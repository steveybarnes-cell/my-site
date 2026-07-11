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
- Device connectivity fix; account deletion (5.1.1); launch watchdog crash fixed.

### Blocked on user
- App Store Connect fields (Support URL, Privacy Policy URL, seller, App Review phone) + five legal sign-offs.
- Choose build + Contact Information in App Store Connect, then submit.

## PHASE 5 — Team feed / company group chat (local demo)
- **Models:** `FeedPost` + `FeedComment` in `Models/CompanyFeed.swift`.
- **UI:** `CompanyFeedView`, `FeedComposerView`, `FeedCommentsView`. Per-site filter chips, pull-to-refresh, uniform fixed-height feed photos.
- **Team** tab is the default/first tab on app open in all three role root views.
- Currently local/in-memory only — resets on relaunch, no cross-device sync yet.

## PHASE 6 — Demo Mode (all builds)
- Always-available Demo Mode via "Explore in Demo Mode" on `LoginView` → `Views/DemoModeView.swift`.

## PHASE 7 — Communication + visibility upgrades (local/mock)
- **In-app calling** (`CallService`), **per-site feed filter**, **live feed feel**, **Admin Work by Trade**.

## PHASE 8 — Advertise AI receipt automation
- AI receipt scanning + auto Hubdoc/Xero upload surfaced across LoginView, DemoModeView, MaterialFormView.

## PHASE 9 — Navigation streamlining (NEW — done)
- **Problem:** each role had 7-9 tabs, overflowing into iOS's auto-generated "More" list and making the app hard to navigate.
- **Fix:** consolidated every role to a consistent **5-tab** layout so muscle memory carries across roles. Team is always first; Alerts (with unread badge) is always fourth; More is always fifth.
  - **Tradesman:** Team · Today · Files · Alerts · More
  - **Admin:** Team · Dashboard · Invoices · Alerts · More
  - **Site Manager:** Team · My Sites · Records · Alerts · More
- **New reusable `MoreHubView`** (`Views/Shared/MoreHubView.swift`) with `MoreHubItem` — a scannable secondary-navigation hub (icon, title, subtitle, optional badge, chevron) collecting less-frequent areas in one predictable place:
  - Tradesman More → My Records, Invoices & Timesheets, Profile
  - Admin More → Manage, Work by Trade, Attendance, Files, Profile & Integrations
  - Site Manager More → Dashboard, Attendance, Files, Profile

### Deferred / Next (streamline pass 2, recommended)
- Global "+" create action (New post / Photo / Receipt / Daily record / Timesheet).
- Feed "Needs action / Unread" filter + pin queried invoices/urgent items.
- Tab badge counts for invoices to approve, timesheets to pay, open queries.
- Wire in-app calling to real telephony (CallKit + VoIP provider).
- Wire Team feed to Supabase (`feed_posts` / `feed_comments` + RLS) with real photo uploads for cross-device sync.
- Push notifications, optional branded web portal.

### Design
Reuse MPG system (charcoal + green, `mpgCard()`, `mpgFormSection()`, `Brand` tokens, shared `Field`/`SectionHeader`/`PrimaryButton`).