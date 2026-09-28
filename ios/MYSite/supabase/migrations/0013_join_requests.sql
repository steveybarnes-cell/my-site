-- =====================================================================
-- MY Site — 0013: asking to join a company, and the office saying yes or no
-- Run AFTER 0012_subscriptions.sql. Safe to re-run.
--
-- Until now a new signup could only get into a company two ways: the
-- office handed him a single-use invite code, or an admin found him in the
-- "pending signups" list and adopted him. That list had two problems, and
-- the second one matters now that other firms are paying for this:
--
--   1. There was no "no". An admin could let someone in but never turn
--      them away, so a stranger sat in the list for ever.
--   2. 0006 showed every unclaimed signup to every admin of every company.
--      A man signing up to join Smith Building appeared on Jones Roofing's
--      screen too — name and email — and Jones's admin could adopt him.
--
-- The fix is a request with an address on it. Each company has a short,
-- reusable company code (pin it up in the site cabin). A new man signs up,
-- types it, and that creates a join request which only THAT company's
-- admins can see, approve or decline. Invite codes still work as before
-- and skip the queue — the office already vouched for whoever holds one.
--
-- Nothing here is writable directly from the client. Every change goes
-- through a SECURITY DEFINER function that checks its own preconditions
-- and raises a specific error, so the app can say what went wrong instead
-- of reporting a zero-row update as success.
-- =====================================================================

-- =====================================================================
-- 1. A company code per company
--
-- Six characters from an alphabet with nothing that reads two ways on a
-- phone call or a photocopied sheet (no 0/O, 1/I/L, 5/S, 2/Z, 8/B).
-- 26^6-ish combinations is plenty: the code is an address, not a secret —
-- knowing it only lets you ASK, and a person still decides.
-- =====================================================================

create or replace function public.generate_join_code()
returns text language plpgsql volatile set search_path = public as $$
declare
  alphabet constant text := 'ACDEFGHJKMNPQRTUVWXY34679';
  result text := '';
begin
  for i in 1..6 loop
    result := result || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
  end loop;
  return result;
end $$;

alter table public.companies add column if not exists join_code text;

-- Backfill before the constraint, one row at a time so a clash retries.
do $$
declare r record; v text;
begin
  for r in select id from public.companies where join_code is null loop
    loop
      v := public.generate_join_code();
      exit when not exists (select 1 from public.companies where join_code = v);
    end loop;
    update public.companies set join_code = v where id = r.id;
  end loop;
end $$;

create unique index if not exists companies_join_code_key on public.companies (join_code);

-- New companies (create_company, bootstrap_company) get one automatically.
create or replace function public.companies_set_join_code()
returns trigger language plpgsql set search_path = public as $$
declare v text;
begin
  if new.join_code is null then
    loop
      v := public.generate_join_code();
      exit when not exists (select 1 from public.companies where join_code = v);
    end loop;
    new.join_code := v;
  end if;
  return new;
end $$;

drop trigger if exists companies_join_code on public.companies;
create trigger companies_join_code before insert on public.companies
  for each row execute function public.companies_set_join_code();

-- The admin reads it here rather than from `companies`, so the code is only
-- ever shown to someone who can act on the requests it produces.
create or replace function public.company_join_code()
returns text language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() or public.current_company_id() is null then
    raise exception 'Only an admin can see the company code.' using errcode = '42501';
  end if;
  return (select join_code from public.companies where id = public.current_company_id());
end $$;

-- If the code ends up somewhere it shouldn't. Requests already made stay.
create or replace function public.reset_join_code()
returns text language plpgsql security definer set search_path = public as $$
declare v text;
begin
  if not public.is_admin() or public.current_company_id() is null then
    raise exception 'Only an admin can change the company code.' using errcode = '42501';
  end if;
  loop
    v := public.generate_join_code();
    exit when not exists (select 1 from public.companies where join_code = v);
  end loop;
  update public.companies set join_code = v where id = public.current_company_id();
  return v;
end $$;

-- =====================================================================
-- 2. Join requests
-- =====================================================================

create table if not exists public.join_requests (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  company_id  uuid not null references public.companies(id) on delete cascade,
  status      text not null default 'Pending'
              check (status in ('Pending', 'Approved', 'Declined', 'Withdrawn')),
  role        user_role,                       -- what he was let in as
  created_at  timestamptz not null default now(),
  decided_by  uuid references public.profiles(id) on delete set null,
  decided_at  timestamptz
);

