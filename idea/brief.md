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
- Demo Sign-in gated behind `#if DEBUG` (absent from Release); Demo Mode always available via role-picker.
- Production Audit complete; account deletion (5.1.1); launch watchdog crash fixed.
- Build uploaded: App ID 6789147701, version 1.0, build 1.

### App Review v1.0 REJECTED (submission b7d2dd2a, iPad Air 11" M3) — two issues, both addressed:
1. **Guideline 2.2 (beta/limited feature set)** — root cause was the **simulated in-app VoIP call screen** (fake ringing/timer). FIXED in code: deleted mock `CallService` + `CallOverlay`; `StartCallView` now places a **real system phone call via `tel://`** using each teammate's stored number, with a clear "no number on file" state. Compiles clean.
2. **Guideline 5.1.2(i) (privacy/tracking label)** — the app genuinely does **not track** (verified: no IDFA/ATT/SKAdNetwork/AdSupport/analytics/ad SDKs anywhere). This is an **App Store Connect App Privacy label error**, fixable only by the Account Holder/Admin.

### Blocked on user (resubmission)
- Correct App Privacy: mark every collected data type (Photos, Name, Email, Precise Location, Messages) as **"not used to track."**
- Upload a new build (increment build number) with the call fix; add Review Notes documenting (a) `tel:` calling is a real feature, (b) app does not track; keep demo credentials (Steve / info@my-project.co.uk / Admin); Add for Review → Submit.
- Prefill still Needs Review: support URL, privacy policy URL, seller name, App Review phone, jurisdiction (England & Wales).

## PHASE 5-14 — COMPLETE
- Team feed / company group chat (local, centred phone-width Instagram-style card with MPG identity).
- Demo Mode; per-site feed filter; Admin Work by Trade.
- AI Invoice Auditor; AI Weekly Recap; AI Ask MPG (local natural-language query).
- Consistent 5-tab navigation per role + reusable More hub. Team is the default tab.
- Branding: MPGLogo simplified to roofline gable + wordmark.

### Calling — now REAL
- In-app "Call a Teammate" opens the system dialer (`tel:`) with the selected member's number. No simulated VoIP. (CallKit/VoIP provider deferred and not required for App Review.)

### AI roadmap (proposed next)
- Optional AI phrasing pass on Weekly Recap via `scan-receipt` Edge Function pattern.
- Smart AI Xero line descriptions before push; AI photo captions/tagging.

### Deferred / Next
- Global "+" create action; tab badge counts.
- Wire Team feed to Supabase (`feed_posts` / `feed_comments` + RLS) with real photo uploads for cross-device sync.
- Push notifications; optional branded web portal.

### Design
Reuse MPG system (charcoal + green, `mpgCard()`, `mpgFormSection()`, `Brand` tokens, shared `Field`/`SectionHeader`/`PrimaryButton`).