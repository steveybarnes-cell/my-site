-- =====================================================================
-- Cross-company isolation test
--
-- Two companies, real data in both, then read everything as each of six
-- users and assert that nothing crosses the boundary.
--
-- This exists because row-level security is only as strong as its weakest
-- policy, and a policy is one forgotten `company_id =` away from leaking a
-- customer's payroll to a competitor. Reading the policies and nodding is
-- not a test. This is.
--
-- Run against a scratch database with the full migration chain applied.
-- Every assertion raises on failure, so a non-zero exit means do not ship.
-- =====================================================================

\set ON_ERROR_STOP on
set client_min_messages to notice;

-- ---------------------------------------------------------------------
-- Assertion helper. Raises with a readable message rather than returning
-- a row nobody reads.
-- ---------------------------------------------------------------------
create or replace function pg_temp.expect(label text, got bigint, want bigint)
returns void language plpgsql as $$
begin
  if got is distinct from want then
    raise exception 'FAIL  %  (saw %, expected %)', label, got, want;
  end if;
  raise notice 'pass  %', label;
end $$;

/* Act as a given user. RLS reads auth.uid() from this setting, which is how
   PostgREST does it too — so this exercises the real policies, not a
   simulation of them. */
create or replace function pg_temp.act_as(p_user uuid)
returns void language plpgsql as $$
begin
  -- `false` = session scope, not transaction scope. With `true` the setting
  -- is discarded at the end of the statement that set it, so every later
  -- query runs with no user at all and every count comes back zero — which
  -- looks exactly like perfect isolation and proves nothing.
  perform set_config('request.jwt.claim.sub', p_user::text, false);
  perform set_config('request.jwt.claim.role', 'authenticated', false);
end $$;

-- =====================================================================
-- Two companies, three people each
-- =====================================================================
begin;
set local role postgres;

-- The role-change guard exists to stop someone promoting themselves. It also
-- stops a test seeding six users, so it is switched off for the seed and back
-- on before a single assertion runs. Nothing below this point has it disabled.
alter table public.profiles disable trigger profiles_enforce_role_change;

insert into auth.users (id, email) values
  ('a0000000-0000-0000-0000-000000000001', 'admin-a@example.com'),
  ('a0000000-0000-0000-0000-000000000002', 'manager-a@example.com'),
  ('a0000000-0000-0000-0000-000000000003', 'trade-a@example.com'),
  ('b0000000-0000-0000-0000-000000000001', 'admin-b@example.com'),
  ('b0000000-0000-0000-0000-000000000002', 'manager-b@example.com'),
  ('b0000000-0000-0000-0000-000000000003', 'trade-b@example.com')
on conflict (id) do nothing;

insert into public.companies (id, name, slug) values
  ('aaaaaaaa-0000-0000-0000-000000000000', 'Alpha Build',  'alpha-build'),
  ('bbbbbbbb-0000-0000-0000-000000000000', 'Bravo Joinery','bravo-joinery')
on conflict (id) do nothing;

insert into public.profiles (id, name, email, role, company_id) values
  ('a0000000-0000-0000-0000-000000000001','Alpha Admin','admin-a@example.com','Admin','aaaaaaaa-0000-0000-0000-000000000000'),
  ('a0000000-0000-0000-0000-000000000002','Alpha Manager','manager-a@example.com','Site Manager','aaaaaaaa-0000-0000-0000-000000000000'),
  ('a0000000-0000-0000-0000-000000000003','Alpha Trade','trade-a@example.com','Tradesman','aaaaaaaa-0000-0000-0000-000000000000'),
  ('b0000000-0000-0000-0000-000000000001','Bravo Admin','admin-b@example.com','Admin','bbbbbbbb-0000-0000-0000-000000000000'),
  ('b0000000-0000-0000-0000-000000000002','Bravo Manager','manager-b@example.com','Site Manager','bbbbbbbb-0000-0000-0000-000000000000'),
  ('b0000000-0000-0000-0000-000000000003','Bravo Trade','trade-b@example.com','Tradesman','bbbbbbbb-0000-0000-0000-000000000000')
on conflict (id) do update set company_id = excluded.company_id, role = excluded.role;

