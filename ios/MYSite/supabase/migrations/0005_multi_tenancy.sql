-- =====================================================================
-- MPG Site Records — 0005: multi-tenancy
-- Run AFTER 0004_role_authorisation.sql in the Supabase SQL Editor.
--
-- Turns the single shared database into one isolated portal area per
-- company. Isolation is enforced by Row Level Security, never by the app:
-- every table carries company_id, and every policy requires it to equal
-- the caller's company. A missed filter in Swift can no longer leak data
-- because the database refuses the rows outright.
--
-- Safe to re-run.
-- =====================================================================

-- =====================================================================
-- 1. The tenant root
-- =====================================================================

create table if not exists public.companies (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  slug       text not null unique,
  active     boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.companies enable row level security;

-- A user's company comes from their profile: one company per login, which
-- matches how the business works — a tradesman works for one firm.
alter table public.profiles
  add column if not exists company_id uuid references public.companies(id) on delete restrict;

-- The company every existing row belongs to. Everything currently in the
-- database predates tenancy, so it all lands here.
insert into public.companies (name, slug)
values ('MPG', 'mpg')
on conflict (slug) do nothing;

update public.profiles
   set company_id = (select id from public.companies where slug = 'mpg')
 where company_id is null;

create index if not exists profiles_company_idx on public.profiles (company_id);

-- =====================================================================
-- 2. The helper every policy hangs off
-- =====================================================================

-- security definer so it can read profiles despite that table's own RLS.
-- Returns null for a signed-up user not yet attached to a company — and a
-- null company_id never equals anything, so such a user sees nothing at
-- all until an admin invites them. That is the intended default.
create or replace function public.current_company_id()
returns uuid language sql stable security definer set search_path = public as $$
  select company_id from public.profiles where id = auth.uid()
$$;

-- Admin *of your own company*, not of the database. The company clause in
-- each policy does the scoping; this stays a pure role check.
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select role = 'Admin' from public.profiles where id = auth.uid()), false)
$$;


-- =====================================================================
-- 3. company_id on every table
--
-- Order matters: add nullable, backfill from the row's own relationships,
-- then constrain. Adding `not null` first would fail on existing rows.
-- =====================================================================

do $$
declare
  t text;
begin
  foreach t in array array[
    'tradesman_details', 'sites', 'work_allocations', 'daily_records',
    'materials', 'site_photos', 'weekly_submissions', 'query_comments',
    'notifications', 'clock_records', 'role_invites', 'role_requests'
  ] loop
    execute format(
      'alter table public.%I add column if not exists company_id uuid references public.companies(id) on delete restrict',
      t);
  end loop;
end $$;

-- Backfill. Each table derives its company from whatever it already points
-- at, so this stays correct even if you later split the data by hand.
update public.sites s
   set company_id = (select id from public.companies where slug = 'mpg')
 where s.company_id is null;

update public.tradesman_details td
   set company_id = p.company_id
  from public.profiles p
 where p.id = td.user_id and td.company_id is null;

update public.work_allocations a
   set company_id = s.company_id
  from public.sites s
 where s.id = a.site_id and a.company_id is null;

update public.daily_records d
   set company_id = s.company_id
  from public.sites s
 where s.id = d.site_id and d.company_id is null;

update public.materials m
   set company_id = s.company_id
  from public.sites s
 where s.id = m.site_id and m.company_id is null;

update public.site_photos ph
   set company_id = s.company_id
  from public.sites s
 where s.id = ph.site_id and ph.company_id is null;

update public.clock_records c
   set company_id = s.company_id
  from public.sites s
 where s.id = c.site_id and c.company_id is null;

update public.weekly_submissions w
   set company_id = p.company_id
  from public.profiles p
 where p.id = w.user_id and w.company_id is null;

update public.notifications n
   set company_id = p.company_id
  from public.profiles p
 where p.id = n.user_id and n.company_id is null;

-- query_comments hangs off a submission, which is the reliable owner.
update public.query_comments q
   set company_id = w.company_id
  from public.weekly_submissions w
 where w.id = q.submission_id and q.company_id is null;

update public.role_invites i
   set company_id = p.company_id
  from public.profiles p
 where p.id = i.created_by and i.company_id is null;

update public.role_requests r
   set company_id = p.company_id
  from public.profiles p
 where p.id = r.user_id and r.company_id is null;

-- Constrain + auto-stamp + index. The default is what lets the Swift app
-- stay company-unaware: every insert is stamped by the database.
do $$
declare
  t text;
