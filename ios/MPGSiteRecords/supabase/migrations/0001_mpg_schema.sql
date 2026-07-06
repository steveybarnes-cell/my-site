-- =====================================================================
-- MPG Site Records — Phase 2 schema
-- My Project Group Ltd
--
-- One shared company database that mirrors the app's data model exactly.
-- Row Level Security enforces the privacy rules already in the app:
--   • tradesman  -> only their own data
--   • siteManager -> data on the sites they manage
--   • admin      -> everything
--
-- Apply in the Supabase dashboard: SQL Editor -> New query -> paste -> Run.
-- Safe to re-run (uses IF NOT EXISTS / CREATE OR REPLACE where possible).
-- =====================================================================

-- ---------- Extensions ----------
create extension if not exists "pgcrypto";

-- ---------- Enums ----------
do $$ begin
  create type user_role as enum ('Admin', 'Site Manager', 'Tradesman');
exception when duplicate_object then null; end $$;

do $$ begin
  create type site_status as enum ('Active', 'Paused', 'Completed');
exception when duplicate_object then null; end $$;

do $$ begin
  create type allocation_status as enum
    ('Allocated','Accepted','Started','In Progress','Completed','Queried','Cancelled');
exception when duplicate_object then null; end $$;

do $$ begin
  create type submission_status as enum
    ('Draft','Submitted','Query Raised','Awaiting Site Manager Approval',
     'Approved by Site Manager','Approved for Payment','Rejected','On Hold','Paid');
exception when duplicate_object then null; end $$;

-- =====================================================================
-- profiles  (one row per auth user; role + identity)
-- =====================================================================
create table if not exists public.profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  name          text not null default '',
  email         text not null default '',
  role          user_role not null default 'Tradesman',
  phone         text not null default '',
  active        boolean not null default true,
  created_at    timestamptz not null default now()
);

-- Tradesman payroll / company details (kept separate; sensitive).
create table if not exists public.tradesman_details (
  user_id           uuid primary key references public.profiles(id) on delete cascade,
  company           text default '',
  address           text default '',
  utr               text default '',
  ni_number         text default '',
  cis_status        text default '',
  main_trade        text default '',
  vehicle_reg       text default '',
  bank_name         text default '',
  sort_code         text default '',
  account_number    text default '',
  hourly_rate       numeric default 0,
  day_rate          numeric default 0,
  vat_registered    boolean default false,
  vat_number        text default '',
  notes             text default '',
  bank_change_pending boolean default false
);

-- =====================================================================
-- sites
-- =====================================================================
create table if not exists public.sites (
  id               uuid primary key default gen_random_uuid(),
  name             text not null,
  address          text default '',
  client           text default '',
  site_manager_id  uuid references public.profiles(id) on delete set null,
  status           site_status not null default 'Active',
  notes            text default '',
  whatsapp_link    text default '',
  default_start    text default '',
  default_finish   text default '',
  latitude         double precision default 0,
  longitude        double precision default 0,
  geofence_radius  double precision default 150,
  created_at       timestamptz not null default now()
);

-- =====================================================================
-- work_allocations
-- =====================================================================
create table if not exists public.work_allocations (
  id                 uuid primary key default gen_random_uuid(),
  site_id            uuid not null references public.sites(id) on delete cascade,
  tradesman_id       uuid not null references public.profiles(id) on delete cascade,
  site_manager_id    uuid references public.profiles(id) on delete set null,
  date               date not null,
  start_time         text default '',
  expected_finish    text default '',
  trade              text default '',
  task_description   text default '',
  category           text default 'Contract Work',
  priority           text default 'Normal',
  required_photos    boolean default false,
  required_materials text default '',
  notes              text default '',
  status             allocation_status not null default 'Allocated',
  created_at         timestamptz not null default now()
);

-- =====================================================================
-- daily_records
-- =====================================================================
create table if not exists public.daily_records (
  id                     uuid primary key default gen_random_uuid(),
  allocation_id          uuid references public.work_allocations(id) on delete set null,
  user_id                uuid not null references public.profiles(id) on delete cascade,
  site_id                uuid not null references public.sites(id) on delete cascade,
  date                   date not null,
  start_time             text default '',
  finish_time            text default '',
  break_minutes          integer default 0,
  total_hours            numeric default 0,
  trade                  text default '',
  description            text default '',
  category               text default 'Contract Work',
  delay_reason           text default 'No delay',
  delay_note             text default '',
  notes                  text default '',
  variation_instructed_by text default '',
  variation_status       text,
  created_at             timestamptz not null default now()
);

-- =====================================================================
-- materials  (purchases + receipts)
-- =====================================================================
create table if not exists public.materials (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references public.profiles(id) on delete cascade,
  site_id           uuid not null references public.sites(id) on delete cascade,
  daily_record_id   uuid references public.daily_records(id) on delete set null,
  date              date not null,
  supplier          text default '',
  description       text default '',
  reason            text default '',
  cost_ex_vat       numeric default 0,
  vat_amount        numeric default 0,
  receipt_uploaded  boolean default false,
  chargeable        text default 'To be confirmed',
  approved          boolean default false,
  notes             text default '',
  created_at        timestamptz not null default now()
);