-- One open request per person: asking a second firm withdraws the first.
create unique index if not exists join_requests_one_pending
  on public.join_requests (user_id) where status = 'Pending';
create index if not exists join_requests_company_pending
  on public.join_requests (company_id) where status = 'Pending';

alter table public.join_requests enable row level security;

-- He sees his own; admins see their own company's. No insert/update/delete
-- policy at all: the functions below are the only way in.
drop policy if exists join_requests_select on public.join_requests;
create policy join_requests_select on public.join_requests for select using (
  user_id = auth.uid()
  or (public.is_admin() and company_id = public.current_company_id())
);

revoke insert, update, delete on public.join_requests from anon, authenticated;
grant select on public.join_requests to authenticated;

-- =====================================================================
-- 3. Asking
-- =====================================================================

create or replace function public.request_to_join(p_code text)
returns text language plpgsql security definer set search_path = public as $$
declare
  v_user     uuid := auth.uid();
  v_code     text := upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g'));
  v_company  public.companies;
  v_mine     uuid;
begin
  if v_user is null then
    raise exception 'You must be signed in to ask to join a company.' using errcode = '42501';
  end if;

  select company_id into v_mine from public.profiles where id = v_user;
  if not found then
    raise exception 'Your account is not set up properly. Ring the office.' using errcode = '22023';
  end if;
  if v_mine is not null then
    raise exception 'Your account already belongs to a company.' using errcode = '42501';
  end if;

  select * into v_company from public.companies
   where join_code = v_code and active;
  if v_company.id is null then
    raise exception 'That company code was not recognised. Check it with the office.'
      using errcode = '22023';
  end if;

  -- Asking the same firm again keeps his place in the queue. Asking a
  -- different firm withdraws the old request rather than stacking them up.
  if exists (select 1 from public.join_requests
              where user_id = v_user and status = 'Pending' and company_id = v_company.id) then
    return v_company.name;
  end if;
  update public.join_requests set status = 'Withdrawn', decided_at = now()
   where user_id = v_user and status = 'Pending';

  insert into public.join_requests (user_id, company_id) values (v_user, v_company.id);
  return v_company.name;
end $$;

-- What his waiting screen shows. The company name comes from here because
-- he cannot read `companies` — that policy scopes it to his own company,
-- which is exactly what he does not have yet.
create or replace function public.my_join_request()
returns table (status text, company_name text, created_at timestamptz, decided_at timestamptz)
language sql stable security definer set search_path = public as $$
  select r.status, c.name, r.created_at, r.decided_at
    from public.join_requests r
    join public.companies c on c.id = r.company_id
   where r.user_id = auth.uid() and r.status <> 'Withdrawn'
   order by r.created_at desc
   limit 1
$$;

-- =====================================================================
-- 4. Deciding
-- =====================================================================

