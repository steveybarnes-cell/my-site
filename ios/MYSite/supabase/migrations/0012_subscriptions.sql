-- =====================================================================
-- MY Site — 0012: subscriptions, seats and per-company branding
-- Run AFTER 0011_command_centre.sql. Safe to re-run.
--
-- Turns a single-firm app into something other firms pay for.
--
-- One design decision runs through all of this and is worth stating plainly
-- because it looks like a bug otherwise: **billing fails open.**
--
-- If a subscription row is missing, unreadable, or the webhook has not
-- arrived, a company keeps working. A hard lockout would mean a Stripe
-- outage, a card that declined at 3am, or a webhook we failed to process
-- stops a bricklayer recording the day he has just worked — and the record
-- of that day is gone, because he is not going to type it in again on
-- Monday. Losing a customer's data to protect our revenue is the wrong way
-- round. Lapsed companies go read-only, loudly, after a grace period, and
-- somebody rings them.
-- =====================================================================

-- =====================================================================
-- 1. What a company is paying for
-- =====================================================================

do $$ begin
  create type subscription_status as enum
    ('trialing', 'active', 'past_due', 'canceled', 'paused');
exception when duplicate_object then null;
end $$;

create table if not exists public.subscriptions (
  company_id             uuid primary key references public.companies(id) on delete cascade,
  plan                   text not null default 'starter',
  status                 subscription_status not null default 'trialing',
  seats                  integer not null default 5 check (seats > 0),
  -- Stripe's identifiers. Nullable because a trial starts before anyone has
  -- paid, and because a company created by hand for testing has neither.
  stripe_customer_id     text unique,
  stripe_subscription_id text unique,
  current_period_end     timestamptz,
  trial_ends_at          timestamptz,
  -- How long after a failed payment we keep them writing. Per-company so a
  -- customer mid-dispute can be given room without a code change.
  grace_days             integer not null default 14 check (grace_days >= 0),
  cancel_at_period_end   boolean not null default false,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now()
);

alter table public.companies
  add column if not exists brand_primary  text not null default '#7F9E4B',
  add column if not exists brand_logo_url text not null default '',
  add column if not exists subdomain      text;

-- Subdomains are a public namespace: two firms cannot both be `acme`.
create unique index if not exists companies_subdomain_key
  on public.companies (lower(subdomain)) where subdomain is not null;

alter table public.subscriptions enable row level security;

-- A company sees its own subscription and nobody else's. Nothing here is
-- writable from the app or the portal at all — only the Stripe webhook,
-- which runs with the service role and bypasses RLS. A customer editing
-- their own subscription row is not a feature.
drop policy if exists sub_select on public.subscriptions;
create policy sub_select on public.subscriptions for select using (
  company_id = public.current_company_id()
);

grant select on public.subscriptions to authenticated;
revoke insert, update, delete on public.subscriptions from authenticated;
revoke all on public.subscriptions from anon;

create or replace function public.touch_subscription()
returns trigger language plpgsql as $$
begin new.updated_at := now(); return new; end $$;

drop trigger if exists subscriptions_touch on public.subscriptions;
create trigger subscriptions_touch before update on public.subscriptions
  for each row execute function public.touch_subscription();

-- =====================================================================
-- 2. May this company still write?
--
-- `stable`, not `volatile`, so Postgres evaluates it once per statement
-- rather than once per row — this ends up inside policies on tables with
-- thousands of rows.
--
-- Every failure path returns true. Read the comment at the top of the file.
-- =====================================================================

create or replace function public.company_can_write()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(
    (
      select case s.status
               when 'active'   then true
               when 'trialing' then coalesce(s.trial_ends_at, now() + interval '1 day') > now()
               -- A failed payment is a conversation, not a wall.
               when 'past_due' then coalesce(s.current_period_end, now())
                                      + (s.grace_days || ' days')::interval > now()
               when 'paused'   then false
               when 'canceled' then coalesce(s.current_period_end, now()) > now()
             end
      from public.subscriptions s
      where s.company_id = public.current_company_id()
    ),
    true   -- no subscription row at all: an existing or self-hosted company
  )
$$;

grant execute on function public.company_can_write() to authenticated;

-- What the app and the portal show the user. Never used to authorise
-- anything — that is `company_can_write()` inside the policies below.
create or replace function public.my_subscription()
returns table (
  plan text, status subscription_status, seats integer, seats_used bigint,
  current_period_end timestamptz, trial_ends_at timestamptz,
  can_write boolean, cancel_at_period_end boolean
) language sql stable security definer set search_path = public as $$
  select
    coalesce(s.plan, 'none'),
    coalesce(s.status, 'active'::subscription_status),
    coalesce(s.seats, 0),
    (select count(*) from public.profiles p where p.company_id = public.current_company_id()),
    s.current_period_end,
    s.trial_ends_at,
    public.company_can_write(),
    coalesce(s.cancel_at_period_end, false)
  from (select 1) x
  left join public.subscriptions s on s.company_id = public.current_company_id()
$$;

revoke execute on function public.my_subscription() from anon;
grant execute on function public.my_subscription() to authenticated;

-- =====================================================================
-- 3. Read-only when lapsed
--
-- Applied to the tables where new work is created. Deliberately NOT applied
-- to daily_records, work_log_entries or clock_records: those are somebody's
-- record of a day they actually worked, and a billing problem between two
-- companies is no reason to lose it. They keep writing; the office chases
-- the invoice.
-- =====================================================================

drop policy if exists site_write on public.sites;
create policy site_write on public.sites for all using (
  company_id = public.current_company_id() and public.is_admin()
) with check (
  company_id = public.current_company_id() and public.is_admin()
  and public.company_can_write()
);

drop policy if exists alloc_write on public.work_allocations;
create policy alloc_write on public.work_allocations for all using (
  company_id = public.current_company_id()
  and (public.is_admin() or public.manages_site(site_id))
) with check (
  company_id = public.current_company_id()
  and (public.is_admin() or public.manages_site(site_id))
  and public.company_can_write()
);

-- =====================================================================
-- 4. Seats
--
-- Counted, surfaced, and deliberately not enforced at the database. A firm
-- that hires a sixth man on a five-seat plan should be invoiced for him,
-- not have him unable to clock on at seven in the morning.
-- =====================================================================

create or replace view public.seat_usage
with (security_invoker = true) as
select
  c.id as company_id,
  c.name,
  coalesce(s.seats, 0)                                        as seats,
  count(p.id)                                                 as people,
  greatest(0, count(p.id) - coalesce(s.seats, 0))              as over_by
from public.companies c
left join public.subscriptions s on s.company_id = c.id
left join public.profiles p on p.company_id = c.id
group by c.id, c.name, s.seats;

grant select on public.seat_usage to authenticated;
revoke all on public.seat_usage from anon;

-- =====================================================================
-- 5. Give every existing company a subscription
--
-- Existing companies get an active row rather than a trial, so nothing that
-- works today stops working the moment this migration runs.
-- =====================================================================

insert into public.subscriptions (company_id, plan, status, seats)
select c.id, 'founding', 'active', 25
from public.companies c
where not exists (select 1 from public.subscriptions s where s.company_id = c.id);