-- =====================================================================
-- site_photos  (files register — backs Storage objects)
-- =====================================================================
create table if not exists public.site_photos (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references public.profiles(id) on delete cascade,
  site_id           uuid not null references public.sites(id) on delete cascade,
  allocation_id     uuid references public.work_allocations(id) on delete set null,
  type              text not null,
  description       text default '',
  timestamp         timestamptz not null default now(),
  source            text default 'Camera',
  file_extension    text default 'jpg',
  sync_status       text default 'Not synced',
  synced_at         timestamptz,
  xero_reference    text default '',
  daily_record_id   uuid references public.daily_records(id) on delete set null,
  submission_id     uuid,
  material_id       uuid references public.materials(id) on delete set null,
  storage_path      text default '',   -- object path in the Storage bucket
  storage_url       text default '',   -- signed / public URL
  week_ending       date,
  created_at        timestamptz not null default now()
);

-- =====================================================================
-- weekly_submissions  (invoices / timesheets)
-- =====================================================================
create table if not exists public.weekly_submissions (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.profiles(id) on delete cascade,
  week_ending     date not null,
  invoice_number  text not null,
  total_hours     numeric default 0,
  labour_rate     numeric default 0,
  materials_total numeric default 0,
  plant_mileage   numeric default 0,
  cis_rate        numeric default 0.20,
  vat_registered  boolean default false,
  status          submission_status not null default 'Draft',
  submitted_at    timestamptz,
  approved_by     text,
  paid_date       timestamptz,
  created_at      timestamptz not null default now()
);

-- =====================================================================
-- query_comments
-- =====================================================================
create table if not exists public.query_comments (
  id            uuid primary key default gen_random_uuid(),
  submission_id uuid not null references public.weekly_submissions(id) on delete cascade,
  from_name     text default '',
  to_user_id    uuid references public.profiles(id) on delete set null,
  message       text default '',
  timestamp     timestamptz not null default now(),
  from_admin    boolean default false
);

-- =====================================================================
-- notifications
-- =====================================================================
create table if not exists public.notifications (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles(id) on delete cascade,
  type       text default '',
  message    text default '',
  read       boolean default false,
  timestamp  timestamptz not null default now(),
  symbol     text default 'bell'
);

-- =====================================================================
-- clock_records  (geofenced clock in/out)
-- =====================================================================
create table if not exists public.clock_records (
  id                    uuid primary key default gen_random_uuid(),
  user_id               uuid not null references public.profiles(id) on delete cascade,
  tradesman_name        text default '',
  site_id               uuid not null references public.sites(id) on delete cascade,
  site_name             text default '',
  date                  date not null,
  device                text default '',
  clock_in_time         timestamptz not null,
  clock_in_lat          double precision,
  clock_in_lng          double precision,
  clock_in_accuracy     double precision,
  clock_in_distance     double precision,
  clock_in_inside       boolean,
  clock_in_status       text default '',
  clock_in_photo_id     uuid,
  clock_out_time        timestamptz,
  clock_out_lat         double precision,
  clock_out_lng         double precision,
  clock_out_accuracy    double precision,
  clock_out_distance    double precision,
  clock_out_inside      boolean,
  clock_out_status      text default '',
  clock_out_photo_id    uuid,
  claimed_hours         numeric default 0,
  admin_approved        boolean,
  reason_note           text default '',
  created_at            timestamptz not null default now()
);

-- =====================================================================
-- Helper functions for RLS
-- =====================================================================
create or replace function public.current_role()
returns user_role language sql stable security definer set search_path = public as $$
  select role from public.profiles where id = auth.uid()
$$;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select role = 'Admin' from public.profiles where id = auth.uid()), false)
$$;

