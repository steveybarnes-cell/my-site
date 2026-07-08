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
- **AI receipt scan — LIVE (needs OpenAI key).** `scan-receipt` Edge Function deployed (verify_jwt on): takes a base64 receipt image and returns supplier/description/costExVat/vatAmount/total/date JSON via OpenAI vision (`gpt-5.4-mini`). `ReceiptScanService` calls it with the user's Supabase token. In Add Material, capturing/picking a receipt auto-fills supplier, cost ex VAT, VAT and a new Purchase date field; fields stay editable with a "please check" note and manual fallback. OpenAI key stays server-side — requires `OPENAI_API_KEY` backend secret to function live.

## PHASE 4 — App Store go-live (in progress)

### Done
- Demo Sign-in gated for release (then temporarily exposed on device for admin access without an account).
- Admin role confirmed (Steve, info@my-project.co.uk).
- Production Audit complete.
- Submission details recorded: support email info@my-project.co.uk, legal seller "My Project Group Limited", App Review phone 0117 251 0565.
- Device connectivity fix (Info.plist fallback for Supabase URL + publishable key).

### Blocked on user
- **OpenAI key** for AI receipt scan: add `OPENAI_API_KEY` in Integrations → Hosted Keys (syncs to Supabase secrets).
- **Google sign-in** needs a Google Cloud OAuth client in Supabase Auth. Optional for launch.
- **App Store Connect API key** validation blocked on 10x-side `asc` auto-install bug (support report pending).

### Remaining Publishing stages
- Credentials → Prefill → App Store Connect setup → Submission → Management.

### Deferred / Next
- Add Supabase save endpoints for sites + staff so Manage tab writes persist across devices.
- Optionally extend AI receipt scan to the general Add File / PhotoCaptureView receipt uploads.
- Push notifications, optional branded web portal.

### Design
Reuse MPG system (charcoal + green, `mpgCard()`, `mpgFormSection()`, `Brand` tokens, shared `Field`/`SectionHeader`/`PrimaryButton`).