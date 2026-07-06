## MPG Site Records — App Plan

**Company:** My Project Group Ltd
**Concept:** A native iOS/iPad app that replaces messy WhatsApp invoices, PDFs and photos with one standard company system for construction subcontractors. Tradesmen log allocated work, take photos, upload receipts, complete daily site records and submit weekly invoices/timesheets. Admin (Steve) and site managers review, approve, query and pay.

**Platform scope note:** 10x builds native iOS (iPhone + iPad). The PC-accessible "central hub" is delivered via the Supabase backend (Supabase dashboard now on any PC browser; a branded web/Sheets view later).

### v1 Status — COMPLETE (mock/local-first)
All three role experiences built and navigable end to end. Site Files Hub, geofenced clock-in/out, and Attendance overview shipped.

---

## PHASE 2 — Supabase backend (IN PROGRESS)

### Done
- Supabase project connected; schema, RLS role helpers, auto-create-profile trigger, private storage bucket applied.
- Real auth wired: email/password + sign-up + Google OAuth, Keychain session persistence + restore, profile row drives role routing.
- **3 company sites seeded** to Supabase with stable UUIDs (Marlborough Street, Clifton Village, Redcliffe Wharf).
- **Live data for the 3 core areas:**
  - New `SupabaseData` service maps app models ↔ PostgREST rows (sites, clock_records, daily_records, weekly_submissions).
  - `SupabaseClient` gained upsert/patch write helpers.
  - On real sign-in, `AppStore.startLiveSession` loads live sites + clock/daily/submission rows; Demo login still uses local seed.
  - Writes routed to Supabase: clock-in, clock-out, clock approval, daily record add, submission save + status change.
  - Verified: signing in as Steve now shows an empty live dashboard (reading real DB) instead of sample data.

### Blocked on user
- **Google provider config:** add a Google Cloud OAuth client in Supabase Auth → Providers → Google + register redirect `mpgsiterecords://auth-callback`. Email/password + Demo login work now.

### Remaining app-code steps
1. Wire remaining areas (allocations, materials, photos, notifications, query comments) to Supabase.
2. Offline sync queue drains to Supabase.

### Deferred (Phase 3)
- Google Drive upload + Sheets/PC dashboard, Xero/Hubdoc OAuth, push notifications, PDF handover export, charts.

### Design
Reuse existing MPG system (charcoal + green, `mpgCard()`, `Brand` tokens).