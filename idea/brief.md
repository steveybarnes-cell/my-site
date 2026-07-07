## MPG Site Records — App Plan

**Company:** My Project Group Ltd
**Concept:** A native iOS/iPad app that replaces messy WhatsApp invoices, PDFs and photos with one standard company system for construction subcontractors. Tradesmen log allocated work, take photos, upload receipts, complete daily site records and submit weekly invoices/timesheets. Admin (Steve) and site managers review, approve, query and pay.

**Platform scope note:** 10x builds native iOS (iPhone + iPad) only. The PC-accessible "central hub" is delivered via the Supabase backend: live `report_*` views any PC browser can open. A fully branded web portal is a separate web project.

### v1 Status — COMPLETE (mock/local-first)
All three role experiences built and navigable end to end.

## PHASE 2 — Supabase backend — COMPLETE
- Schema, RLS, auto-create-profile trigger, private storage bucket applied.
- Real auth: email/password + sign-up + Google OAuth, Keychain session persistence + restore.
- 3 company sites seeded. All core areas read/write live Supabase on real sign-in.
- PC-accessible hub: 7 `report_*` views + in-app PC Access card.

## PHASE 3 (IN PROGRESS)

### Done
- **Real photo image uploads** to the private `site-evidence` Storage bucket (camera + gallery).
- **Offline sync queue:** disk-backed FIFO queue (`SyncQueue`) captures any Supabase write that fails (e.g. no signal). Failed writes are persisted to Documents and replayed in order on the next successful live reload or via the dashboard "Retry" banner. Upserts to the same row id coalesce to the latest version. `AppStore.pendingSyncCount` drives an in-app pending-sync banner on the Company Dashboard. Writes routed through the new `sync(queued:_:)` helper: clock in/out, clock approval, daily records, submissions, allocations, materials, photos, notifications, query comments, mark-read.

### Blocked on user
- **Google provider config:** add a Google Cloud OAuth client in Supabase Auth → Providers → Google + register redirect `mpgsiterecords://auth-callback`. Email/password + Demo login work now.

### Deferred
- Xero/Hubdoc OAuth, push notifications, PDF handover export, charts, optional branded web portal.

### Design
Reuse existing MPG system (charcoal + green, `mpgCard()`, `Brand` tokens).