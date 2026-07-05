## MPG Site Records — App Plan

**Company:** My Project Group Ltd
**Concept:** A native iOS/iPad app that replaces messy WhatsApp invoices, PDFs and photos with one standard company system for construction subcontractors. Tradesmen log allocated work, take photos, upload receipts, complete daily site records and submit weekly invoices/timesheets. Admin (Steve) and site managers review, approve, query and pay.

**Platform scope note:** 10x builds native iOS (iPhone + iPad), not web/Android/desktop browser. Delivered as a native iOS app covering the same functionality.

### v1 Status — COMPLETE (mock/local-first)
Role-based entry with mock auth (Admin / Site Manager / Tradesman). All three role experiences built and navigable end to end (Today, Records, Files, Invoices, Alerts, Profile; Admin dashboard, payment run, integrations; Site Manager sites/records review).

---

## NEXT FEATURE — Site Files Hub (in progress)

**Decision:** Build as a feature inside the existing MPG app, reusing the current charcoal + green design system (`MPGLogo`, `mpgCard()`, `MPGBackground()`, `Brand` tokens, role routing). NOT a website clone — the `C.pdf` website import failed (no screenshots/DOM), so no source-derived visuals exist; we extend the established in-app design language instead.

**Files tab decision:** REPLACE the current flat Files tab with a site-first Hub. Flow: pick a Site → see that site's file categories → drill into a category → files. Existing file model/pipeline is reused and extended, not thrown away.

**Sync decision:** User asked for real Google Drive + Sheets. Honest scope — real Drive uploads + Sheets row-append need Google OAuth + a server-side backend (Drive API + Sheets API), which is not stood up from scratch here. v1 ships the COMPLETE client modelled locally (exact folder-path convention + Site Files Register row projection), Phase 2 swaps in real Google OAuth + backend.

### Site Files Hub — v1 scope
- **Site-first Hub screen:** list of sites → each opens its Site Files Hub with the full folder groups (Drawings, Structural Calcs, Building Control, Photos, Receipts, Supplier Invoices, Variations, Snagging, Client Instructions, Programme/Schedule, RAMS/H&S, Quotes/Orders, Reports, Handover Documents, Other Files).
- **Full category set (23):** Drawings, Structural calculations, Building control, Planning, Client instruction, Variation evidence, Snagging, Site photos, Progress photos, Before photos, Completed works, Delay evidence, Damage/issue evidence, Materials receipt, Supplier invoice, Quote/order, RAMS, Health & safety, Programme/schedule, Report, Handover, Warranty, Other.
- **Add file — two paths:** (1) Upload file (camera/gallery/document, all listed file types); (2) Add Google Drive link (title, URL, category, site, description, uploaded by, date, visibility). Tapping a Drive-linked file opens the URL.
- **File metadata:** full set per spec — File ID, Site ID/name, title, category, type, uploaded by, date/time, related tradesman/allocation/daily record/weekly invoice/variation/material, description, Drive/internal URL, visibility, approval status, tags.
- **Drive folder-path convention (modelled):** `My Project Group - Site Record System → Site Files → Site Name → Category → Week Ending/Date → File` with auto-rename (`Uploader - Description.ext`).
- **Site Files Register (modelled Sheets tab):** every file/link projects a row with all specified columns; central register view.
- **Linking:** files linkable to work allocation, daily record, weekly invoice, material, receipt, variation, delay, snag, site issue, handover pack.
- **Approval labels:** green = approved, amber = awaiting/missing, red = rejected/missing evidence.
- **Permissions:** Admin (all sites, full control), Site Manager (assigned sites, upload/approve/flag), Tradesman (own uploads + shared allocated-site files only; blocked from other tradesmen's invoices/bank details, private admin files, non-allocated sites).
- **Prompts/warnings:** variation needs photo evidence, material claim needs VAT receipt, site has no drawings, receipt missing, before/after photos before variation submit, site manager requested photos.
- **Search:** across site name, file title, category, tradesman, supplier, receipt no., invoice no., variation ID, date, notes, tags.
- **Handover pack:** mark files into the handover pack (BC docs, electrical/gas certs, structural drawings, warranties, manuals, photos, final invoice, completion notes, snag completion); export a handover file-list/PDF index.
- **Admin dashboard widgets:** files this week, files by site, missing receipts, missing variation photos, awaiting approval, recently uploaded, sites with no drawings, sites missing H&S docs, evidence linked to variations, handover ready/missing.

### Design
Reuse existing MPG system. Site file cards, category filter chips, search bar, Upload + Add Drive Link buttons, clear role permissions, green/amber/red approval labels. Simple and professional, charcoal + green.

### Architecture
- `@Observable` AppStore holds all mock data + current user/role; extend `SiteFile` model with new metadata + relations; add per-site grouping + category enum.
- Role-based visibility enforced by filtering.

### Deferred (Phase 2/3)
- Real Google Drive upload + Sheets append (Google OAuth + backend/Edge Function), real Xero/Hubdoc OAuth, real auth (Supabase), push notifications, real PDF handover export, charts.