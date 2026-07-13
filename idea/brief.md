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

## PHASE 9 — Navigation streamlining — done
- Consolidated every role to a consistent **5-tab** layout with a reusable `MoreHubView`.
  - **Tradesman:** Team · Today · Files · Alerts · More
  - **Admin:** Team · Dashboard · Invoices · Alerts · More
  - **Site Manager:** Team · My Sites · Records · Alerts · More

## PHASE 10 — Branding: logo matched to app icon — DONE
- Redrew `MYSiteMark` to the clean roofline gable + "MY" green / "SITE" charcoal wordmark; hard hat removed.

## PHASE 11 — Team feed redesign — DONE
- Centred single column (max width 500pt), edge-to-edge card, olive accent rail, location ribbon, square-tick acknowledge burst.

## PHASE 12 — AI Invoice Auditor — DONE
- **Goal:** turn Steve's approval job from reading every invoice into reviewing only flagged exceptions.
- **Engine (`Models/InvoiceAuditor.swift`):** fully local, deterministic, explainable. Runs on the real data the app already holds. Produces a scored `InvoiceAudit` (0–100 risk) from weighted `AuditFinding`s across six checks:
  1. Claimed hours vs geofenced GPS time on site (±20% tolerance).
  2. Attendance events outside geofence / no location that are not yet approved.
  3. Materials billed without a receipt (or billed with none logged).
  4. Labour claimed with no before/during/completed photos.
  5. Submitted after the Monday 13:00 deadline.
  6. Duplicate invoice number across submissions.
- **UI (`Views/Admin/InvoiceAuditView.swift`):** ring-gauge score + verdict, worst-first findings list, disclaimer that the decision stays with the office. Each `AdminSubmissionRow` shows a compact sparkles risk badge + "Review AI audit / clear" button opening the sheet.
- **Future enrichment:** an optional LLM pass (via the existing `scan-receipt` Edge Function pattern) could rephrase flags into a friendly office note; numbers stay grounded in real data.

### AI roadmap (proposed next)
- **Voice-to-daily-record** (tradesman mic → structured site record) — biggest adoption lever.
- AI photo captions/tagging; weekly plain-English spend summary; smart Xero line descriptions; "Ask MPG" natural-language search.

### Deferred / Next
- Global "+" create action; feed "Needs action / Unread" filter; tab badge counts.
- Wire in-app calling to real telephony (CallKit + VoIP provider).
- Wire Team feed to Supabase (`feed_posts` / `feed_comments` + RLS) with real photo uploads for cross-device sync.
- Push notifications, optional branded web portal.

### Design
Reuse MPG system (charcoal + green, `mpgCard()`, `mpgFormSection()`, `Brand` tokens, shared `Field`/`SectionHeader`/`PrimaryButton`).