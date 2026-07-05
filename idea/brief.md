## MPG Site Records — App Plan

**Company:** My Project Group Ltd
**Concept:** A native iOS/iPad app that replaces messy WhatsApp invoices, PDFs and photos with one standard company system for construction subcontractors. Tradesmen log allocated work, take photos, upload receipts, complete daily site records and submit weekly invoices/timesheets. Admin (Steve) and site managers review, approve, query and pay.

**Platform scope note:** 10x builds native iOS (iPhone + iPad), not web/Android/desktop browser. Delivered as a native iOS app covering the same functionality.

### v1 Status — COMPLETE (mock/local-first)
Role-based entry with mock auth (Admin / Site Manager / Tradesman) via demo picker. All three role experiences are built and navigable end to end.

- **Tradesman:** Today's Work, Allocation detail, Daily Site Record, Photo/file capture, Material form, Records tab, Files tab, Weekly Invoices (CIS/VAT + submit), Notifications, Profile
- **Admin:** Office Dashboard, Invoices/payment run, Files (all sites), Notifications, Team profile
- **Site Manager:** My Sites, Site Records review, Files (assigned sites), Notifications, Profile
- **Cross-cutting:** In-app notifications, warning banners, status workflow, CIS/VAT calc

### File Storage (local-first, backend-ready)
- Capture from camera (`UIImagePickerController`, simulator-safe fallback) or gallery (`PhotosPicker`)
- 11 file types: before/during/completed works, variation/snagging/delay/damage evidence, receipt, supplier invoice, materials photo, other
- `FileStorage` builds the exact Drive folder path `My Project Group - Site Record System / File Type / Site / Week Ending / Tradesman` and auto-renames `Date_Site_Tradesman_FileType_TaskID.ext`
- `AppStore.uploadFile` produces a `FileSheetRow` (Photos & Files tab) with all required columns; receipts/supplier invoices link to Materials Register, variation → Variation Register, delay → Delay Register
- Role-based visibility: tradesman = own, site manager = assigned sites, admin = all

### Architecture
- `@Observable` AppStore holds all mock data + current user/role
- `ContentView` performs role-based root routing; privacy enforced by filtering
- Models mirror the spec's tables; `SitePhoto` extended with Drive/sheet/link metadata

### Deferred (Phase 2/3)
- Real Google Drive + Sheets sync (Google OAuth + backend: Drive API + Sheets API)
- Real auth (Supabase), push notifications, real PDF export, Xero/Sage integrations, charts

### Known notes
- CLI typechecker reports per-file cross-file resolution artifacts on partial edits; full `verify_compile` passes across all 22 files.