insert into public.sites (id, name, company_id, site_manager_id) values
  ('a1111111-0000-0000-0000-000000000000','Alpha Site','aaaaaaaa-0000-0000-0000-000000000000','a0000000-0000-0000-0000-000000000002'),
  ('b1111111-0000-0000-0000-000000000000','Bravo Site','bbbbbbbb-0000-0000-0000-000000000000','b0000000-0000-0000-0000-000000000002')
on conflict (id) do nothing;

insert into public.work_allocations (id, site_id, tradesman_id, date, task_description, company_id) values
  ('a2222222-0000-0000-0000-000000000000','a1111111-0000-0000-0000-000000000000','a0000000-0000-0000-0000-000000000003',current_date,'Alpha work','aaaaaaaa-0000-0000-0000-000000000000'),
  ('b2222222-0000-0000-0000-000000000000','b1111111-0000-0000-0000-000000000000','b0000000-0000-0000-0000-000000000003',current_date,'Bravo work','bbbbbbbb-0000-0000-0000-000000000000')
on conflict (id) do nothing;

insert into public.daily_records (id, user_id, site_id, date, total_hours, description, company_id) values
  ('a3333333-0000-0000-0000-000000000000','a0000000-0000-0000-0000-000000000003','a1111111-0000-0000-0000-000000000000',current_date,8,'Alpha day','aaaaaaaa-0000-0000-0000-000000000000'),
  ('b3333333-0000-0000-0000-000000000000','b0000000-0000-0000-0000-000000000003','b1111111-0000-0000-0000-000000000000',current_date,8,'Bravo day','bbbbbbbb-0000-0000-0000-000000000000')
on conflict (id) do nothing;

insert into public.materials (id, user_id, site_id, date, supplier, cost_ex_vat, company_id) values
  ('a4444444-0000-0000-0000-000000000000','a0000000-0000-0000-0000-000000000003','a1111111-0000-0000-0000-000000000000',current_date,'Alpha Supplies',100,'aaaaaaaa-0000-0000-0000-000000000000'),
  ('b4444444-0000-0000-0000-000000000000','b0000000-0000-0000-0000-000000000003','b1111111-0000-0000-0000-000000000000',current_date,'Bravo Supplies',200,'bbbbbbbb-0000-0000-0000-000000000000')
on conflict (id) do nothing;

insert into public.site_photos (id, user_id, site_id, type, description, storage_path, company_id) values
  ('a5555555-0000-0000-0000-000000000000','a0000000-0000-0000-0000-000000000003','a1111111-0000-0000-0000-000000000000','Progress','Alpha photo','aaaaaaaa-0000-0000-0000-000000000000/a1111111-0000-0000-0000-000000000000/a0000000-0000-0000-0000-000000000003/a.jpg','aaaaaaaa-0000-0000-0000-000000000000'),
  ('b5555555-0000-0000-0000-000000000000','b0000000-0000-0000-0000-000000000003','b1111111-0000-0000-0000-000000000000','Progress','Bravo photo','bbbbbbbb-0000-0000-0000-000000000000/b1111111-0000-0000-0000-000000000000/b0000000-0000-0000-0000-000000000003/b.jpg','bbbbbbbb-0000-0000-0000-000000000000')
on conflict (id) do nothing;

insert into public.weekly_submissions (id, user_id, week_ending, invoice_number, total_hours, labour_rate, company_id) values
  ('a6666666-0000-0000-0000-000000000000','a0000000-0000-0000-0000-000000000003',current_date,'ALPHA-1',38,22,'aaaaaaaa-0000-0000-0000-000000000000'),
  ('b6666666-0000-0000-0000-000000000000','b0000000-0000-0000-0000-000000000003',current_date,'BRAVO-1',40,30,'bbbbbbbb-0000-0000-0000-000000000000')
on conflict (id) do nothing;

insert into public.work_log_entries (id, user_id, site_id, date, description, minutes, company_id) values
  ('a7777777-0000-0000-0000-000000000000','a0000000-0000-0000-0000-000000000003','a1111111-0000-0000-0000-000000000000',current_date,'Alpha line',300,'aaaaaaaa-0000-0000-0000-000000000000'),
  ('b7777777-0000-0000-0000-000000000000','b0000000-0000-0000-0000-000000000003','b1111111-0000-0000-0000-000000000000',current_date,'Bravo line',300,'bbbbbbbb-0000-0000-0000-000000000000')
