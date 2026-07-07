## MPG Site Records — App Plan

**Company:** My Project Group Ltd
**Concept:** A native iOS/iPad app that replaces messy WhatsApp invoices, PDFs and photos with one standard company system for construction subcontractors. Tradesmen log allocated work, take photos, upload receipts, complete daily site records and submit weekly invoices/timesheets. Admin (Steve) and site managers review, approve, query and pay.

**Platform scope note:** 10x builds native iOS (iPhone + iPad) only. PC hub is delivered via Supabase `report_*` views any PC browser can open.

### v1 Status — COMPLETE (mock/local-first)
All three role experiences built and navigable end to end.

## PHASE 2 — Supabase backend — COMPLETE
- Schema, RLS, auto-create-profile trigger, private storage bucket applied.
- Real auth: email/password + sign-up + Google OAuth, Keychain session persistence + restore.
- 3 company sites seeded. Core areas read/write live Supabase.
- PC-accessible hub: 7 `report_*` views + in-app PC Access card.

## PHASE 3

### Done
- Real photo image uploads to private `site-evidence` Storage bucket.
- Offline sync queue: disk-backed FIFO, auto-retry, pending-sync banner.
- **Dashboard charts (Swift Charts):** `DashboardCharts` adds a stacked site-cost bar, weekly net-value area/line trend, and an allocation-status donut, all driven by `DashboardAnalytics` and the active filter.
- **PDF handover export:** `PDFExportService` renders a branded A4 report (week summary + site cost table + payment run) via `UIGraphicsPDFRenderer`, exposed on the dashboard toolbar as a generate → `ShareLink` flow.

### Blocked on user
- **Google provider config:** Google Cloud OAuth client + redirect `mpgsiterecords://auth-callback`. Email/password + Demo login work now.
- **Xero OAuth:** needs Xero developer app credentials (client id/secret) + OAuth redirect. Currently modelled locally.

### Deferred
- Push notifications, optional branded web portal.

### Design
Reuse MPG system (charcoal + green, `mpgCard()`, `Brand` tokens). Charts use `Brand.olive`/`amber`/`blue`/`paidGreen`.