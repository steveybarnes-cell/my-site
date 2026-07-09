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
- **AI receipt scan — LIVE (needs OpenAI key).** `scan-receipt` Edge Function deployed; `ReceiptScanService` calls it with the user's Supabase token. Requires `OPENAI_API_KEY` backend secret to function live.

## PHASE 4 — App Store go-live (in progress)

### Done
- Demo Sign-in gated for release (then temporarily exposed on device for admin access without an account).
- Admin role confirmed (Steve, info@my-project.co.uk).
- Production Audit complete.
- Submission details recorded: support email info@my-project.co.uk, legal seller "My Project Group Limited", App Review phone 0117 251 0565.
- Device connectivity fix (Info.plist fallback for Supabase URL + publishable key).
- **Account deletion (Apple Guideline 5.1.1) — DONE.** `delete-account` Edge Function deployed + ACTIVE; app-side `AccountService.deleteAccount` + Profile delete button with confirmation.

### Blocked on user
- **OpenAI key** for AI receipt scan: add `OPENAI_API_KEY` in Backend > Secrets.
- **App Store Connect fields**: Support URL, Privacy Policy URL, seller, App Review phone.
- **Choose build + Contact Information** in App Store Connect, then submit.

### Remaining Publishing stages
- Prefill → attach build → Submission → Management.

## PHASE 5 — Team feed / company group chat (NEW — local demo)
- **Models:** `FeedPost` (author, role, text, photo SF-symbol stand-ins, optional site tag, likes, comments) + `FeedComment` in `Models/CompanyFeed.swift`.
- **AppStore:** `feedPosts` state + `feed` (newest-first), `addFeedPost`, `toggleLike`/`isLiked`, `addComment`, `deleteFeedPost` (author or admin only). Realistic seeded posts.
- **UI:** `CompanyFeedView` (wall + composer entry), `FeedComposerView` (text, site tag, demo photo attach), `FeedCommentsView` (thread + inline chat composer). Reuses Brand tokens, `mpgCard()`, shared components.
- **Navigation:** "Team" tab (bubble.left.and.bubble.right.fill) added to all three role root views.
- **Scope note:** Currently local/in-memory only — resets on relaunch, no cross-device sync yet.

### Deferred / Next
- Wire Team feed to Supabase (`feed_posts` / `feed_comments` tables + RLS) with real photo uploads to `site-evidence`, using the existing offline sync queue.
- Add Supabase save endpoints for sites + staff so Manage tab writes persist across devices.
- Optionally extend AI receipt scan to the general Add File / PhotoCaptureView receipt uploads.
- Push notifications, optional branded web portal.

### Design
Reuse MPG system (charcoal + green, `mpgCard()`, `mpgFormSection()`, `Brand` tokens, shared `Field`/`SectionHeader`/`PrimaryButton`). Delete uses `Brand.red` destructive style.