- [x] Brand theme + design system + models
- [x] AppStore with realistic sample data + role auth
- [x] Role-based login + root routing
- [x] Tradesman / Admin / Site Manager flows
- [x] Notifications + warnings, Files tab, company dashboard, Xero/Hub sync (modelled), receipt capture
- [x] Site Files Hub (categories, Drive convention, register, handover, dashboard widgets)
- [x] Geofenced clock-in/out + Attendance overview (map, review, approve/reject)
- [x] Submission-ready: Info.plist usage strings; App Store assets + audit + prefill drafts
- [x] Phase 2 backend: Supabase schema + RLS + Storage bucket SQL migrations written
- [ ] Phase 2 backend: apply migrations to Supabase project (user step)
- [ ] Phase 2 backend: Supabase client + service layer in app
- [ ] Phase 2 backend: real auth (Google sign-in + Demo login) + session/role routing
- [ ] Phase 2 backend: switch AppStore to live Supabase data (loading/empty/error states)
- [ ] Offline work logging: local persistence + sync queue drains to Supabase once live
- [ ] Phase 3: real Google Drive/Sheets sync, Xero OAuth, PDF export</parameter>
<parameter name="plan">## MPG Site Records — App Plan

**Company:** My Project Group Ltd
**Concept:** A native iOS/iPad app that replaces messy WhatsApp invoices, PDFs and photos with one standard company system for construction subcontractors. Tradesmen log allocated work, take photos, upload receipts, complete daily site records and submit weekly invoices/timesheets. Admin (Steve) and site managers review, approve, query and pay.

**Platform scope note:** 10x builds native iOS (iPhone + iPad). The PC-accessible "central hub" is delivered via the Phase 2 Supabase backend (Supabase dashboard now; a web admin page later).

### v1 Status — COMPLETE (mock/local-first)
Role-based entry with mock auth (Admin / Site Manager / Tradesman). All three role experiences built and navigable end to end. Site Files Hub, geofenced clock-in/out, and Attendance overview shipped.

---

## PHASE 2 — Supabase backend (IN PROGRESS)

**Goal:** Turn the on-device app into one shared company system so all data lives in the cloud, everyone signs in with their own account, and Steve can open the data from any PC browser.

### Done
- Supabase project connected via Integrations.
- **Schema written** — `supabase/migrations/0001_mpg_schema.sql`: tables for profiles, tradesman_details, sites, work_allocations, daily_records, materials, site_photos, weekly_submissions, query_comments, notifications, clock_records. Mirrors the app data model field-for-field.
- **Row Level Security written** — tradesman sees own data; site manager sees managed-site data; admin sees everything. Helper functions `current_role()`, `is_admin()`, `manages_site()`. Auto-create profile trigger on signup (defaults role = Tradesman).
- **Storage written** — `0002_storage.sql`: private `site-evidence` bucket with path-based access policies (`<site_id>/<user_id>/<file>`).

### Blocked on user
- **Apply migrations:** paste `0001` then `0002` into Supabase SQL Editor and Run.
- **Admin email:** identify Steve's account email so his role can be promoted to Admin (others default to Tradesman).

### Remaining app-code steps (after migrations run)
1. Supabase client config + service layer.
2. Real auth: Google sign-in + clearly-labelled Demo Sign In for testing; session + role routing replaces the role-picker mock.
3. Switch AppStore reads/writes to live Supabase data with loading/empty/error states.
4. Offline sync queue drains to Supabase once live.

### Dependencies
- Supabase (clientRuntime; SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY) — connected.
- Google sign-in requires a Google Cloud OAuth client added in Supabase Auth later (walk-through when we reach it).

### Deferred (Phase 3)
- Real Google Drive upload + Sheets append, Xero/Hubdoc OAuth, push notifications, PDF handover export, charts.

### Design
Reuse existing MPG system (charcoal + green, `mpgCard()`, `Brand` tokens). Sync/status uses amber pending, green synced, red failed.</parameter>
</invoke>