-- =====================================================================
-- MPG Site Records — 0006: let admins onboard new signups
-- Run AFTER 0005_multi_tenancy.sql.
--
-- Fixes a hole opened by 0005. Every profiles policy in that migration
-- required `company_id = current_company_id()`, but a brand-new signup
-- has company_id NULL — and NULL never equals anything. The result: an
-- admin could not SEE a new signup, and updating one silently affected
-- zero rows. No error, no permission denied, just nothing happening.
--
-- Safe to re-run.
-- =====================================================================

-- =====================================================================
-- 1. Admins can see signups that haven't joined a company yet
-- =====================================================================

-- A user with no company is nobody's data yet, so showing them to admins
-- leaks nothing about an existing company's records — only that someone
-- has registered. That is the minimum needed to onboard them at all.
--
-- Trade-off worth knowing: with more than one company on this database,
-- every admin sees every unclaimed signup, including one intended for a
-- different firm. If that matters, use invite codes instead — those bind
-- the user to the inviting admin's company and never expose the list.
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles for select using (
  id = auth.uid()
  or (
    company_id = public.current_company_id()
    and (public.is_admin() or public.current_role() = 'Site Manager')
  )
  or (public.is_admin() and company_id is null)
);

-- =====================================================================
-- 2. Adopting a signup into your company
--
-- Deliberately a function rather than a looser UPDATE policy. A policy
-- that allowed writes to rows with a null company would let any admin
-- overwrite a signup mid-onboarding; this checks every precondition and
-- raises a specific error for each, so the app can say what went wrong
-- instead of reporting a silent success.
-- =====================================================================

create or replace function public.adopt_user_into_company(
  p_user uuid,
  p_role user_role default 'Tradesman'
) returns void language plpgsql security definer set search_path = public as $$
declare
  v_company uuid := public.current_company_id();
  v_target_company uuid;
begin
  if not public.is_admin() then
    raise exception 'Only an admin can add someone to a company.'
      using errcode = '42501';
  end if;
  if v_company is null then
    raise exception 'Your own account is not attached to a company.'
      using errcode = '22023';
  end if;

  select company_id into v_target_company
    from public.profiles where id = p_user;

  if not found then
    raise exception 'That user does not exist.' using errcode = '22023';
  end if;

  -- Already yours: this is a plain role change, allowed.
  if v_target_company = v_company then
    perform set_config('app.role_change_authorised', 'on', true);
    update public.profiles set role = p_role where id = p_user;
    perform set_config('app.role_change_authorised', 'off', true);
    return;
  end if;

  -- Belongs to someone else: refuse. Moving between companies would
  -- strand their existing records in the old company.
  if v_target_company is not null then
    raise exception 'That user already belongs to another company.'
      using errcode = '42501';
  end if;

  perform set_config('app.role_change_authorised', 'on', true);
  update public.profiles
     set company_id = v_company, role = p_role
   where id = p_user;
  perform set_config('app.role_change_authorised', 'off', true);
end $$;

revoke execute on function public.adopt_user_into_company(uuid, user_role) from anon;
grant execute on function public.adopt_user_into_company(uuid, user_role) to authenticated;

-- =====================================================================
-- 3. Changing the role of someone already in your company
--
-- The RLS policy already permits this, but going through a function
-- means a refusal is an actual error rather than a zero-row update the
-- app would report as success.
-- =====================================================================

create or replace function public.set_user_role(
  p_user uuid,
  p_role user_role
) returns void language plpgsql security definer set search_path = public as $$
declare
  v_company uuid := public.current_company_id();
begin
  if not public.is_admin() then
    raise exception 'Only an admin can change someone''s role.'
      using errcode = '42501';
  end if;

  if not exists (
    select 1 from public.profiles
    where id = p_user and company_id is not distinct from v_company
  ) then
    raise exception 'That user is not in your company.' using errcode = '42501';
  end if;

  if p_user = auth.uid() and p_role <> 'Admin' then
    raise exception 'You cannot remove your own admin access.'
      using errcode = '42501';
  end if;

  perform set_config('app.role_change_authorised', 'on', true);
  update public.profiles set role = p_role where id = p_user;
  perform set_config('app.role_change_authorised', 'off', true);
end $$;

revoke execute on function public.set_user_role(uuid, user_role) from anon;
grant execute on function public.set_user_role(uuid, user_role) to authenticated;

-- =====================================================================
-- 4. Who is waiting to be let in
-- =====================================================================

create or replace view public.pending_signups
with (security_invoker = true) as
  select id, name, email, created_at
    from public.profiles
   where company_id is null;

grant select on public.pending_signups to authenticated;
