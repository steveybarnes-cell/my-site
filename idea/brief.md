## MPG Site Records — App Plan

**Company:** My Project Group Ltd
**Concept:** A native iOS/iPad app that replaces messy WhatsApp invoices, PDFs and photos with one standard company system for construction subcontractors. Tradesmen log allocated work, take photos, upload receipts, complete daily site records and submit weekly invoices/timesheets. Admin (Steve) and site managers review, approve, query and pay.

**Platform scope note:** 10x builds native iOS (iPhone + iPad), not web/Android/desktop browser. Delivered as a native iOS app covering the same functionality. Web/Android would need a separate build.

### v1 Scope (mock/local-first)
- Role-based entry: Admin / Site Manager / Tradesman (mock auth, no live Supabase yet)
- Brand system: charcoal, white, olive green #6F8F5A, light green #E7EFE2
- Tradesman: Today's Work, My Allocations, Daily Site Record, Photos, Materials, Weekly Invoice, My Submissions, Payment Status, Profile
- Admin: Dashboard, Users/Tradesmen, Sites, Allocate Work, Review Records, Review Submissions, Materials/Missing Receipts, Variation Register, Payment Run, Reports
- Site Manager: My Sites, Site Allocations, Review Records, Approve/Query, Site Photos/Materials
- Status workflow, CIS/VAT calc, missing-receipt & late-invoice warnings, variation & delay tracking, in-app notifications

### Architecture
- `@Observable` AppStore holds all mock data + current user/role
- Role-based root routing; privacy enforced by filtering to current user
- Models mirror the spec's tables (Users, Profiles, Sites, Allocations, DailyRecords, Materials, Photos, WeeklySubmissions, Comments, Notifications)

### Deferred (Phase 2/3)
- Real auth (Supabase), push notifications, real PDF export, Xero/Sage/Drive integrations, charts
</plan>
<tasks">- [ ] Brand theme + design system + models
- [ ] AppStore with realistic sample data + role auth
- [ ] Role-based login + root routing
- [ ] Tradesman flow (today, allocations, daily record, photos, materials, weekly invoice, submissions)
- [ ] Admin flow (dashboard, sites, users, allocate, review, payment run)
- [ ] Site Manager flow
- [ ] Notifications + warnings + polish

## Selected Design Direction

- Selected style: Clean (`clean`)
- Direction: Whitespace, simple typography, restrained color
- Reference apps: Uber, Notion, Things 3
- Palette seed: primary #111827, accent #2563EB, background #F8FAFC
- Status: selected by the AI after the user skipped style selection.