## MPG Site Records — App Plan

**Company:** My Project Group Ltd
**Concept:** A native iOS/iPad app that replaces messy WhatsApp invoices, PDFs and photos with one standard company system for construction subcontractors. Tradesmen log allocated work, take photos, upload receipts, complete daily site records and submit weekly invoices/timesheets. Admin (Steve) and site managers review, approve, query and pay.

**Platform scope note:** 10x builds native iOS (iPhone + iPad) only. PC hub is delivered via Supabase `report_*` views any PC browser can open.

### v1 Status — COMPLETE (mock/local-first)
All three role experiences built and navigable end to end.

## PHASE 2 — Supabase backend — COMPLETE
- Schema, RLS, auto-create-profile trigger, private storage bucket applied.
- Real auth: email/password + sign-up + Google OAuth, Keychain session persistence + restore.
- Core areas read/write live Supabase. PC-accessible hub via `report_*` views.

## PHASE 3

### Done
- Real photo image uploads to private `site-evidence` Storage bucket.
- Offline sync queue: disk-backed FIFO, auto-retry, pending-sync banner.
- Dashboard charts (Swift Charts) + branded A4 PDF handover export via ShareLink.
- **Xero — LIVE.** Two Supabase Edge Functions deployed (`xero-oauth`, `xero-push-invoice`); app wired with signed-in user's Supabase JWT; Client Secret stays server-side.
- **Admin Manage tab (NEW).** Admin can now add and edit data in-app via a segmented Manage screen:
  - **Sites/Jobs** — `SiteFormView`: name, address, client, site manager, status, default hours, WhatsApp link, notes, geofence (lat/long + radius).
  - **Team** — `StaffFormView`: add/edit tradesmen + site managers (name, email, phone, role, active).
  - **Work allocations** — `AllocationFormView`: assign site + tradesman + date, trade, task, category, priority, times, materials, photo requirement, status; new allocations auto-notify the tradesman.
  - Store mutations: `saveSite`, `saveUser`, `saveAllocation`. Allocations sync to Supabase; sites + staff are local-only writes for now.

### Blocked on user
- **Google provider config:** Google Cloud OAuth client + redirect `mpgsiterecords://auth-callback`. Email/password + Demo login work now.

### Deferred / Next
- Add Supabase save endpoints for sites + staff so Manage tab writes persist across devices.
- Push notifications, optional branded web portal.

### Design
Reuse MPG system (charcoal + green, `mpgCard()`, `mpgFormSection()`, `Brand` tokens, shared `Field`/`SectionHeader`/`PrimaryButton`).