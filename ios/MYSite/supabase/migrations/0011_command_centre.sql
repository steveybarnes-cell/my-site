-- =====================================================================
-- MY Site — 0011: progress, and material requests
-- Run AFTER 0010_work_log.sql. Safe to re-run.
--
-- Two things an allocation could not carry until now:
--
--   how far along it is   — a boarding job is 50% done, not "Allocated"
--   what it's short of    — the plasterboard nobody ordered
--
-- Both currently happen on the phone, verbally, and are lost.
-- =====================================================================

-- =====================================================================
-- 1. Progress on a job
--
-- The percentage lives on the allocation because that is what every screen
-- reads, and the history lives in its own table because "it was 80% on
-- Thursday and 50% on Friday" is a conversation worth being able to have.
--
-- Denormalising the current value is a deliberate trade: it can drift from
-- the log if something writes one without the other, so the trigger below
-- makes that impossible rather than relying on everyone remembering.
-- =====================================================================

alter table public.work_allocations
  add column if not exists percent_complete integer not null default 0
    check (percent_complete between 0 and 100),
  add column if not exists progress_note text not null default '',
  add column if not exists progress_updated_at timestamptz,
  add column if not exists target_date date;

create table if not exists public.allocation_progress (
  id            uuid primary key default gen_random_uuid(),
  company_id    uuid not null references public.companies(id) on delete cascade
                  default public.current_company_id(),
  allocation_id uuid not null references public.work_allocations(id) on delete cascade,
  user_id       uuid not null references public.profiles(id) on delete cascade
                  default auth.uid(),
  percent       integer not null check (percent between 0 and 100),
  note          text not null default '',
  created_at    timestamptz not null default now()
);

create index if not exists alloc_progress_alloc
  on public.allocation_progress (allocation_id, created_at desc);

-- Writing a progress entry IS how you move the allocation. One write, so
-- the headline figure and the history behind it cannot disagree.
create or replace function public.apply_allocation_progress()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  update public.work_allocations
     set percent_complete    = new.percent,
         progress_note       = new.note,
         progress_updated_at = new.created_at,
         status = case
                    when new.percent >= 100 then 'Completed'::allocation_status
                    when status = 'Allocated' then 'In Progress'::allocation_status
                    else status
                  end
   where id = new.allocation_id;
  return new;
end $$;

drop trigger if exists allocation_progress_applied on public.allocation_progress;
create trigger allocation_progress_applied
  after insert on public.allocation_progress
  for each row execute function public.apply_allocation_progress();

alter table public.allocation_progress enable row level security;

drop policy if exists alloc_progress_select on public.allocation_progress;
create policy alloc_progress_select on public.allocation_progress for select using (
  company_id = public.current_company_id()
);

-- A tradesman updates his own jobs; admins and the site's manager can too.
drop policy if exists alloc_progress_insert on public.allocation_progress;
create policy alloc_progress_insert on public.allocation_progress for insert with check (
  company_id = public.current_company_id()
  and (
    public.is_admin()
    or exists (
      select 1 from public.work_allocations a
      where a.id = allocation_id
        and (a.tradesman_id = auth.uid() or public.manages_site(a.site_id))
    )
  )
);

grant select, insert on public.allocation_progress to authenticated;
revoke all on public.allocation_progress from anon;

-- =====================================================================
-- 2. Material requests
--
-- Deliberately not an order. This is a tradesman saying "I need twelve
-- sheets of 12.5mm by Thursday" and the office seeing it in one place
-- instead of in a text message at ten at night.
-- =====================================================================

do $$ begin
  create type material_request_status as enum
    ('Requested', 'Ordered', 'Delivered', 'Declined');
exception when duplicate_object then null;
end $$;

create table if not exists public.material_requests (
  id            uuid primary key default gen_random_uuid(),
  company_id    uuid not null references public.companies(id) on delete cascade
                  default public.current_company_id(),
  user_id       uuid not null references public.profiles(id) on delete cascade
                  default auth.uid(),
  site_id       uuid not null references public.sites(id) on delete cascade,
  allocation_id uuid references public.work_allocations(id) on delete set null,
  description   text not null,
  quantity      text not null default '',
  needed_by     date,
  status        material_request_status not null default 'Requested',
  office_note   text not null default '',
  actioned_by   uuid references public.profiles(id) on delete set null,
  actioned_at   timestamptz,
  created_at    timestamptz not null default now()
);

create index if not exists material_requests_open
  on public.material_requests (company_id, created_at desc)
  where status = 'Requested';

alter table public.material_requests enable row level security;

drop policy if exists mat_req_select on public.material_requests;
create policy mat_req_select on public.material_requests for select using (
  company_id = public.current_company_id()
  and (user_id = auth.uid() or public.is_admin() or public.manages_site(site_id))
);

drop policy if exists mat_req_insert on public.material_requests;
create policy mat_req_insert on public.material_requests for insert with check (
  company_id = public.current_company_id() and user_id = auth.uid()
);

-- Only the office changes a request's status. A tradesman marking his own
-- request "Delivered" tells nobody anything.
drop policy if exists mat_req_update on public.material_requests;
create policy mat_req_update on public.material_requests for update using (
  company_id = public.current_company_id()
  and (public.is_admin() or public.manages_site(site_id))
) with check (
  company_id = public.current_company_id()
);

grant select, insert, update on public.material_requests to authenticated;
revoke all on public.material_requests from anon;

-- =====================================================================
-- 3. This week, rolled up
--
-- Every job counts once. Weighting by hours was tempting and wrong: the
-- hours are an estimate made before the work is done, so a week would
-- appear to move backwards whenever somebody corrected one.
-- =====================================================================

create or replace view public.allocation_week_progress
with (security_invoker = true) as
select
  a.company_id,
  a.tradesman_id,
  a.site_id,
  (a.date + ((6 - extract(dow from a.date)::int + 7) % 7))::date as week_ending,
  count(*)                                                        as jobs,
  count(*) filter (where a.percent_complete >= 100)               as jobs_done,
  round(avg(a.percent_complete))::int                             as percent_complete
from public.work_allocations a
group by a.company_id, a.tradesman_id, a.site_id,
         (a.date + ((6 - extract(dow from a.date)::int + 7) % 7))::date;

grant select on public.allocation_week_progress to authenticated;
revoke all on public.allocation_week_progress from anon;
