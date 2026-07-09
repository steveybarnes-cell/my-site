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
- **Device connectivity fix.** `SupabaseConfig` has both public client-safe values baked in (project URL + publishable/anon key), used after env vars / Info.plist. Fully self-contained for device / TestFlight / App Store builds.
- **Account deletion (Apple Guideline 5.1.1) — DONE.** `delete-account` Edge Function deployed + ACTIVE; app-side flow + confirmation.
- **Launch watchdog crash (0x8BADF00D) — FIXED.** Crash report decoded to the iOS watchdog kill with 0% app CPU = main flow blocked on a hanging launch network call. `SupabaseClient` now uses a dedicated `URLSession` (15s request / 25s resource timeout, `waitsForConnectivity = false`); `AuthManager.restore()` is wrapped in a hard 12s cap that resolves cleanly to the login screen if the session refresh stalls, so launch can never freeze on the "restoring" spinner and get killed on background.

### Blocked on user
- **App Store Connect fields**: Support URL, Privacy Policy URL, seller, App Review phone (Prefill).
- **Prefill review confirmations**: five legal sign-offs must be ticked by the user.
- **Choose build + Contact Information** in App Store Connect, then submit.

### Remaining Publishing stages
- Prefill → attach build → Submission → Management.

## PHASE 5 — Team feed / company group chat (local demo)
- **Models:** `FeedPost` + `FeedComment` in `Models/CompanyFeed.swift`.
- **UI:** `CompanyFeedView` (Instagram-style), `FeedComposerView`, `FeedCommentsView`.
- **Navigation:** "Team" tab is the default/first tab on app open in all three role root views.
- **Scope note:** Currently local/in-memory only — resets on relaunch, no cross-device sync yet.

## PHASE 6 — Demo Mode (all builds)
- **Always-available Demo Mode** via "Explore in Demo Mode" on `LoginView` → `Views/DemoModeView.swift` (role picker + sample team-member list). `AuthManager.enterDemo(as:)` starts a session without Supabase.

### Deferred / Next
- Wire Team feed to Supabase (`feed_posts` / `feed_comments` tables + RLS) with real photo uploads.
- Add Supabase save endpoints for sites + staff so Manage tab writes persist across devices.
- Optionally extend AI receipt scan to the general Add File / PhotoCaptureView receipt uploads.
- Push notifications, optional branded web portal.

### Design
Reuse MPG system (charcoal + green, `mpgCard()`, `mpgFormSection()`, `Brand` tokens, shared `Field`/`SectionHeader`/`PrimaryButton`).