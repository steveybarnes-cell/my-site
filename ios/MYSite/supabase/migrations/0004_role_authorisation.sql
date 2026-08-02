-- =====================================================================
-- 0004  Role authorisation
--
-- Everyone signs up as Tradesman. Becoming a Site Manager or Admin now
-- requires either:
--   (a) redeeming a short invite code created by an Admin, or
--   (b) requesting the role and having an Admin approve it.
--
-- SECURITY: this migration also closes a privilege-escalation hole. The
-- existing `profiles_update_self` policy lets a user update their own
-- profile row, and `role` is a column on that row — so any tradesman
-- could PATCH themselves to Admin. A trigger now rejects any role change
-- that does not come from an Admin or from the audited functions below.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Lock down role changes
-- ---------------------------------------------------------------------

-- Set by the SECURITY DEFINER functions below so they can legitimately
-- change a role. `set_config(..., true)` scopes it to the transaction.
create or replace function public.role_change_is_authorised()
returns boolean language sql stable as $$
  select coalesce(current_setting('app.role_change_authorised', true) = 'on', false)
$$;

create or replace function public.enforce_role_change()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.role is distinct from old.role then
    if not (public.is_admin() or public.role_change_is_authorised()) then
      raise exception
        'Role changes require an admin, an invite code, or an approved request.'
        using errcode = '42501';
    end if;
  end if;
  return new;
end $$;

drop trigger if exists profiles_enforce_role_change on public.profiles;
create trigger profiles_enforce_role_change
  before update on public.profiles
  for each row execute function public.enforce_role_change();

-- ---------------------------------------------------------------------
-- 2. Invite codes
-- ---------------------------------------------------------------------

create table if not exists public.role_invites (
  id          uuid primary key default gen_random_uuid(),
  code        text not null unique,
  role        user_role not null,
  created_by  uuid not null references public.profiles(id) on delete cascade,
  created_at  timestamptz not null default now(),
  expires_at  timestamptz not null,
  used_by     uuid references public.profiles(id) on delete set null,
  used_at     timestamptz,
  revoked     boolean not null default false
);

create index if not exists role_invites_code_idx on public.role_invites (code);

alter table public.role_invites enable row level security;

-- Only admins can see or manage invites. Redemption happens through the
-- SECURITY DEFINER function below, so codes can never be enumerated.
drop policy if exists role_invites_admin on public.role_invites;
create policy role_invites_admin on public.role_invites for all
  using (public.is_admin()) with check (public.is_admin());

-- Human-friendly code: MPG-XXXX-XXXX, no ambiguous characters (0/O, 1/I/L).
create or replace function public.generate_invite_code()
returns text language plpgsql as $$
declare
  alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  result text := '';
  i int;
begin
  for i in 1..8 loop
    result := result || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
    if i = 4 then result := result || '-'; end if;
  end loop;
  return 'MPG-' || result;
end $$;

-- Admin creates an invite for a given role. Returns the code to share.
create or replace function public.create_role_invite(
  p_role user_role,
  p_expires_days int default 7
) returns text language plpgsql security definer set search_path = public as $$
declare
  v_code text;
  v_attempts int := 0;
begin
  if not public.is_admin() then
    raise exception 'Only an admin can create invites.' using errcode = '42501';
  end if;
  if p_role not in ('Admin', 'Site Manager') then
    raise exception 'Invites are only needed for Admin or Site Manager.'
      using errcode = '22023';
  end if;

  loop
    v_code := public.generate_invite_code();
    exit when not exists (select 1 from public.role_invites where code = v_code);
    v_attempts := v_attempts + 1;
    if v_attempts > 10 then
      raise exception 'Could not generate a unique invite code.';
    end if;
  end loop;

  insert into public.role_invites (code, role, created_by, expires_at)
  values (v_code, p_role, auth.uid(), now() + (p_expires_days || ' days')::interval);

  return v_code;
end $$;

