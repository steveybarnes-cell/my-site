## MPG Site Records — App Plan

**Company:** My Project Group Ltd
**Concept:** A native iOS/iPad app that replaces messy WhatsApp invoices, PDFs and photos with one standard company system for construction subcontractors. Tradesmen log allocated work, take photos, upload receipts, complete daily site records and submit weekly invoices/timesheets. Admin (Steve) and site managers review, approve, query and pay.

**Platform scope note:** 10x builds native iOS (iPhone + iPad) only. PC hub is delivered via Supabase `report_*` views any PC browser can open.

### v1 Status — COMPLETE (mock/local-first) then backed by Supabase
All three role experiences built and navigable end to end; core areas read/write live Supabase.

## PHASE 2 — Supabase backend — COMPLETE
- Schema, RLS, auto-create-profile trigger, private storage bucket applied.
- Real auth: email/password + sign-up + Google OAuth, Keychain session persistence + restore.
- Core areas read/write live Supabase. PC-accessible hub via `report_*` views.

## PHASE 3 — COMPLETE
- Real photo uploads to private `site-evidence` bucket; disk-backed offline sync queue.
- Dashboard charts (Swift Charts) + branded A4 PDF handover export via ShareLink.
- **Xero — LIVE** (two Supabase Edge Functions; client secret server-side).
- **Admin Manage tab** — add/edit sites, staff, allocations in-app.
- **AI receipt scan — LIVE** (`scan-receipt` Edge Function + `OPENAI_API_KEY`).

## PHASE 4 — App Store go-live (in progress)

### Done
- Demo Sign-in gated behind `#if DEBUG`; Demo Mode always available via role-picker.
- Production Audit complete; account deletion (5.1.1); launch watchdog crash fixed.
- Build uploaded: App ID 6789147701, version 1.0, build 1.

### App Review v1.0 REJECTED (submission b7d2dd2a, iPad Air 11" M3) — two issues, both addressed:
1. **Guideline 2.2** — fake in-app VoIP call replaced with real `tel://` system call. FIXED in code.
2. **Guideline 5.1.2(i)** — app genuinely does not track; App Store Connect App Privacy label fix (user-side).

### Blocked on user (resubmission)
- Correct App Privacy: mark every collected data type "not used to track."
- Upload a new build (increment build number) with the call fix; add Review Notes; resubmit.
- Prefill still Needs Review: support URL, privacy policy URL, seller name, App Review phone, jurisdiction (England & Wales).

## PHASE 5-14 — COMPLETE
- Team feed / company group chat (local, Instagram-style centred card with MPG identity).
- Demo Mode; per-site feed filter; Admin Work by Trade.
- AI Invoice Auditor; AI Weekly Recap; AI Ask MPG (local natural-language query).
- Consistent 5-tab navigation per role + reusable More hub. Team is the default tab.
- Branding: MPGLogo simplified to roofline gable + wordmark.
- Calling — REAL system dialer (`tel:`), no simulated VoIP.

### Offline site record drafts — COMPLETE
- New `DraftStore` (Models/DraftStore.swift): disk-backed, fully local, relaunch-safe, one draft per allocation.
- `DailyRecordFormView` save-draft/auto-restore; `TradesmanRecordsView` Saved drafts card (resume/delete).

### Notifications & approval alerts — COMPLETE
- `NotificationPreferencesStore` (Models/NotificationPreferences.swift): disk-backed per-user prefs (master switch + per-event `NotifyCategory` toggles), relaunch-safe, defaults on.
- `LocalNotificationService`: UNUserNotificationCenter local (on-device) banner delivery; authorization requested at launch.
- `AppStore.notify(_:category:message:)` + `notifyOffice(...)`: category-aware, respects prefs, records in-app notification and fires a local banner for the signed-in recipient.
- Triggers wired: invoice/timesheet submitted → admin + all site managers; daily site record submitted → office; invoice queried/held/rejected → subcontractor; invoice paid/approved → subcontractor; new work allocated → tradesman; attendance/file events reuse the routed path.
- `NotificationSettingsView` (role-aware toggle list) opened from a slider button in the Alerts tab.
- **Admin pending-review digest — COMPLETE**: `pendingAdminReviewCount` (submitted/approvedSM/queried/on-hold invoices + attendance needing manual approval) drives both the Dashboard "Invoices to review" tile and a proactive `notifyPendingReviews()` reminder fired once per launch when Steve opens the app (`AdminRootView.onAppear`). New `.pendingReview` `NotifyCategory` with its own admin toggle. Respects prefs; in-app alert + local banner.
- **Scope:** local notifications only today. Real remote delivery when app is fully closed (APNS) needs push certs + server + physical-device validation — deferred (event triggers + prefs already built, so it's a delivery swap not a rebuild).

### AI roadmap (proposed next)
- Optional AI phrasing pass on Weekly Recap via `scan-receipt` Edge Function pattern.
- Smart AI Xero line descriptions before push; AI photo captions/tagging.

### Deferred / Next
- Remote push delivery (APNS): push certificates + server, validate on physical device.
- Global "+" create action; tab badge counts.
- Wire Team feed to Supabase (`feed_posts` / `feed_comments` + RLS) with real photo uploads.
- Optional branded web portal.

### Design
Reuse MPG system (charcoal + green, `mpgCard()`, `mpgFormSection()`, `Brand` tokens, shared `Field`/`SectionHeader`/`PrimaryButton`).