-- The admin's queue, with the name and email to decide on. A function
-- rather than a view over profiles so it can join a row the admin is not
-- otherwise allowed to read, and hand back only these columns.
create or replace function public.pending_join_requests()
returns table (id uuid, user_id uuid, name text, email text, created_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() or public.current_company_id() is null then
    raise exception 'Only an admin can see who is waiting to join.' using errcode = '42501';
  end if;
  return query
    select r.id, r.user_id, p.name, p.email, r.created_at
      from public.join_requests r
      join public.profiles p on p.id = r.user_id
     where r.company_id = public.current_company_id() and r.status = 'Pending'
     order by r.created_at;
end $$;

create or replace function public.decide_join_request(
  p_id      uuid,
  p_approve boolean,
  p_role    user_role default 'Tradesman'
) returns void language plpgsql security definer set search_path = public as $$
declare
  v_req     public.join_requests;
  v_company uuid := public.current_company_id();
  v_target  uuid;
begin
  if not public.is_admin() or v_company is null then
    raise exception 'Only an admin can let people in.' using errcode = '42501';
  end if;

  select * into v_req from public.join_requests where id = p_id for update;
  -- Another company's request is reported as not found, not as forbidden:
  -- confirming it exists would leak that someone asked to join them.
  if v_req.id is null or v_req.company_id <> v_company then
    raise exception 'That request was not found.' using errcode = '22023';
  end if;
  if v_req.status <> 'Pending' then
    raise exception 'That request has already been dealt with.' using errcode = '22023';
  end if;

  if p_approve then
    select company_id into v_target from public.profiles where id = v_req.user_id for update;
    if v_target is not null and v_target <> v_company then
      raise exception 'That person has already joined another company.' using errcode = '42501';
    end if;
    perform set_config('app.role_change_authorised', 'on', true);
    update public.profiles set company_id = v_company, role = coalesce(p_role, 'Tradesman')
     where id = v_req.user_id;
    perform set_config('app.role_change_authorised', 'off', true);
  end if;

  update public.join_requests
     set status = case when p_approve then 'Approved' else 'Declined' end,
         role = case when p_approve then coalesce(p_role, 'Tradesman') end,
         decided_by = auth.uid(), decided_at = now()
   where id = p_id;
end $$;

-- =====================================================================
-- 5. Closing the cross-company leak from 0006
--
-- Admins now see an unattached signup only when he has asked to join
-- THEIR company. `pending_signups` (the view the iPhone app's Manage →
-- Team list reads) is security_invoker over profiles, so it narrows with
-- this policy on its own and the app keeps working unchanged — it just
-- stops showing other firms' people.
-- =====================================================================

drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles for select using (
  id = auth.uid()
  or (
    company_id = public.current_company_id()
    and (public.is_admin() or public.current_role() = 'Site Manager')
  )
  or (
    public.is_admin() and company_id is null
    and exists (
      select 1 from public.join_requests r
       where r.user_id = profiles.id
         and r.company_id = public.current_company_id()
         and r.status = 'Pending')
  )
);

-- adopt_user_into_company (0006) could attach ANY unattached user whose id
-- an admin knew. It now needs that person to have asked to join, and it
-- closes the request, so the iPhone app's "Add to company" and the portal's
-- Approve are the same act with the same record behind them.
create or replace function public.adopt_user_into_company(
  p_user uuid,
  p_role user_role default 'Tradesman'
) returns void language plpgsql security definer set search_path = public as $$
declare
  v_company uuid := public.current_company_id();
  v_target_company uuid;
  v_req uuid;
begin
  if not public.is_admin() then
    raise exception 'Only an admin can add someone to a company.' using errcode = '42501';
  end if;
  if v_company is null then
    raise exception 'Your own account is not attached to a company.' using errcode = '22023';
  end if;

  select company_id into v_target_company from public.profiles where id = p_user;
  if not found then
    raise exception 'That user does not exist.' using errcode = '22023';
  end if;

  -- Already yours: a plain role change, allowed as before.
  if v_target_company = v_company then
    perform set_config('app.role_change_authorised', 'on', true);
    update public.profiles set role = p_role where id = p_user;
    perform set_config('app.role_change_authorised', 'off', true);
    return;
  end if;

  if v_target_company is not null then
    raise exception 'That user already belongs to another company.' using errcode = '42501';
  end if;

  select id into v_req from public.join_requests
   where user_id = p_user and company_id = v_company and status = 'Pending';
  if v_req is null then
    raise exception 'That person has not asked to join your company. Give them your company code or an invite code.'
      using errcode = '42501';
  end if;

  perform public.decide_join_request(v_req, true, p_role);
end $$;

-- An invite code (redeem_role_invite) also puts him in a company; close
-- any request he had open so it does not linger on an admin's screen.
create or replace function public.join_requests_close_on_join()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if old.company_id is null and new.company_id is not null then
    update public.join_requests
       set status = case when company_id = new.company_id then 'Approved' else 'Withdrawn' end,
           role = case when company_id = new.company_id then new.role end,
           decided_at = now()
     where user_id = new.id and status = 'Pending';
  end if;
  return new;
end $$;

drop trigger if exists profiles_close_join_requests on public.profiles;
create trigger profiles_close_join_requests after update of company_id on public.profiles
  for each row execute function public.join_requests_close_on_join();

-- =====================================================================
-- 6. Permissions
-- =====================================================================

revoke execute on function public.generate_join_code() from public, anon, authenticated;
revoke execute on function public.companies_set_join_code() from public, anon, authenticated;
revoke execute on function public.join_requests_close_on_join() from public, anon, authenticated;

do $$
declare f text;
begin
  foreach f in array array[
    'public.company_join_code()', 'public.reset_join_code()',
    'public.request_to_join(text)', 'public.my_join_request()',
    'public.pending_join_requests()', 'public.decide_join_request(uuid, boolean, user_role)',
    'public.adopt_user_into_company(uuid, user_role)'
  ] loop
    execute 'revoke execute on function ' || f || ' from public, anon';
    execute 'grant execute on function ' || f || ' to authenticated';
  end loop;
end $$;