-- Any signed-in user redeems a code to receive the invited role.
create or replace function public.redeem_role_invite(p_code text)
returns user_role language plpgsql security definer set search_path = public as $$
declare
  v_invite public.role_invites;
  v_code text := upper(trim(p_code));
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

  perform set_config('app.role_change_authorised', 'on', true);
  update public.profiles set role = v_invite.role where id = auth.uid();
  perform set_config('app.role_change_authorised', 'off', true);

  update public.role_invites
     set used_by = auth.uid(), used_at = now()
   where id = v_invite.id;

  return v_invite.role;
end $$;

-- ---------------------------------------------------------------------
-- 3. Role requests
-- ---------------------------------------------------------------------

do $$ begin
  create type role_request_status as enum ('Pending', 'Approved', 'Declined');
exception when duplicate_object then null;
end $$;

create table if not exists public.role_requests (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references public.profiles(id) on delete cascade,
  requested_role user_role not null,
  status         role_request_status not null default 'Pending',
  note           text not null default '',
  created_at     timestamptz not null default now(),
  decided_by     uuid references public.profiles(id) on delete set null,
  decided_at     timestamptz
);

-- At most one open request per person.
create unique index if not exists role_requests_one_pending
  on public.role_requests (user_id) where status = 'Pending';

alter table public.role_requests enable row level security;

drop policy if exists role_requests_select on public.role_requests;
create policy role_requests_select on public.role_requests for select
  using (user_id = auth.uid() or public.is_admin());

drop policy if exists role_requests_insert_self on public.role_requests;
create policy role_requests_insert_self on public.role_requests for insert
  with check (user_id = auth.uid() and status = 'Pending');

drop policy if exists role_requests_admin_update on public.role_requests;
create policy role_requests_admin_update on public.role_requests for update
  using (public.is_admin()) with check (public.is_admin());

-- A user asks to be upgraded.
create or replace function public.request_role(
  p_role user_role,
  p_note text default ''
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_id uuid;
begin
  if auth.uid() is null then
    raise exception 'You must be signed in.' using errcode = '42501';
  end if;
  if p_role not in ('Admin', 'Site Manager') then
    raise exception 'You can only request Admin or Site Manager.' using errcode = '22023';
  end if;

  insert into public.role_requests (user_id, requested_role, note)
  values (auth.uid(), p_role, coalesce(p_note, ''))
  returning id into v_id;

  return v_id;
end $$;

-- An admin approves or declines. Approving applies the role.
create or replace function public.decide_role_request(
  p_id uuid,
  p_approve boolean
) returns void language plpgsql security definer set search_path = public as $$
declare
  v_req public.role_requests;
begin
  if not public.is_admin() then
    raise exception 'Only an admin can decide role requests.' using errcode = '42501';
  end if;

  select * into v_req from public.role_requests where id = p_id for update;
  if v_req.id is null then
    raise exception 'Request not found.' using errcode = '22023';
  end if;
  if v_req.status <> 'Pending' then
    raise exception 'That request has already been decided.' using errcode = '22023';
  end if;

  if p_approve then
    perform set_config('app.role_change_authorised', 'on', true);
    update public.profiles set role = v_req.requested_role where id = v_req.user_id;
    perform set_config('app.role_change_authorised', 'off', true);
  end if;

  update public.role_requests
     set status = case when p_approve then 'Approved' else 'Declined' end::role_request_status,
         decided_by = auth.uid(),
         decided_at = now()
   where id = p_id;
end $$;

-- ---------------------------------------------------------------------
-- 4. Permissions
-- ---------------------------------------------------------------------

revoke all on function public.create_role_invite(user_role, int) from public;
revoke all on function public.redeem_role_invite(text) from public;
revoke all on function public.request_role(user_role, text) from public;
revoke all on function public.decide_role_request(uuid, boolean) from public;

grant execute on function public.create_role_invite(user_role, int) to authenticated;
grant execute on function public.redeem_role_invite(text) to authenticated;
grant execute on function public.request_role(user_role, text) to authenticated;
grant execute on function public.decide_role_request(uuid, boolean) to authenticated;