on conflict (id) do nothing;

insert into public.material_requests (id, user_id, site_id, description, company_id) values
  ('a8888888-0000-0000-0000-000000000000','a0000000-0000-0000-0000-000000000003','a1111111-0000-0000-0000-000000000000','Alpha plasterboard','aaaaaaaa-0000-0000-0000-000000000000'),
  ('b8888888-0000-0000-0000-000000000000','b0000000-0000-0000-0000-000000000003','b1111111-0000-0000-0000-000000000000','Bravo plasterboard','bbbbbbbb-0000-0000-0000-000000000000')
on conflict (id) do nothing;

insert into public.subscriptions (company_id, plan, status, seats) values
  ('aaaaaaaa-0000-0000-0000-000000000000','starter','active',5),
  ('bbbbbbbb-0000-0000-0000-000000000000','starter','active',5)
on conflict (company_id) do nothing;

-- Storage objects, both layouts, in both companies.
insert into storage.buckets (id, name, public) values ('site-evidence','site-evidence',false)
  on conflict (id) do nothing;
insert into storage.objects (bucket_id, name) values
  ('site-evidence','aaaaaaaa-0000-0000-0000-000000000000/a1111111-0000-0000-0000-000000000000/a0000000-0000-0000-0000-000000000003/a.jpg'),
  ('site-evidence','bbbbbbbb-0000-0000-0000-000000000000/b1111111-0000-0000-0000-000000000000/b0000000-0000-0000-0000-000000000003/b.jpg'),
  ('site-evidence','a1111111-0000-0000-0000-000000000000/a0000000-0000-0000-0000-000000000003/legacy-a.jpg'),
  ('site-evidence','b1111111-0000-0000-0000-000000000000/b0000000-0000-0000-0000-000000000003/legacy-b.jpg')
on conflict do nothing;

alter table public.profiles enable trigger profiles_enforce_role_change;

-- Supabase grants the `authenticated` role broad table privileges by default
-- and relies on row-level security to do the actual restricting. Replicated
-- here so the test exercises the policies rather than the grants — if it only
-- passed because a GRANT was missing, it would prove nothing about RLS.
grant usage on schema public, storage to authenticated, anon;
grant all on all tables in schema public to authenticated;
grant all on storage.objects, storage.buckets to authenticated;

commit;

-- =====================================================================
-- The test itself. Everything below runs as `authenticated`, which is the
-- role PostgREST uses — so RLS is actually in force.
-- =====================================================================
set role authenticated;

-- ---------- Alpha's admin: sees all of Alpha, none of Bravo ----------
select pg_temp.act_as('a0000000-0000-0000-0000-000000000001');

select pg_temp.expect('admin A · companies',        (select count(*) from public.companies), 1);
select pg_temp.expect('admin A · profiles',         (select count(*) from public.profiles), 3);
select pg_temp.expect('admin A · sites',            (select count(*) from public.sites), 1);
select pg_temp.expect('admin A · allocations',      (select count(*) from public.work_allocations), 1);
select pg_temp.expect('admin A · daily records',    (select count(*) from public.daily_records), 1);
select pg_temp.expect('admin A · materials',        (select count(*) from public.materials), 1);
select pg_temp.expect('admin A · photos',           (select count(*) from public.site_photos), 1);
select pg_temp.expect('admin A · invoices',         (select count(*) from public.weekly_submissions), 1);
select pg_temp.expect('admin A · work log',         (select count(*) from public.work_log_entries), 1);
select pg_temp.expect('admin A · material requests',(select count(*) from public.material_requests), 1);
select pg_temp.expect('admin A · subscriptions',    (select count(*) from public.subscriptions), 1);

-- Named directly by id, which is the attack: guessing or leaking a uuid.
select pg_temp.expect('admin A · Bravo site by id',
  (select count(*) from public.sites where id = 'b1111111-0000-0000-0000-000000000000'), 0);
select pg_temp.expect('admin A · Bravo invoice by id',
  (select count(*) from public.weekly_submissions where id = 'b6666666-0000-0000-0000-000000000000'), 0);
select pg_temp.expect('admin A · Bravo subscription by id',
  (select count(*) from public.subscriptions where company_id = 'bbbbbbbb-0000-0000-0000-000000000000'), 0);

