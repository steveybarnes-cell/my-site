- [x] Brand theme + design system + models
- [x] AppStore with realistic sample data + role auth
- [x] Role-based login + root routing
- [x] Tradesman / Admin / Site Manager flows
- [x] Notifications + warnings, Files tab, company dashboard, Xero/Hub sync (modelled), receipt capture
- [x] Site Files Hub (categories, Drive convention, register, handover, dashboard widgets)
- [x] Geofenced clock-in/out + Attendance overview (map, review, approve/reject)
- [x] Submission-ready: Info.plist camera/photo library/location usage strings; App Store assets + audit + prefill drafts
- [ ] Offline work logging: local persistence (SwiftData) so nothing is lost on relaunch
- [ ] Offline work logging: PendingChange sync queue + connectivity monitor
- [ ] Offline work logging: route record/material/photo/clock/submission mutations through queue
- [ ] Offline work logging: auto-drain on reconnect + offline banner / sync badges / retry UI
- [ ] Phase 2: real Google Drive/Sheets sync, real auth, PDF export (offline queue drains to backend)</parameter>
<parameter name="plan">## MPG Site Records — App Plan

**Company:** My Project Group Ltd
**Concept:** A native iOS/iPad app that replaces messy WhatsApp invoices, PDFs and photos with one standard company system for construction subcontractors. Tradesmen log allocated work, take photos, upload receipts, complete daily site records and submit weekly invoices/timesheets. Admin (Steve) and site managers review, approve, query and pay.

**Platform scope note:** 10x builds native iOS (iPhone + iPad), not web/Android/desktop browser. Delivered as a native iOS app covering the same functionality.

### v1 Status — COMPLETE (mock/local-first)
Role-based entry with mock auth (Admin / Site Manager / Tradesman). All three role experiences built and navigable end to end. Site Files Hub, geofenced clock-in/out, and Attendance overview shipped.

### Release readiness — IN PROGRESS
- App Store assets generated (icon, 5 screenshots, description) in `growth/app-store`.
- Production audit passed (no security blockers; app is local/mock).
- Prefill drafts generated (privacy policy, terms, support page, review notes, keywords).
- `Info.plist` added with camera, photo library, and location (when-in-use) usage descriptions so the app is submission-ready and won't crash on real-device permission prompts.
- **Blocked on user:** paid Apple Developer Program + App Store Connect API key (Code → Release → Credentials), plus business/legal details (support email/URL, legal entity, review contact phone) and confirming the legal drafts.
- **Recommended first ship:** TestFlight (external testers via link) for the real-world site trial before a public App Store release, since Drive/Sheets/Xero/shared accounts are still modelled.

---

## NEXT FEATURE — Offline Work Logging (scoping)

**Why:** Tradesmen on site often have no reliable connectivity. Right now every log action assumes data is saved instantly to the in-memory store. On a real backend that means lost daily records, photos, materials, and clock-ins when signal drops. The app must let a tradesman capture everything offline and sync it automatically once back online, with clear status so nothing is silently lost.

### What must work offline
- **Daily site records** — write/edit fully offline.
- **Materials / receipts** — add offline with captured photo.
- **Site photos & file uploads** — captured and queued; binary stored locally until upload.
- **Geofenced clock-in / clock-out** — GPS + timestamp captured offline (highest-integrity data; must never be lost).
- **Weekly submission drafts** — editable offline, submitted when back online.

### Offline architecture (planned)
- **Local-first persistence:** move mock in-memory arrays onto durable on-device storage (SwiftData). Load `swiftdata` skill before implementing.
- **Sync queue:** every create/edit while offline becomes a `PendingChange` (type, payload, capturedAt, local media path, sync state: `pending → syncing → synced → failed`).
- **Connectivity monitor:** `NWPathMonitor` drives an online/offline flag; when online, drain the queue oldest-first.
- **Conflict / ordering rules:** clock events keep their real captured timestamp; records are last-write-wins per record id.
- **Media handling:** photos saved to app sandbox immediately; only the upload is deferred.
- **UI status surfacing:** offline banner, per-item sync badges (queued / synced / failed), a "Pending sync (N)" indicator, and manual "Retry sync".

### Scope honesty
Real server sync needs the Phase 2 backend (Supabase/Drive). This feature ships the COMPLETE offline capture + local persistence + sync-queue + status UI now, draining against the existing local store (simulated "server"). When the real backend lands, the queue drains to it instead.

### Deferred (Phase 2/3)
- Real Google Drive upload + Sheets append, real Xero/Hubdoc OAuth, real auth (Supabase), push notifications, PDF handover export, charts. Offline queue drains to this real backend once available.

### Design
Reuse existing MPG system (charcoal + green, `mpgCard()`, `Brand` tokens). Offline status uses amber for pending, green for synced, red for failed — consistent with existing approval labels.</parameter>
</invoke>