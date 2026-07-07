-- =====================================================================
-- MPG Site Records — Phase 2: PC reporting views
-- My Project Group Ltd
--
-- These read-only views turn the raw app tables into the tabbed
-- "central hub" report Steve asked for, so anyone with database
-- access can open them from a PC browser:
--   Supabase Dashboard -> Table Editor / SQL Editor -> the `report_*` views.
--
-- Every view uses security_invoker so the same Row Level Security
-- rules that protect the app also apply when read from PostgREST.
-- (In the Supabase SQL Editor you run as owner, so admins see all rows.)
--
-- Apply: SQL Editor -> New query -> paste -> Run. Safe to re-run.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Work Allocations
-- ---------------------------------------------------------------------
create or replace view public.report_work_allocations
with (security_invoker = true) as
select
  wa.date                       as work_date,
  s.name                        as site,
  s.client                      as client,
  tp.name                       as tradesman,
  sm.name                       as site_manager,
  wa.trade                      as trade,
  wa.task_description           as task,
  wa.category                   as category,
  wa.priority                   as priority,
  wa.status                     as status,
  wa.start_time                 as start_time,
  wa.expected_finish            as expected_finish,
  wa.required_photos            as photos_required,
  wa.required_materials         as materials_required,
  wa.notes                      as notes,
  wa.created_at                 as created_at
from public.work_allocations wa
left join public.sites    s  on s.id  = wa.site_id
left join public.profiles tp on tp.id = wa.tradesman_id
left join public.profiles sm on sm.id = wa.site_manager_id
order by wa.date desc, s.name;

-- ---------------------------------------------------------------------
-- 2. Daily Records (site diary + variations/delays)
-- ---------------------------------------------------------------------
create or replace view public.report_daily_records
with (security_invoker = true) as
select
  dr.date                       as work_date,
  s.name                        as site,
  p.name                        as tradesman,
  dr.trade                      as trade,
  dr.category                   as category,
  dr.start_time                 as start_time,
  dr.finish_time                as finish_time,
  dr.break_minutes              as break_minutes,
  dr.total_hours                as total_hours,
  dr.description                as description,
  dr.delay_reason               as delay_reason,
  dr.delay_note                 as delay_note,
  dr.variation_instructed_by    as variation_instructed_by,
  dr.variation_status           as variation_status,
  dr.notes                      as notes,
  dr.created_at                 as created_at
from public.daily_records dr
left join public.sites    s on s.id = dr.site_id
left join public.profiles p on p.id = dr.user_id
order by dr.date desc, s.name;

-- ---------------------------------------------------------------------
-- 3. Materials (purchases + receipt / approval tracking)
-- ---------------------------------------------------------------------
create or replace view public.report_materials
with (security_invoker = true) as
select
  m.date                        as purchase_date,
  s.name                        as site,
  p.name                        as tradesman,
  m.supplier                    as supplier,
  m.description                 as description,
  m.reason                      as reason,
  m.cost_ex_vat                 as cost_ex_vat,
  m.vat_amount                  as vat_amount,
  (m.cost_ex_vat + m.vat_amount) as cost_inc_vat,
  m.chargeable                  as chargeable,
  m.receipt_uploaded            as receipt_uploaded,
  m.approved                    as approved,
  m.notes                       as notes,
  m.created_at                  as created_at
from public.materials m
left join public.sites    s on s.id = m.site_id
left join public.profiles p on p.id = m.user_id
order by m.date desc, s.name;

-- ---------------------------------------------------------------------
-- 4. Photos & Files register
-- ---------------------------------------------------------------------
create or replace view public.report_photos_files
with (security_invoker = true) as
select
  sp.timestamp                  as captured_at,
  s.name                        as site,
  p.name                        as uploaded_by,
  sp.type                       as file_type,
  sp.description                as description,
  sp.source                     as source,
  sp.file_extension             as file_extension,
  sp.sync_status                as sync_status,
  sp.synced_at                  as synced_at,
  sp.xero_reference             as xero_reference,
  sp.storage_path               as storage_path,
  sp.storage_url                as storage_url,
  sp.week_ending                as week_ending
