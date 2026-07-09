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
- **Account deletion (Apple Guideline 5.1.1) — DONE.** `delete-account` Edge Function deployed + ACTIVE (verify_jwt on): verifies caller JWT, then uses server-side service-role key to permanently delete the auth user + profile row (owned data cascades). App side: `AccountService.deleteAccount(token:)`, `AuthManager.deleteAccount()` (deletes then clears Keychain + signs out), and a "Delete my account" button on the Profile screen with a destructive confirmation alert and an error alert. Edge-function source stored as `*.ts.txt` to avoid duplicate `index.ts` bundle-resource build collisions.

### Blocked on user
- **OpenAI key** for AI receipt scan: add `OPENAI_API_KEY` in Integrations → Hosted Keys.
- **App Store Connect fields** (user-entered): Support URL `https://my-project.co.uk`, Privacy Policy URL `https://my-project.co.uk/privacy`, seller "My Project Group Limited", App Review phone `+44 117 251 0565`.
- **Choose build + Contact Information** in App Store Connect, then type SUBMIT to unlock final submission.

### Remaining Publishing stages
- Prefill → attach build → Submission → Management.

### Deferred / Next
- Add Supabase save endpoints for sites + staff so Manage tab writes persist across devices.
- Optionally extend AI receipt scan to the general Add File / PhotoCaptureView receipt uploads.
- Push notifications, optional branded web portal.

### Known infra note
- `TenXPreviewSupport.swift` (10x-managed preview helper) can report a stale build-copy error (`TenXDateFormatting` not in scope) out of sync with its source; app code compiles cleanly and it clears on project regeneration.

### Design
Reuse MPG system (charcoal + green, `mpgCard()`, `mpgFormSection()`, `Brand` tokens, shared `Field`/`SectionHeader`/`PrimaryButton`). Delete button uses `Brand.red` outlined style.