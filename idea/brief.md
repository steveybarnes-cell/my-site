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

## PHASE 3 — COMPLETE
- Real photo image uploads to private `site-evidence` Storage bucket.
- Offline sync queue: disk-backed FIFO, auto-retry, pending-sync banner.
- Dashboard charts (Swift Charts) + branded A4 PDF handover export via ShareLink.
- **Xero — LIVE.** Two Supabase Edge Functions deployed; app wired with signed-in user's Supabase JWT; Client Secret stays server-side.
- **Admin Manage tab.** Admin can add/edit sites, staff, and work allocations in-app.

## PHASE 4 — App Store go-live (in progress)

### Done
- **Demo Sign-in gated for release** (#if DEBUG).
- **Admin role confirmed.** Steve (info@my-project.co.uk) has `role = Admin`.
- **Production Audit stage complete.**
- Submission details recorded: support email info@my-project.co.uk, legal seller "My Project Group Limited", App Review phone 0117 251 0565.
- **Device connectivity fix.** `SupabaseConfig` now reads the process environment first (Xcode/simulator dev), then falls back to public URL + publishable key baked into Info.plist (`SupabaseURL`, `SupabasePublishableKey` from `$(SUPABASE_URL)`/`$(SUPABASE_PUBLISHABLE_KEY)`). This fixes the "Not connected to Supabase yet" banner on installed device builds where the environment isn't injected. Only client-safe public keys are shipped; no service_role/admin secret.

### Blocked on user
- **Google sign-in** needs a Google Cloud OAuth client in Supabase Auth to work live. Optional for launch.
- **App Store Connect API key** validation currently blocked on the 10x-side `asc` auto-install bug (support report pending).

### Remaining Publishing stages
- Credentials → Prefill → App Store Connect setup → Submission → Management.

### Deferred / Next
- Add Supabase save endpoints for sites + staff so Manage tab writes persist across devices.
- Push notifications, optional branded web portal.

### Design
Reuse MPG system (charcoal + green, `mpgCard()`, `mpgFormSection()`, `Brand` tokens, shared `Field`/`SectionHeader`/`PrimaryButton`).