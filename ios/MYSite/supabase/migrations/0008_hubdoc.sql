-- =====================================================================
-- MPG Site Records — 0008: Hubdoc delivery
-- Run AFTER 0007_dashboard_role_editing.sql.
--
-- Hubdoc has no public API. The only programmatic way to get a document in
-- is the unique email address each Hubdoc organisation is given — you email
-- the receipt to it as an attachment. So "send to Hubdoc" is, concretely,
-- "send an email with the receipt attached".
--
-- Two things follow from that, and both are why this migration exists rather
-- than a hardcoded address in the Edge Function:
--
--   • The address is per Hubdoc organisation, and this database is now
--     multi-tenant. One company's receipts must never land in another
--     company's Hubdoc, so the address belongs on `companies`.
--   • Email is fire-and-forget. Nothing bounces back into the app to say a
--     receipt arrived, so without a record of what was sent there is no way
--     to answer "did that receipt go?" — hence `hubdoc_deliveries`.
--
-- Safe to re-run.
-- =====================================================================

-- =====================================================================
-- 1. Where each company's receipts go
-- =====================================================================

alter table public.companies
  add column if not exists hubdoc_email text;

comment on column public.companies.hubdoc_email is
  'The Hubdoc organisation''s unique upload address. Found in Hubdoc under '
  'Upload Document, or Organization settings. Null disables Hubdoc delivery '
  'for this company.';

-- A wrong address here silently sends receipts to a stranger, so the shape is
-- checked rather than trusted. Not full RFC 5322 — just enough to catch a
-- typo or a pasted sentence.
alter table public.companies
  drop constraint if exists companies_hubdoc_email_shape;
alter table public.companies
  add constraint companies_hubdoc_email_shape
  check (hubdoc_email is null or hubdoc_email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$');

-- =====================================================================
-- 2. What was sent, and what happened
-- =====================================================================

create table if not exists public.hubdoc_deliveries (
  id            uuid primary key default gen_random_uuid(),
  company_id    uuid not null references public.companies(id) on delete cascade,
  site_photo_id uuid not null references public.site_photos(id) on delete cascade,
  to_email      text not null,
  status        text not null default 'sent',
  provider_id   text,
  error         text,
  created_at    timestamptz not null default now(),
  constraint hubdoc_deliveries_status_check
    check (status in ('sent', 'failed'))
);

-- One successful delivery per receipt. A tradesman tapping save twice, or a
-- retry after a timeout that actually succeeded, would otherwise put the same
-- receipt into the bookkeeping twice — which is worse than not sending it,
-- because someone has to notice and unpick it.
create unique index if not exists hubdoc_deliveries_once
  on public.hubdoc_deliveries (site_photo_id)
  where status = 'sent';

create index if not exists hubdoc_deliveries_company_idx
  on public.hubdoc_deliveries (company_id, created_at desc);

alter table public.hubdoc_deliveries enable row level security;

-- Readable by the company that owns it, so an admin can answer "did it go?".
-- No insert/update/delete policy at all: rows are written by the Edge Function
-- using the service key, which bypasses RLS. Nothing the app can say should be
-- able to fabricate a delivery record.
drop policy if exists hubdoc_deliveries_select on public.hubdoc_deliveries;
create policy hubdoc_deliveries_select on public.hubdoc_deliveries for select
  using (company_id = public.current_company_id());

-- Granted explicitly rather than left to Supabase's default privileges for new
-- tables in `public`. Those defaults would work, but they also hand the table
-- to `anon`, and a policy is a thinner thing to be relying on than simply not
-- granting the privilege.
grant select on public.hubdoc_deliveries to authenticated;
revoke all on public.hubdoc_deliveries from anon;

-- =====================================================================
-- 3. Reading and setting the address from the app
--
-- `companies` has no policy letting an admin update it, and it shouldn't get
-- a blanket one — that row also carries the company's identity. A function
-- keeps the writable surface to exactly this column.
-- =====================================================================

create or replace function public.set_hubdoc_email(p_email text)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_company uuid := public.current_company_id();
  v_clean   text := nullif(btrim(coalesce(p_email, '')), '');
begin
  if not public.is_admin() then
    raise exception 'Only an admin can change the Hubdoc address.'
      using errcode = '42501';
  end if;
  if v_company is null then
    raise exception 'Your account is not attached to a company.'
      using errcode = '22023';
  end if;

  -- The check constraint would catch this anyway, but its message names the
  -- constraint rather than the problem.
  if v_clean is not null
     and v_clean !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    raise exception 'That does not look like an email address.'
      using errcode = '22023';
  end if;

  update public.companies set hubdoc_email = v_clean where id = v_company;
end $$;

revoke execute on function public.set_hubdoc_email(text) from anon;
grant execute on function public.set_hubdoc_email(text) to authenticated;

create or replace function public.hubdoc_settings()
returns table (hubdoc_email text, delivered bigint, failed bigint)
language sql stable security definer set search_path = public as $$
  select
    c.hubdoc_email,
    (select count(*) from public.hubdoc_deliveries d
      where d.company_id = c.id and d.status = 'sent'),
    (select count(*) from public.hubdoc_deliveries d
      where d.company_id = c.id and d.status = 'failed')
  from public.companies c
  where c.id = public.current_company_id()
$$;

revoke execute on function public.hubdoc_settings() from anon;
grant execute on function public.hubdoc_settings() to authenticated;