begin
  foreach t in array array[
    'tradesman_details', 'sites', 'work_allocations', 'daily_records',
    'materials', 'site_photos', 'weekly_submissions', 'query_comments',
    'notifications', 'clock_records', 'role_invites', 'role_requests'
  ] loop
    execute format(
      'update public.%I set company_id = (select id from public.companies where slug = ''mpg'') where company_id is null', t);
    execute format('alter table public.%I alter column company_id set not null', t);
    execute format('alter table public.%I alter column company_id set default public.current_company_id()', t);
    execute format('create index if not exists %I on public.%I (company_id)', t || '_company_idx', t);
  end loop;
end $$;

-- Now company-aware: managing a site in another company is impossible even
-- if the site id is guessed. Defined here, after sites.company_id exists.
create or replace function public.manages_site(target_site uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists(
    select 1 from public.sites s
    where s.id = target_site
      and s.site_manager_id = auth.uid()
      and s.company_id = public.current_company_id()
  )
$$;

-- =====================================================================
-- 4. Policies, rewritten with company scoping
--
-- Every policy below gains `company_id = public.current_company_id()`.
-- Three of the originals were outright cross-company leaks once more than
-- one company exists, and are called out where they appear.
-- =====================================================================

-- ---------- companies ----------
drop policy if exists companies_select on public.companies;
create policy companies_select on public.companies for select using (
  id = public.current_company_id()
);
-- Companies are created out of band (service role / bootstrap below), never
-- by an app client, so there is deliberately no insert or update policy.

-- ---------- profiles ----------
-- WAS: any Site Manager could read every profile in the database.
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles for select using (
  id = auth.uid()
  or (
    company_id = public.current_company_id()
    and (public.is_admin() or public.current_role() = 'Site Manager')
  )
);
drop policy if exists profiles_update_self on public.profiles;
create policy profiles_update_self on public.profiles for update using (
  id = auth.uid()
  or (public.is_admin() and company_id = public.current_company_id())
);
drop policy if exists profiles_insert_self on public.profiles;
create policy profiles_insert_self on public.profiles for insert with check (
  id = auth.uid()
  or (public.is_admin() and company_id = public.current_company_id())
);

-- ---------- tradesman_details ----------
drop policy if exists td_rw on public.tradesman_details;
create policy td_rw on public.tradesman_details for all using (
  user_id = auth.uid()
  or (public.is_admin() and company_id = public.current_company_id())
) with check (
  user_id = auth.uid()
  or (public.is_admin() and company_id = public.current_company_id())
);

-- ---------- sites ----------
-- WAS: `using (auth.uid() is not null)` — every signed-in user, of any
-- company, could read every site in the database. The single largest leak.
drop policy if exists sites_select on public.sites;
create policy sites_select on public.sites for select using (
  company_id = public.current_company_id()
);
drop policy if exists sites_write on public.sites;
create policy sites_write on public.sites for all using (
  public.is_admin() and company_id = public.current_company_id()
) with check (
  public.is_admin() and company_id = public.current_company_id()
);

-- ---------- work_allocations ----------
drop policy if exists alloc_select on public.work_allocations;
create policy alloc_select on public.work_allocations for select using (
  company_id = public.current_company_id()
  and (tradesman_id = auth.uid() or public.is_admin() or public.manages_site(site_id))
);
drop policy if exists alloc_write on public.work_allocations;
create policy alloc_write on public.work_allocations for all using (
  company_id = public.current_company_id()
  and (public.is_admin() or public.manages_site(site_id))
) with check (
  company_id = public.current_company_id()
  and (public.is_admin() or public.manages_site(site_id))
);

-- ---------- daily_records ----------
drop policy if exists rec_select on public.daily_records;
create policy rec_select on public.daily_records for select using (
  company_id = public.current_company_id()
  and (user_id = auth.uid() or public.is_admin() or public.manages_site(site_id))
);
drop policy if exists rec_write on public.daily_records;
create policy rec_write on public.daily_records for all using (
  company_id = public.current_company_id()
  and (user_id = auth.uid() or public.is_admin())
) with check (
  company_id = public.current_company_id()
  and (user_id = auth.uid() or public.is_admin())
);

-- ---------- materials ----------
drop policy if exists mat_select on public.materials;
create policy mat_select on public.materials for select using (
  company_id = public.current_company_id()
  and (user_id = auth.uid() or public.is_admin() or public.manages_site(site_id))
);
drop policy if exists mat_write on public.materials;
create policy mat_write on public.materials for all using (
  company_id = public.current_company_id()
  and (user_id = auth.uid() or public.is_admin())
) with check (
  company_id = public.current_company_id()
  and (user_id = auth.uid() or public.is_admin())
);

-- ---------- site_photos ----------
drop policy if exists photo_select on public.site_photos;
create policy photo_select on public.site_photos for select using (
  company_id = public.current_company_id()
  and (user_id = auth.uid() or public.is_admin() or public.manages_site(site_id))
);
drop policy if exists photo_write on public.site_photos;
create policy photo_write on public.site_photos for all using (
  company_id = public.current_company_id()
  and (user_id = auth.uid() or public.is_admin())
) with check (
  company_id = public.current_company_id()
  and (user_id = auth.uid() or public.is_admin())
);

-- ---------- weekly_submissions ----------
-- WAS: any Site Manager could read every submission in the database.
drop policy if exists sub_select on public.weekly_submissions;
create policy sub_select on public.weekly_submissions for select using (
  company_id = public.current_company_id()
  and (user_id = auth.uid() or public.is_admin() or public.current_role() = 'Site Manager')
);
drop policy if exists sub_insert on public.weekly_submissions;
create policy sub_insert on public.weekly_submissions for insert with check (
  company_id = public.current_company_id()
  and (user_id = auth.uid() or public.is_admin())
);
drop policy if exists sub_update on public.weekly_submissions;
create policy sub_update on public.weekly_submissions for update using (
  company_id = public.current_company_id()
  and (user_id = auth.uid() or public.is_admin() or public.current_role() = 'Site Manager')
);

-- ---------- query_comments ----------
drop policy if exists qc_select on public.query_comments;
create policy qc_select on public.query_comments for select using (
  company_id = public.current_company_id()
  and (to_user_id = auth.uid() or public.is_admin() or public.current_role() = 'Site Manager')
);
-- WAS: `with check (auth.uid() is not null)` — any signed-in user could
-- write a comment onto any company's submission.
drop policy if exists qc_insert on public.query_comments;
create policy qc_insert on public.query_comments for insert with check (
  company_id = public.current_company_id()
);

-- ---------- notifications ----------
drop policy if exists notif_select on public.notifications;
create policy notif_select on public.notifications for select using (
  company_id = public.current_company_id()
  and (user_id = auth.uid() or public.is_admin())
);
drop policy if exists notif_update on public.notifications;
create policy notif_update on public.notifications for update using (
  company_id = public.current_company_id() and user_id = auth.uid()
);
-- WAS: any signed-in user could push a notification to any user anywhere.
drop policy if exists notif_insert on public.notifications;
create policy notif_insert on public.notifications for insert with check (
  company_id = public.current_company_id()
);

-- ---------- clock_records ----------
drop policy if exists clock_select on public.clock_records;
create policy clock_select on public.clock_records for select using (
  company_id = public.current_company_id()
  and (user_id = auth.uid() or public.is_admin() or public.manages_site(site_id))
);
drop policy if exists clock_insert on public.clock_records;
create policy clock_insert on public.clock_records for insert with check (
  company_id = public.current_company_id()
  and (user_id = auth.uid() or public.is_admin())
);
drop policy if exists clock_update on public.clock_records;
create policy clock_update on public.clock_records for update using (
  company_id = public.current_company_id()
  and (user_id = auth.uid() or public.is_admin() or public.manages_site(site_id))
);

-- ---------- role_invites / role_requests ----------
drop policy if exists role_invites_admin on public.role_invites;
create policy role_invites_admin on public.role_invites for all using (
  public.is_admin() and company_id = public.current_company_id()
) with check (
  public.is_admin() and company_id = public.current_company_id()
);

drop policy if exists role_requests_select on public.role_requests;
create policy role_requests_select on public.role_requests for select using (
  user_id = auth.uid()
  or (public.is_admin() and company_id = public.current_company_id())
);
drop policy if exists role_requests_insert_self on public.role_requests;
create policy role_requests_insert_self on public.role_requests for insert with check (
  user_id = auth.uid() and status = 'Pending'
);
drop policy if exists role_requests_admin_update on public.role_requests;
create policy role_requests_admin_update on public.role_requests for update using (
  public.is_admin() and company_id = public.current_company_id()
) with check (
  public.is_admin() and company_id = public.current_company_id()
);

-- =====================================================================
-- 5. Joining a company
--
-- A brand-new signup has company_id null and therefore sees nothing. They
-- join by redeeming an invite, which now carries the inviting admin's
-- company. This is the only path that attaches a user to a company.
-- =====================================================================

create or replace function public.create_role_invite(
  p_role user_role,
  p_expires_days int default 7
) returns text language plpgsql security definer set search_path = public as $$
declare
  v_code text;
  v_attempts int := 0;
  v_company uuid := public.current_company_id();
begin
  if not public.is_admin() then
    raise exception 'Only an admin can create invites.' using errcode = '42501';
  end if;
  if v_company is null then
    raise exception 'Your account is not attached to a company.' using errcode = '22023';
  end if;
  if p_role not in ('Admin', 'Site Manager', 'Tradesman') then
    raise exception 'Unknown role for invite.' using errcode = '22023';
  end if;

  loop
    v_code := public.generate_invite_code();
    exit when not exists (select 1 from public.role_invites where code = v_code);
    v_attempts := v_attempts + 1;
    if v_attempts > 10 then
      raise exception 'Could not generate a unique invite code.';
    end if;
  end loop;

  insert into public.role_invites (code, role, created_by, company_id, expires_at)
  values (v_code, p_role, auth.uid(), v_company,
          now() + (p_expires_days || ' days')::interval);

  return v_code;
end $$;

create or replace function public.redeem_role_invite(p_code text)
returns user_role language plpgsql security definer set search_path = public as $$
declare
  v_invite public.role_invites;
  v_code text := upper(trim(p_code));
  v_current_company uuid;
begin
  if auth.uid() is null then
    raise exception 'You must be signed in to redeem an invite.' using errcode = '42501';
  end if;

  select * into v_invite from public.role_invites where code = v_code for update;

  if v_invite.id is null then
    raise exception 'That invite code was not recognised.' using errcode = '22023';
  end if;
  if v_invite.revoked then
    raise exception 'That invite has been revoked.' using errcode = '22023';
  end if;
  if v_invite.used_by is not null then
    raise exception 'That invite has already been used.' using errcode = '22023';
  end if;
  if v_invite.expires_at < now() then
    raise exception 'That invite has expired.' using errcode = '22023';
  end if;

  -- Moving between companies would strand the user's existing records in
  -- their old company, so it is refused rather than silently allowed.
  select company_id into v_current_company from public.profiles where id = auth.uid();
  if v_current_company is not null and v_current_company <> v_invite.company_id then
    raise exception 'That invite belongs to a different company.' using errcode = '42501';
  end if;

  perform set_config('app.role_change_authorised', 'on', true);
  update public.profiles
     set role = v_invite.role, company_id = v_invite.company_id
   where id = auth.uid();
  perform set_config('app.role_change_authorised', 'off', true);

  update public.role_invites
     set used_by = auth.uid(), used_at = now()
   where id = v_invite.id;

  return v_invite.role;
end $$;

-- Stands up a brand-new company with its first admin. Service-role only:
-- there is deliberately no client-callable path to creating a company.
create or replace function public.bootstrap_company(
  p_name text,
  p_slug text,
  p_admin_user uuid
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_company uuid;
begin
  insert into public.companies (name, slug)
  values (p_name, p_slug)
  on conflict (slug) do update set name = excluded.name
  returning id into v_company;

  perform set_config('app.role_change_authorised', 'on', true);
  update public.profiles
     set company_id = v_company, role = 'Admin'
   where id = p_admin_user;
  perform set_config('app.role_change_authorised', 'off', true);

  return v_company;
end $$;

revoke execute on function public.bootstrap_company(text, text, uuid) from anon, authenticated;

-- Moves a site and everything hanging off it into another company. Use this
-- if two companies' records are already mixed together in the default
-- company — the migration cannot guess which site belongs to whom.
create or replace function public.move_site_to_company(
  p_site uuid,
  p_company uuid
) returns void language plpgsql security definer set search_path = public as $$
begin
  update public.sites             set company_id = p_company where id = p_site;
  update public.work_allocations  set company_id = p_company where site_id = p_site;
  update public.daily_records     set company_id = p_company where site_id = p_site;
  update public.materials         set company_id = p_company where site_id = p_site;
  update public.site_photos       set company_id = p_company where site_id = p_site;
  update public.clock_records     set company_id = p_company where site_id = p_site;
end $$;

revoke execute on function public.move_site_to_company(uuid, uuid) from anon, authenticated;

-- =====================================================================
-- 6. Xero, per company
--
-- Replaces the single row keyed on the literal string 'mpg', which meant
-- the second company to connect Xero overwrote the first and both then
-- pushed invoices into whichever organisation connected last.
-- =====================================================================

create table if not exists public.xero_connections (
  company_key   text,
  company_id    uuid references public.companies(id) on delete cascade,
  tenant_id     text,
  tenant_name   text,
  access_token  text,
  refresh_token text,
  expires_at    timestamptz,
  updated_at    timestamptz not null default now()
);

-- Carry any pre-existing single connection over to the default company.
update public.xero_connections
   set company_id = (select id from public.companies where slug = 'mpg')
 where company_id is null;

delete from public.xero_connections where company_id is null;

alter table public.xero_connections drop column if exists company_key;
alter table public.xero_connections alter column company_id set not null;

do $$ begin
  alter table public.xero_connections add constraint xero_connections_company_key unique (company_id);
exception when duplicate_table or duplicate_object then null; end $$;

-- Ties an in-flight consent flow back to the company that started it. The
-- callback arrives unauthenticated straight from Xero, so without this the
-- function cannot know whose connection it is storing. It also closes the
-- CSRF hole where `state` was generated and then never verified.
create table if not exists public.xero_oauth_states (
  state      text primary key,
  company_id uuid not null references public.companies(id) on delete cascade,
  created_by uuid references public.profiles(id) on delete set null,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);

-- Tokens are only ever touched by the Edge Functions using the service role,
-- so both tables stay locked with RLS on and no policy at all.
alter table public.xero_connections  enable row level security;
alter table public.xero_oauth_states enable row level security;

-- =====================================================================
-- 7. Storage — company-scoped evidence paths
--
-- Paths become <company_id>/<site_id>/<user_id>/<filename>, so the read
-- policy can authorise on segment 1 before it looks at anything else.
--
-- Objects uploaded before this migration use the old two-folder layout
-- <site_id>/<user_id>/<filename>. Those are grandfathered for READ so that
-- existing evidence stays visible, but nothing new may be written that way.
-- =====================================================================

drop policy if exists evidence_read on storage.objects;
create policy evidence_read on storage.objects for select using (
  bucket_id = 'site-evidence'
  and (
    -- New three-folder layout: company / site / owner.
    (
      array_length(storage.foldername(name), 1) >= 3
      and (storage.foldername(name))[1] = public.current_company_id()::text
      and (
        public.is_admin()
        or (storage.foldername(name))[3] = auth.uid()::text
        or public.manages_site(((storage.foldername(name))[2])::uuid)
      )
    )
    -- Legacy two-folder layout: site / owner. Read-only, and still checked
    -- against the caller's own company via manages_site / ownership.
    or (
      array_length(storage.foldername(name), 1) = 2
      and (
        (storage.foldername(name))[2] = auth.uid()::text
        or public.manages_site(((storage.foldername(name))[1])::uuid)
        or (
          public.is_admin()
          and exists (
            select 1 from public.sites s
            where s.id = ((storage.foldername(name))[1])::uuid
              and s.company_id = public.current_company_id()
          )
        )
      )
    )
  )
);

drop policy if exists evidence_insert on storage.objects;
create policy evidence_insert on storage.objects for insert with check (
  bucket_id = 'site-evidence'
  and array_length(storage.foldername(name), 1) >= 3
  and (storage.foldername(name))[1] = public.current_company_id()::text
  and (storage.foldername(name))[3] = auth.uid()::text
);

drop policy if exists evidence_update on storage.objects;
create policy evidence_update on storage.objects for update using (
  bucket_id = 'site-evidence'
  and array_length(storage.foldername(name), 1) >= 3
  and (storage.foldername(name))[1] = public.current_company_id()::text
  and ((storage.foldername(name))[3] = auth.uid()::text or public.is_admin())
);

drop policy if exists evidence_delete on storage.objects;
create policy evidence_delete on storage.objects for delete using (
  bucket_id = 'site-evidence'
  and array_length(storage.foldername(name), 1) >= 3
  and (storage.foldername(name))[1] = public.current_company_id()::text
  and ((storage.foldername(name))[3] = auth.uid()::text or public.is_admin())
);

-- =====================================================================
-- 8. Verification
--
-- Every row should belong to a company, and every table should be scoped.
-- Run this after the migration; both counts must be zero.
-- =====================================================================

-- select 'unassigned profiles' as check, count(*) from public.profiles where company_id is null
-- union all
-- select 'companies', count(*) from public.companies;