-- Storage, both layouts.
select pg_temp.expect('admin A · Bravo storage objects',
  (select count(*) from storage.objects where name like 'bbbbbbbb%'), 0);
select pg_temp.expect('admin A · Bravo legacy storage',
  (select count(*) from storage.objects where name like 'b1111111%'), 0);
select pg_temp.expect('admin A · own storage visible',
  (select count(*) from storage.objects where name like 'aaaaaaaa%'), 1);

-- Views must be scoped too — a security_invoker slip here leaks everything.
select pg_temp.expect('admin A · day_totals',      (select count(*) from public.day_totals), 1);
select pg_temp.expect('admin A · seat_usage',      (select count(*) from public.seat_usage), 1);
select pg_temp.expect('admin A · week progress',   (select count(*) from public.allocation_week_progress), 1);

-- ---------- Bravo's admin: the mirror image ----------
select pg_temp.act_as('b0000000-0000-0000-0000-000000000001');
select pg_temp.expect('admin B · sites',            (select count(*) from public.sites), 1);
select pg_temp.expect('admin B · profiles',         (select count(*) from public.profiles), 3);
select pg_temp.expect('admin B · Alpha site by id',
  (select count(*) from public.sites where id = 'a1111111-0000-0000-0000-000000000000'), 0);
select pg_temp.expect('admin B · Alpha storage',
  (select count(*) from storage.objects where name like 'aaaaaaaa%'), 0);
select pg_temp.expect('admin B · day_totals',       (select count(*) from public.day_totals), 1);

-- ---------- A tradesman sees only himself ----------
select pg_temp.act_as('a0000000-0000-0000-0000-000000000003');
select pg_temp.expect('trade A · own daily records',(select count(*) from public.daily_records), 1);
select pg_temp.expect('trade A · own invoices',     (select count(*) from public.weekly_submissions), 1);
select pg_temp.expect('trade A · Bravo anything',
  (select count(*) from public.daily_records where company_id = 'bbbbbbbb-0000-0000-0000-000000000000'), 0);

-- ---------- Writing across the boundary must fail ----------
select pg_temp.act_as('a0000000-0000-0000-0000-000000000001');
do $$
begin
  begin
    insert into public.sites (name, company_id) values ('Sneaky','bbbbbbbb-0000-0000-0000-000000000000');
    raise exception 'FAIL  admin A inserted a site into Bravo';
  exception when insufficient_privilege then
    raise notice 'pass  admin A cannot insert into Bravo';
  end;
  begin
    update public.sites set name = 'Hijacked'
      where id = 'b1111111-0000-0000-0000-000000000000';
    if found then raise exception 'FAIL  admin A updated a Bravo site'; end if;
    raise notice 'pass  admin A cannot update a Bravo site';
  end;
end $$;

-- ---------- A user with no company sees nothing ----------
select pg_temp.act_as('00000000-0000-0000-0000-0000000000ff');
select pg_temp.expect('orphan · companies',   (select count(*) from public.companies), 0);
select pg_temp.expect('orphan · sites',       (select count(*) from public.sites), 0);
select pg_temp.expect('orphan · daily records',(select count(*) from public.daily_records), 0);
select pg_temp.expect('orphan · storage',     (select count(*) from storage.objects), 0);

reset role;

-- ---------- storage.objects must have RLS on ----------
-- Its own check because it lives outside the public schema and so is missed
-- by the sweep below. If this is ever off, every customer's photos and
-- receipts are readable by every other customer, and no policy will save you.
do $$
begin
  if not (select c.relrowsecurity from pg_class c
          join pg_namespace n on n.oid = c.relnamespace
          where n.nspname = 'storage' and c.relname = 'objects') then
    raise exception 'FAIL  row-level security is OFF on storage.objects';
  end if;
  raise notice 'pass  storage.objects has row-level security enabled';
end $$;

-- ---------- Every public table must have RLS on ----------
do $$
declare v_unprotected text;
begin
  select string_agg(c.relname, ', ') into v_unprotected
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity;
  if v_unprotected is not null then
    raise exception 'FAIL  tables without row-level security: %', v_unprotected;
  end if;
  raise notice 'pass  every public table has row-level security enabled';
end $$;

\echo ''
\echo '================================================'
\echo ' ISOLATION TEST PASSED — no data crosses tenants'
\echo '================================================'
