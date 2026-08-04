-- =====================================================================
-- MY Site — isolation audit (READ ONLY)
--
-- Safe to run against production. It creates nothing, changes nothing and
-- deletes nothing — every statement below is a SELECT.
--
-- Paste the whole thing into the Supabase SQL editor and press Run. It
-- returns one table. Every row should say PASS.
--
-- This is NOT the same file as isolation_test.sql. That one seeds two fake
-- companies to prove they cannot see each other, and must only ever be run
-- against a throwaway database.
-- =====================================================================

with

-- 1. Every table in `public` must have row-level security switched on.
--    A table without it is readable by every customer, whatever its
--    policies say.
rls_off as (
  select string_agg(c.relname, ', ' order by c.relname) as names, count(*) as n
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity
),

-- 2. The file bucket lives outside `public`, so the sweep above misses it.
--    If this is off, every customer's photos and receipts are readable by
--    every other customer and no policy will save you.
storage_rls as (
  select coalesce(bool_and(c.relrowsecurity), false) as ok
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'storage' and c.relname = 'objects'
),

-- 3. RLS on with no policies denies everyone except the service role.
--    That is a half-finished migration OR a deliberate choice for tables
--    only an edge function should ever touch — Xero tokens, for instance,
--    which no signed-in user has any business reading. Reported for you to
--    judge rather than flagged as broken.
no_policies as (
  select string_agg(c.relname, ', ' order by c.relname) as names, count(*) as n
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind = 'r' and c.relrowsecurity
    and not exists (select 1 from pg_policy p where p.polrelid = c.oid)
),

-- 4. Every company-owned table should carry company_id. One that doesn't
--    cannot be scoped, however careful the policy looks.
missing_company_id as (
  select string_agg(t.tablename, ', ' order by t.tablename) as names, count(*) as n
  from pg_tables t
  where t.schemaname = 'public'
    and t.tablename in (
      'sites','work_allocations','daily_records','materials','site_photos',
      'weekly_submissions','query_comments','notifications','clock_records',
      'work_log_entries','allocation_progress','material_requests','tradesman_details')
    and not exists (
      select 1 from information_schema.columns c
      where c.table_schema = 'public' and c.table_name = t.tablename
        and c.column_name = 'company_id')
),

-- 5. Any row that belongs to no company is invisible to everyone and will
--    never be reachable again.
orphans as (
  select
    (select count(*) from public.profiles where company_id is null) as profiles,
    (select count(*) from public.sites where company_id is null)    as sites
),

-- 6. Views that read company data must be security_invoker. Without it a
--    view runs as its owner and cheerfully returns every company's rows.
leaky_views as (
  select string_agg(c.relname, ', ' order by c.relname) as names, count(*) as n
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind = 'v'
    and c.relname in ('day_totals','clock_day_totals','allocation_week_progress',
                      'seat_usage','user_directory')
    and coalesce((
      select option_value from pg_options_to_table(c.reloptions)
      where option_name = 'security_invoker'), 'false') <> 'true'
),

-- 7. Storage objects must sit under a company folder. Anything with fewer
--    than three folders is on the legacy read-only path.
legacy_objects as (
  select count(*) as n from storage.objects
  where bucket_id = 'site-evidence'
    and coalesce(array_length(storage.foldername(name), 1), 0) < 3
)

select * from (
  select 1 as ord, 'Row-level security on every public table' as check,
    case when (select n from rls_off) = 0 then 'PASS' else 'FAIL' end as result,
    coalesce((select names from rls_off), 'all tables protected') as detail
  union all
  select 2, 'Row-level security on storage.objects',
    case when (select ok from storage_rls) then 'PASS' else 'FAIL' end,
    case when (select ok from storage_rls) then 'the evidence bucket is protected'
         else 'EVERY customer file is readable by every customer' end
  union all
  select 3, 'Tables with no policy (service-role only)',
    case when (select n from no_policies) = 0 then 'PASS' else 'CHECK' end,
    coalesce((select names from no_policies)
             || ' — correct if only an edge function reads these',
             'every protected table has a policy')
  union all
  select 4, 'Company-owned tables carry company_id',
    case when (select n from missing_company_id) = 0 then 'PASS' else 'FAIL' end,
    coalesce((select names from missing_company_id), 'all scoped')
  union all
  select 5, 'No rows stranded without a company',
    case when (select profiles + sites from orphans) = 0 then 'PASS' else 'CHECK' end,
    (select profiles || ' profiles, ' || sites || ' sites with no company' from orphans)
  union all
  select 6, 'Reporting views run as the caller',
    case when (select n from leaky_views) = 0 then 'PASS' else 'FAIL' end,
    coalesce((select names from leaky_views), 'all security_invoker')
  union all
  select 7, 'Stored files sit under a company folder',
    case when (select n from legacy_objects) = 0 then 'PASS' else 'INFO' end,
    (select n || ' file(s) on the legacy path (readable, not writable)' from legacy_objects)
) checks
order by ord;