from public.site_photos sp
left join public.sites    s on s.id = sp.site_id
left join public.profiles p on p.id = sp.user_id
order by sp.timestamp desc;

-- ---------------------------------------------------------------------
-- 5. Weekly Submissions / Payment Run
-- ---------------------------------------------------------------------
create or replace view public.report_payment_run
with (security_invoker = true) as
select
  ws.week_ending                as week_ending,
  p.name                        as contractor,
  ws.invoice_number             as invoice_number,
  ws.total_hours                as total_hours,
  ws.labour_rate                as labour_rate,
  (ws.total_hours * ws.labour_rate) as labour_value,
  ws.materials_total            as materials_total,
  ws.plant_mileage              as plant_mileage,
  (ws.total_hours * ws.labour_rate + ws.materials_total + ws.plant_mileage) as gross_total,
  round((ws.total_hours * ws.labour_rate) * ws.cis_rate, 2) as cis_deduction,
  round(
    (ws.total_hours * ws.labour_rate + ws.materials_total + ws.plant_mileage)
    - (ws.total_hours * ws.labour_rate) * ws.cis_rate, 2) as net_due,
  ws.cis_rate                   as cis_rate,
  ws.vat_registered             as vat_registered,
  ws.status                     as status,
  ws.submitted_at               as submitted_at,
  ws.approved_by                as approved_by,
  ws.paid_date                  as paid_date
from public.weekly_submissions ws
left join public.profiles p on p.id = ws.user_id
order by ws.week_ending desc, p.name;

-- ---------------------------------------------------------------------
-- 6. Site Cost Summary (rolled up per site)
-- ---------------------------------------------------------------------
create or replace view public.report_site_cost_summary
with (security_invoker = true) as
with labour as (
  select site_id, coalesce(sum(total_hours), 0) as hours
  from public.daily_records group by site_id
),
mats as (
  select
    site_id,
    coalesce(sum(cost_ex_vat + vat_amount), 0) as materials_total,
    coalesce(sum(case when not receipt_uploaded then 1 else 0 end), 0) as missing_receipts
  from public.materials group by site_id
)
select
  s.name                                   as site,
  s.client                                 as client,
  s.status                                 as site_status,
  coalesce(l.hours, 0)                     as total_hours,
  coalesce(mats.materials_total, 0)        as materials_total,
  coalesce(mats.missing_receipts, 0)       as materials_missing_receipts
from public.sites s
left join labour l  on l.site_id  = s.id
left join mats      on mats.site_id = s.id
order by s.name;

-- ---------------------------------------------------------------------
-- 7. Attendance (geofenced clock in / out)
-- ---------------------------------------------------------------------
create or replace view public.report_attendance
with (security_invoker = true) as
select
  cr.date                       as work_date,
  coalesce(cr.site_name, s.name) as site,
  coalesce(cr.tradesman_name, p.name) as tradesman,
  cr.clock_in_time              as clock_in,
  cr.clock_in_status            as clock_in_status,
  cr.clock_in_inside            as clock_in_on_site,
  cr.clock_in_distance          as clock_in_distance_m,
  cr.clock_out_time             as clock_out,
  cr.clock_out_status           as clock_out_status,
  cr.clock_out_inside           as clock_out_on_site,
  cr.clock_out_distance         as clock_out_distance_m,
  cr.claimed_hours              as claimed_hours,
  cr.admin_approved             as admin_approved,
  cr.reason_note                as reason_note,
  cr.device                     as device
from public.clock_records cr
left join public.sites    s on s.id = cr.site_id
left join public.profiles p on p.id = cr.user_id
order by cr.date desc, cr.clock_in_time desc;
