-- =====================================================================
-- MPG Site Records — 0007: let the Supabase dashboard edit roles
-- Run AFTER 0006_onboarding_fix.sql.
--
-- Why this exists
-- ---------------
-- `profiles.role` is guarded by the `enforce_role_change` trigger added in
-- 0004, which stops a tradesman PATCHing themselves to Admin. It allows the
-- change only when `is_admin()` is true or one of the audited functions has
-- set `app.role_change_authorised`.
--
-- Neither is true in the Supabase dashboard. The SQL Editor and Table Editor
-- connect as `postgres`, where there is no end user, so `auth.uid()` is null
-- and `is_admin()` is false. Editing the role cell therefore failed with
-- "Role changes require an admin, an invite code, or an approved request."
--
-- This adds a third allowed case: the caller is not an end user of the app.
--
-- Picking the right signal took two attempts, and the wrong one is worth
-- recording. Inside a SECURITY DEFINER function `current_user` is the
-- function's OWNER (postgres) for every caller, so it is useless as a guard.
-- `session_user` is honest, but it is `authenticator` for *everything* that
-- comes through PostgREST — and the dashboard's Table Editor edits rows
-- through PostgREST with the service key, so it looked identical to a
-- tradesman's request and stayed blocked.
--
-- The `role` GUC is the one that works. PostgREST issues `SET ROLE` per
-- request, and SECURITY DEFINER does not disturb it:
--
--   SQL Editor / direct connection    role = 'none'
--   Table Editor / service key        role = 'service_role'
--   Signed-in app user                role = 'authenticated'
--   Unauthenticated app request       role = 'anon'
--
-- So the check is: anything that is NOT one of the two end-user roles.
--
-- Is that a weakening? Only nominally. `service_role` already bypasses RLS
-- entirely and a direct connection could drop this trigger outright, so
-- neither is being handed anything it didn't already have. Every request the
-- app itself makes still hits the original check.
--
-- Verified on Postgres 16 across six paths: SQL Editor allowed; Table Editor
-- allowed; tradesman self-promotion refused by the trigger; tradesman
-- promoting someone else blocked by RLS; anonymous blocked by RLS; admin
-- promotion allowed.
--
-- Safe to re-run.
-- =====================================================================

create or replace function public.enforce_role_change()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.role is distinct from old.role then
    if not (
      public.is_admin()
      or public.role_change_is_authorised()
      -- Dashboard, service key, or a direct connection — not an app user.
      or coalesce(current_setting('role', true), 'none')
           not in ('authenticated', 'anon')
    ) then
      raise exception
        'Role changes require an admin, an invite code, or an approved request.'
        using errcode = '42501';
    end if;
  end if;
  return new;
end $$;

-- =====================================================================
-- Convenience: one place to see who is who
--
-- The dashboard's Authentication → Users page reads `auth.users`, which has
-- no role column and can't be given one. Roles live on `public.profiles`.
-- This view puts the two side by side so you can find someone by how they
-- signed in, then edit them in the profiles table.
--
-- Read-only on purpose — edit `public.profiles` to make changes.
-- =====================================================================

create or replace view public.user_directory
with (security_invoker = true) as
  select
    p.id,
    p.name,
    coalesce(p.email, u.email)            as email,
    p.role,
    p.active,
    c.name                                as company,
    u.last_sign_in_at,
    u.email_confirmed_at is not null      as email_confirmed,
    p.created_at
  from public.profiles p
  left join auth.users u        on u.id = p.id
  left join public.companies c  on c.id = p.company_id;

grant select on public.user_directory to authenticated;
