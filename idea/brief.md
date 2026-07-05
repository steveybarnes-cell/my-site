## MPG Site Records — App Plan

**Company:** My Project Group Ltd
**Concept:** A native iOS/iPad app that replaces messy WhatsApp invoices, PDFs and photos with one standard company system for construction subcontractors. Tradesmen log allocated work, take photos, upload receipts, complete daily site records and submit weekly invoices/timesheets. Admin (Steve) and site managers review, approve, query and pay.

**Platform scope note:** 10x builds native iOS (iPhone + iPad), not web/Android/desktop browser. Delivered as a native iOS app covering the same functionality. Web/Android would need a separate build.

### v1 Status — COMPLETE (mock/local-first)
Role-based entry with mock auth (Admin / Site Manager / Tradesman) via demo picker. All three role experiences are built and navigable end to end.

- **Tradesman:** Today's Work, Allocation detail + accept/start, Daily Site Record form, Photo capture, Material form, Records tab (records/materials/photos), Weekly Invoices with CIS/VAT breakdown + submit, Notifications, Profile
- **Admin:** Office Dashboard (metrics, missing-receipt + late-invoice warnings, sites, variation register), Invoices/payment run (approve/query/mark-paid), Notifications, Team profile
- **Site Manager:** My Sites (with allocations), Site Records review, Notifications, Profile
- **Cross-cutting:** In-app notifications with unread badges, warning banners (missing receipts, late invoices, Monday 13:00 deadline, pending bank change), status workflow, CIS/VAT calc

### Architecture
- `@Observable` AppStore holds all mock data + current user/role
- `ContentView` performs role-based root routing; privacy enforced by filtering to current user
- Models mirror the spec's tables (Users, Profiles, Sites, Allocations, DailyRecords, Materials, Photos, WeeklySubmissions, Comments, Notifications)
- Shared brand system: charcoal, white, olive #6F8F5A, light green #E7EFE2

### Deferred (Phase 2/3)
- Real auth (Supabase), push notifications, real PDF export, Xero/Sage/Drive integrations, charts

### Known notes
- CLI typechecker reports `#Preview` macro-plugin errors only; these compile fine in Xcode. All real cross-file references resolve.