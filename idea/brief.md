## MPG Site Records — App Plan

**Company:** My Project Group Ltd
**Concept:** A native iOS/iPad app that replaces messy WhatsApp invoices, PDFs and photos with one standard company system for construction subcontractors. Tradesmen log allocated work, take photos, upload receipts, complete daily site records and submit weekly invoices/timesheets. Admin (Steve) and site managers review, approve, query and pay.

**Platform scope note:** 10x builds native iOS (iPhone + iPad), not web/Android/desktop browser. Delivered as a native iOS app covering the same functionality.

### v1 Status — COMPLETE (mock/local-first)
Role-based entry with mock auth (Admin / Site Manager / Tradesman) via demo picker. All three role experiences are built and navigable end to end.

- **Tradesman:** Today's Work, Allocation detail, Daily Site Record, Photo/file capture, Material form (with receipt capture), Records tab, Files tab, Weekly Invoices (CIS/VAT + submit), Notifications, Profile
- **Admin:** Office Dashboard, Invoices/payment run, Files (all sites), Notifications, Team profile, Integrations (Xero connection toggle)
- **Site Manager:** My Sites, Site Records review, Files (assigned sites), Notifications, Profile
- **Cross-cutting:** In-app notifications, warning banners, status workflow, CIS/VAT calc

### Branding
- `Components/MPGLogo.swift` — faithful vector rendition of the official My Project Group wordmark: green **MY**, white double-peak house/frame mark (stroked `Shape`), white **PROJECT**, green **GROUP**. Scales via a single `height` param.
- `Brand.logoGreen` (#63B877) matches the bright green in the official logo.
- Login header uses `MPGLogo` on charcoal (replaced the old placeholder "MPG" square).

### File Storage (local-first, backend-ready)
- Capture from camera or gallery; 11 file types; exact Drive folder path + auto-rename; Photos & Files sheet row; register linking; role-based visibility.

### Materials + Receipt Capture (modelled, backend-ready)
- Add Materials form captures a Receipt or Supplier invoice via camera/gallery (simulator-safe pipeline)
- Receipt uploads to Drive as a proper file and links to the exact material via `materialId`; marks material receipt-backed
- No-receipt path still fires the missing-receipt notification
- When Xero connected, receipt auto-sends via `sendToXero` to Hubdoc/Xero + central cost tracker; live note shows connection state

### Xero / Company Hub sync (modelled, backend-ready)
- `SyncStatus` on each file (Not synced → Pending → Synced/Failed)
- `AppStore.sendToXero` simulates push, stamps `XERO-…` reference + timestamp; gated to receipts/supplier invoices via `canSyncToXero`
- File Detail "Xero / Company Hub" card; send button gated on `xeroConnected`
- Files list shows inline sync badges (Pending sync / In Xero / Sync failed)
- Admin profile Integrations card with `xeroConnected` toggle
- Phase 2 swap: replace `sendToXero` body with real Hubdoc/Xero OAuth + Files/Bills API; toggle becomes real connect action

### Architecture
- `@Observable` AppStore holds all mock data + current user/role
- `ContentView` performs role-based root routing; privacy enforced by filtering

### Deferred (Phase 2/3)
- Real Google Drive + Sheets sync, real Xero/Hubdoc OAuth + Files/Bills API, real auth (Supabase), push notifications, real PDF export, charts