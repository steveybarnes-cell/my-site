## MPG Site Records — App Plan

**Company:** My Project Group Ltd
**Concept:** A native iOS/iPad app that replaces messy WhatsApp invoices, PDFs and photos with one standard company system for construction subcontractors. Tradesmen log allocated work, take photos, upload receipts, complete daily site records and submit weekly invoices/timesheets. Admin (Steve) and site managers review, approve, query and pay.

**Platform scope note:** 10x builds native iOS (iPhone + iPad) only. The PC-accessible "central hub" is delivered via the Supabase backend: live `report_*` views any PC browser can open (Supabase → Table Editor). A fully branded web portal is a separate web project, not deliverable in 10x.

### v1 Status — COMPLETE (mock/local-first)
All three role experiences built and navigable end to end. Site Files Hub, geofenced clock-in/out, and Attendance overview shipped.

---

## PHASE 2 — Supabase backend (IN PROGRESS)

### Done
- Supabase project connected; schema, RLS role helpers, auto-create-profile trigger, private storage bucket applied.
- Real auth wired: email/password + sign-up + Google OAuth, Keychain session persistence + restore, profile row drives role routing.
- 3 company sites seeded to Supabase with stable UUIDs.
- Live data for all core areas: sites, clock records, daily records, weekly submissions, allocations, materials, photos, notifications, query comments read/write live Supabase on real sign-in. Demo login still uses local seed.
- **PC-accessible hub:** 7 `report_*` views (work allocations, daily records, materials, photos & files, payment run, site cost summary, attendance) applied to the live DB using security_invoker. Verified queryable. Added an in-app "PC / Web Access" card on the Company Dashboard with step-by-step guidance to open the report from any PC browser.

### Blocked on user
- **Google provider config:** add a Google Cloud OAuth client in Supabase Auth → Providers → Google + register redirect `mpgsiterecords://auth-callback`. Email/password + Demo login work now.

### Remaining app-code steps
1. Real photo image bytes uploaded into the Storage bucket (currently stores metadata + storage path only).
2. Offline sync queue drains to Supabase.

### Deferred (Phase 3)
- Xero/Hubdoc OAuth, push notifications, PDF handover export, charts, optional branded web portal (separate web project).

### Design
Reuse existing MPG system (charcoal + green, `mpgCard()`, `Brand` tokens).