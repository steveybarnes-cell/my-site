## MPG Site Records — App Plan

**Company:** My Project Group Ltd
**Concept:** A native iOS/iPad app that replaces messy WhatsApp invoices, PDFs and photos with one standard company system for construction subcontractors. Tradesmen log allocated work, take photos, upload receipts, complete daily site records and submit weekly invoices/timesheets. Admin (Steve) and site managers review, approve, query and pay.

**Platform scope note:** 10x builds native iOS (iPhone + iPad) only. PC hub is delivered via Supabase `report_*` views any PC browser can open.

### v1 Status — COMPLETE (mock/local-first)
All three role experiences built and navigable end to end.

## PHASE 2 — Supabase backend — COMPLETE
- Schema, RLS, auto-create-profile trigger, private storage bucket applied.
- Real auth: email/password + sign-up + Google OAuth, Keychain session persistence + restore.
- Core areas read/write live Supabase. PC-accessible hub via `report_*` views.

## PHASE 3 — COMPLETE
- Real photo image uploads to private `site-evidence` Storage bucket.
- Offline sync queue: disk-backed FIFO, auto-retry, pending-sync banner.
- Dashboard charts (Swift Charts) + branded A4 PDF handover export via ShareLink.
- **Xero — LIVE.** Two Supabase Edge Functions deployed; app wired with signed-in user's Supabase JWT; Client Secret stays server-side.
- **Admin Manage tab.** Admin can add/edit sites, staff, and work allocations in-app.
- **AI receipt scan — LIVE.** `scan-receipt` Edge Function deployed; `ReceiptScanService` calls it with the user's Supabase token. `OPENAI_API_KEY` backend secret is set.

## PHASE 4 — App Store go-live (in progress)

### Done
- Demo Sign-in gated for release; Demo Mode always available via login role-picker.
- Admin role confirmed (Steve, info@my-project.co.uk).
- Production Audit complete.
- Submission details recorded: support email info@my-project.co.uk, legal seller "My Project Group Limited", App Review phone 0117 251 0565.
- **Device connectivity fix.** `SupabaseConfig` has both public client-safe values baked in (project URL + publishable/anon key), used after env vars / Info.plist.
- **Account deletion (Apple Guideline 5.1.1) — DONE.** `delete-account` Edge Function deployed + ACTIVE; app-side flow + confirmation.
- **Launch watchdog crash (0x8BADF00D) — FIXED.** Dedicated `URLSession` (15s/25s timeouts); `AuthManager.restore()` wrapped in a hard 12s cap.

### Blocked on user
- App Store Connect fields (Support URL, Privacy Policy URL, seller, App Review phone) + five legal sign-offs.
- Choose build + Contact Information in App Store Connect, then submit.

## PHASE 5 — Team feed / company group chat (local demo)
- **Models:** `FeedPost` + `FeedComment` in `Models/CompanyFeed.swift`.
- **UI:** `CompanyFeedView`, `FeedComposerView`, `FeedCommentsView`.
- Distinct-from-Instagram design (Acknowledge tick, pill actions, card posts, rendered/real site photos).
- **Team** tab is the default/first tab on app open in all three role root views.
- Currently local/in-memory only — resets on relaunch, no cross-device sync yet.

## PHASE 6 — Demo Mode (all builds)
- Always-available Demo Mode via "Explore in Demo Mode" on `LoginView` → `Views/DemoModeView.swift`.

## PHASE 7 — Communication + visibility upgrades (local/mock)
- **In-app calling.** `Models/CallService.swift` (@Observable) drives a modelled VoIP flow (ringing → connected → live timer, mute/speaker/end). `Views/Shared/CallView.swift`: `CallOverlay` (top-level, cross-tab), `CallScreen`, `StartCallView`. Scope note: modelled call, no real telephony yet.
- **Per-site feed filter.** `AppStore.feed(siteId:)` + `SiteFilterBar`/`FilterChip` chip row scopes feed to one site.
- **Live feed feel.** `LivePill`, 5s `Timer.publish` tick, pull-to-refresh (reloads Supabase when `isLiveBackend`).
- **Admin "Work by Trade".** `TradeWorkFeedView` + **Trades** tab; unified `TradeWorkItem` timeline per trade.

## PHASE 8 — Advertise AI receipt automation (NEW)
- Made the AI receipt scanning + automatic Hubdoc/Xero upload a headline, user-visible value prop:
  - **LoginView** — charcoal feature card under the logo: "AI receipt scanning", a `Photograph → AI reads it → Hubdoc / Xero` flow row, and supporting copy ("scanned and uploaded to Hubdoc and Xero automatically — no more lost paperwork or manual data entry").
  - **DemoModeView** — matching light `aiReceiptCard` so demo explorers see the same promise.
  - **MaterialFormView** — receipt section header subtitle now states the automatic scan + Hubdoc/Xero upload at the point of capture (in addition to the existing live auto-send status label).
- Copy only; underlying scan (`ReceiptScanService`) and Xero push already exist. Auto-upload fires when Xero is connected; otherwise the "connect Xero" prompt still shows.

### Deferred / Next
- Wire in-app calling to real telephony (CallKit + VoIP provider).
- Wire Team feed to Supabase (`feed_posts` / `feed_comments` + RLS) with real photo uploads for cross-device sync.
- Regenerate app icon from the MY Site mark; decide on remaining "MPG"/"My Project Group" copy.
- Push notifications, optional branded web portal.

### Design
Reuse MPG system (charcoal + green, `mpgCard()`, `mpgFormSection()`, `Brand` tokens, shared `Field`/`SectionHeader`/`PrimaryButton`).