-- Does the current user manage this site?
create or replace function public.manages_site(target_site uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists(
    select 1 from public.sites s
    where s.id = target_site and s.site_manager_id = auth.uid()
  )
$$;

-- =====================================================================
-- Enable RLS everywhere
-- =====================================================================
alter table public.profiles           enable row level security;
alter table public.tradesman_details  enable row level security;
alter table public.sites              enable row level security;
alter table public.work_allocations   enable row level security;
alter table public.daily_records      enable row level security;
alter table public.materials          enable row level security;
alter table public.site_photos        enable row level security;
alter table public.weekly_submissions enable row level security;
alter table public.query_comments     enable row level security;
alter table public.notifications      enable row level security;
alter table public.clock_records      enable row level security;

-- ---------- profiles ----------
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles for select using (
  id = auth.uid() or public.is_admin() or public.current_role() = 'Site Manager'
);
drop policy if exists profiles_update_self on public.profiles;
create policy profiles_update_self on public.profiles for update using (
  id = auth.uid() or public.is_admin()
);
drop policy if exists profiles_insert_self on public.profiles;
create policy profiles_insert_self on public.profiles for insert with check (
  id = auth.uid() or public.is_admin()
);

-- ---------- tradesman_details ----------
drop policy if exists td_rw on public.tradesman_details;
create policy td_rw on public.tradesman_details for all using (
  user_id = auth.uid() or public.is_admin()
) with check (
  user_id = auth.uid() or public.is_admin()
);

-- ---------- sites (all roles read; admin writes) ----------
drop policy if exists sites_select on public.sites;
create policy sites_select on public.sites for select using (auth.uid() is not null);
drop policy if exists sites_write on public.sites;
create policy sites_write on public.sites for all using (public.is_admin())
  with check (public.is_admin());

-- Generic pattern: owner OR admin OR site manager of the row's site.
-- ---------- work_allocations ----------
drop policy if exists alloc_select on public.work_allocations;
create policy alloc_select on public.work_allocations for select using (
  tradesman_id = auth.uid() or public.is_admin() or public.manages_site(site_id)
);
drop policy if exists alloc_write on public.work_allocations;
create policy alloc_write on public.work_allocations for all using (
  public.is_admin() or public.manages_site(site_id)
) with check (
  public.is_admin() or public.manages_site(site_id)
);

-- ---------- daily_records ----------
drop policy if exists rec_select on public.daily_records;
create policy rec_select on public.daily_records for select using (
  user_id = auth.uid() or public.is_admin() or public.manages_site(site_id)
);
drop policy if exists rec_write on public.daily_records;
create policy rec_write on public.daily_records for all using (
  user_id = auth.uid() or public.is_admin()
) with check (
  user_id = auth.uid() or public.is_admin()
);

-- ---------- materials ----------
drop policy if exists mat_select on public.materials;
create policy mat_select on public.materials for select using (
  user_id = auth.uid() or public.is_admin() or public.manages_site(site_id)
);
drop policy if exists mat_write on public.materials;
create policy mat_write on public.materials for all using (
  user_id = auth.uid() or public.is_admin()
) with check (
  user_id = auth.uid() or public.is_admin()
);

-- ---------- site_photos ----------
drop policy if exists photo_select on public.site_photos;
create policy photo_select on public.site_photos for select using (
  user_id = auth.uid() or public.is_admin() or public.manages_site(site_id)
);
drop policy if exists photo_write on public.site_photos;
create policy photo_write on public.site_photos for all using (
  user_id = auth.uid() or public.is_admin()
) with check (
  user_id = auth.uid() or public.is_admin()
);

-- ---------- weekly_submissions ----------
drop policy if exists sub_select on public.weekly_submissions;
create policy sub_select on public.weekly_submissions for select using (
  user_id = auth.uid() or public.is_admin() or public.current_role() = 'Site Manager'
);
drop policy if exists sub_insert on public.weekly_submissions;
create policy sub_insert on public.weekly_submissions for insert with check (
  user_id = auth.uid() or public.is_admin()
);
-- Tradesman edits own drafts; admin/site manager can update status.
drop policy if exists sub_update on public.weekly_submissions;
create policy sub_update on public.weekly_submissions for update using (
  user_id = auth.uid() or public.is_admin() or public.current_role() = 'Site Manager'
);

-- ---------- query_comments ----------
drop policy if exists qc_select on public.query_comments;
create policy qc_select on public.query_comments for select using (
  to_user_id = auth.uid() or public.is_admin() or public.current_role() = 'Site Manager'
);
drop policy if exists qc_insert on public.query_comments;
create policy qc_insert on public.query_comments for insert with check (
  auth.uid() is not null
);

-- ---------- notifications ----------
drop policy if exists notif_select on public.notifications;
create policy notif_select on public.notifications for select using (
  user_id = auth.uid() or public.is_admin()
);
drop policy if exists notif_update on public.notifications;
create policy notif_update on public.notifications for update using (
  user_id = auth.uid()
);
drop policy if exists notif_insert on public.notifications;
create policy notif_insert on public.notifications for insert with check (
  auth.uid() is not null
);

-- ---------- clock_records ----------
drop policy if exists clock_select on public.clock_records;
create policy clock_select on public.clock_records for select using (
  user_id = auth.uid() or public.is_admin() or public.manages_site(site_id)
);
drop policy if exists clock_insert on public.clock_records;
create policy clock_insert on public.clock_records for insert with check (
  user_id = auth.uid() or public.is_admin()
);
drop policy if exists clock_update on public.clock_records;
create policy clock_update on public.clock_records for update using (
  user_id = auth.uid() or public.is_admin() or public.manages_site(site_id)
);

-- =====================================================================
-- Auto-create a profile row when a new auth user signs up
-- =====================================================================
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, name, email, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name', ''),
    coalesce(new.email, ''),
    'Tradesman'
  )
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
