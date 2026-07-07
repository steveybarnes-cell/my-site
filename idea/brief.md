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
- **Xero — LIVE.** Two Supabase Edge Functions deployed:
  - `xero-oauth`: consent URL, callback token exchange, storage in `xero_connections`, auto-refresh.
  - `xero-push-invoice`: approved submission → draft ACCREC invoice in Xero (auth/JWT-verified).
  - App wiring: `XeroService` calls both functions with the signed-in user's Supabase JWT; Client Secret stays server-side as a backend secret. Admin → Profile → Integrations has a real Connect-to-Xero flow (`ASWebAuthenticationSession`). Admin → Invoices shows "Approve & Send to Xero" which pushes labour/materials/mileage line items, records the returned Xero invoice number, marks Approved for Payment, and notifies the tradesman. `mpgsiterecords://` URL scheme registered in Info.plist.

### Blocked on user
- **Google provider config:** Google Cloud OAuth client + redirect `mpgsiterecords://auth-callback`. Email/password + Demo login work now.

### Notes
- Xero push requires a real (non-demo) signed-in admin, since the push function verifies the Supabase JWT.

### Deferred
- Push notifications, optional branded web portal.

### Design
Reuse MPG system (charcoal + green, `mpgCard()`, `Brand` tokens).