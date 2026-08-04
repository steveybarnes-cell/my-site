-- =====================================================================
-- MY Site — 0010: the work log, and the day → week join
-- Run AFTER 0009_self_serve_signup.sql. Safe to re-run.
--
-- Until now a day was one `daily_records` row: one description, one hours
-- figure. That holds right up until a day is split, which is most days — an
-- hour of snagging at one site and the rest on contract work at another is
-- two jobs, two sites and potentially two charge codes, flattened into one
-- text box exactly where the money is.
--
-- `work_log_entries` is the line level. `daily_records` stays, as the day's
-- summary, written from the lines rather than typed.
--
-- Nothing here changes an existing row. Days already recorded keep working;
-- they simply have no lines behind them.
-- =====================================================================

-- =====================================================================
-- 1. Work log entries
--
-- `minutes` as an integer, not hours as a numeric. Quarter- and half-hours
-- are the real unit of a working day, and a numeric column is how 7.499999
-- ends up on somebody's invoice.
--
-- `voided` rather than DELETE. Once a week has been billed, a row vanishing
-- rewrites what was invoiced with nothing left to show it happened. It is
-- also the only option that survives the app's offline queue, which speaks
-- upsert and nothing else — a delete made with no signal would be undone by
-- the next full reload.
-- =====================================================================

create table if not exists public.work_log_entries (
  id            uuid primary key default gen_random_uuid(),
  company_id    uuid not null references public.companies(id) on delete cascade
                  default public.current_company_id(),
  user_id       uuid not null references public.profiles(id) on delete cascade,
  site_id       uuid not null references public.sites(id) on delete cascade,
  allocation_id uuid references public.work_allocations(id) on delete set null,
  date          date not null default current_date,
  description   text not null default '',
  category      text not null default 'Contract Work',
  minutes       integer not null default 0 check (minutes >= 0 and minutes <= 1440),
  voided        boolean not null default false,
  created_at    timestamptz not null default now()
);

-- The app reads a single person's single day, constantly — that is the Today
-- screen redrawing. Voided rows are excluded from the index because they are
-- excluded from every total.
create index if not exists work_log_user_date
  on public.work_log_entries (user_id, date desc) where not voided;
create index if not exists work_log_company_date
  on public.work_log_entries (company_id, date desc) where not voided;

alter table public.work_log_entries enable row level security;

-- Same shape as daily_records: your own lines, plus admins, plus the manager
-- of the site the work was on.
drop policy if exists work_log_select on public.work_log_entries;
create policy work_log_select on public.work_log_entries for select using (
  company_id = public.current_company_id()
  and (user_id = auth.uid() or public.is_admin() or public.manages_site(site_id))
);

drop policy if exists work_log_write on public.work_log_entries;
create policy work_log_write on public.work_log_entries for all using (
  company_id = public.current_company_id()
  and (user_id = auth.uid() or public.is_admin())
) with check (
  company_id = public.current_company_id()
  and (user_id = auth.uid() or public.is_admin())
);

grant select, insert, update on public.work_log_entries to authenticated;
revoke all on public.work_log_entries from anon;

-- =====================================================================
-- 2. AI captions on photos
--
-- Its own column rather than reusing `description`. The description is what
-- the person typed, and a recap run that overwrote it would destroy the one
-- account of the photo that a human actually vouched for.
-- =====================================================================

alter table public.site_photos
  add column if not exists ai_caption text not null default '';

-- =====================================================================
-- 3. What a day added up to
--
-- A view rather than a stored total, because a stored total is wrong from
-- the moment anything behind it is corrected — and corrections are the norm
-- here: the whole app is built on "fix it and the figures move".
--
-- security_invoker, so the caller's RLS applies. Without it this view would
-- happily read every company's hours.
-- =====================================================================

create or replace view public.day_totals
with (security_invoker = true) as
select
  w.company_id,
  w.user_id,
  w.date,
  sum(w.minutes)                       as logged_minutes,
  round(sum(w.minutes) / 60.0, 2)      as logged_hours,
  count(*)                             as line_count,
  -- Site of the longest single line. Not `min(site_id)` — Postgres has no
  -- min() for uuid, and even if it did, the smallest uuid is a meaningless
  -- answer to "where was this day worked".
  (array_agg(w.site_id order by w.minutes desc))[1] as main_site_id
from public.work_log_entries w
where not w.voided
group by w.company_id, w.user_id, w.date;

grant select on public.day_totals to authenticated;
revoke all on public.day_totals from anon;

-- =====================================================================
-- 4. Clock hours per day
--
-- Closed spans only. Somebody still on site has not finished, and a total
-- that grows while you look at it is not a total.
-- =====================================================================

create or replace view public.clock_day_totals
with (security_invoker = true) as
select
  c.company_id,
  c.user_id,
  c.date,
  round(sum(extract(epoch from (c.clock_out_time - c.clock_in_time))) / 3600.0, 2)
                                                                      as clocked_hours,
  min(c.clock_in_time)                                                as first_in,
  max(c.clock_out_time)                                               as last_out
from public.clock_records c
where c.clock_out_time is not null
group by c.company_id, c.user_id, c.date;

grant select on public.clock_day_totals to authenticated;
revoke all on public.clock_day_totals from anon;
