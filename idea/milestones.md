- [x] Brand theme + design system + models
- [x] AppStore with realistic sample data + role auth
- [x] Role-based login + root routing
- [x] Tradesman / Admin / Site Manager flows
- [x] Notifications + warnings, Files tab, company dashboard, Xero/Hub sync (modelled), receipt capture
- [x] Site Files Hub (categories, Drive convention, register, handover, dashboard widgets)
- [x] Geofenced clock-in/out + Attendance overview (map, review, approve/reject)
- [x] Submission-ready: Info.plist usage strings; App Store assets + audit + prefill drafts
- [x] Phase 2 backend: Supabase schema + RLS + Storage bucket SQL migrations applied
- [x] Phase 2 backend: Supabase client + session/Keychain + Google OAuth flow
- [x] Phase 2 backend: real auth (email/password + sign-up + Google) + session restore + role routing
- [ ] Phase 2 backend: Google Cloud OAuth client configured in Supabase Auth (user step)
- [ ] Phase 2 backend: promote Steve's profile row to Admin once he signs in (user step)
- [ ] Phase 2 backend: switch AppStore reads/writes to live Supabase data (loading/empty/error states)
- [ ] Offline work logging: local persistence + sync queue drains to Supabase once live
- [ ] Phase 3: real Google Drive/Sheets sync, Xero OAuth, PDF export</parameter>
<parameter name="plan">## MPG Site Records — App Plan

**Company:** My Project Group Ltd
**Concept:** A native iOS/iPad app that replaces messy WhatsApp invoices, PDFs and photos with one standard company system for construction subcontractors. Tradesmen log allocated work, take photos, upload receipts, complete daily site records and submit weekly invoices/timesheets. Admin (Steve) and site managers review, approve, query and pay.

**Platform scope note:** 10x builds native iOS (iPhone + iPad). The PC-accessible "central hub" is delivered via the Phase 2 Supabase backend (Supabase dashboard now; a web admin page later).

### v1 Status — COMPLETE (mock/local-first)
All three role experiences built and navigable end to end. Site Files Hub, geofenced clock-in/out, and Attendance overview shipped.

---

## PHASE 2 — Supabase backend (IN PROGRESS)

**Goal:** Turn the on-device app into one shared company system so all data lives in the cloud, everyone signs in with their own account, and Steve can open the data from any PC browser.

### Done
- Supabase project connected via Integrations.
- Schema, RLS + role helpers (`current_role()`, `is_admin()`, `manages_site()`), auto-create-profile trigger, and private `site-evidence` storage bucket — all migrations applied to the live project.
- Supabase auth/data client (`SupabaseClient`), Codable session + Keychain persistence, Google OAuth flow (`OAuthFlow`).
- **Real auth wired into the app** (`AuthManager` + `LoginView` + `ContentView` + `App.swift`):
  - Email/password sign-in and sign-up against Supabase GoTrue.
  - Google OAuth sign-in via hosted provider + app-scheme callback.
  - Session persisted in Keychain; restored and refreshed on launch with a branded loading state.
  - Signed-in user's `profiles` row fetched via PostgREST; real `role` drives root routing.
  - Sign-out revokes server-side session and clears Keychain.
  - Demo Sign-in card retained, clearly labelled development-only, for testing any role.
  - Verified `profiles.role` enum (Admin / Site Manager / Tradesman) matches app `UserRole`.

### Blocked on user
- **Google provider config:** add a Google Cloud OAuth client in Supabase Auth → Providers → Google and register redirect scheme `mpgsiterecords://auth-callback`. Until then, email/password or Demo login work.
- **Admin promotion:** `profiles` is empty. Once Steve signs in with `myprojectgroupltd@gmail.com`, promote that row to Admin (others default to Tradesman via trigger).

### Remaining app-code steps
1. Switch AppStore reads/writes to live Supabase data with loading/empty/error states.
2. Offline sync queue drains to Supabase once live.

### Dependencies
- Supabase (clientRuntime; SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY) — connected.
- Google sign-in requires the Google Cloud OAuth client above.

### Deferred (Phase 3)
- Real Google Drive upload + Sheets append, Xero/Hubdoc OAuth, push notifications, PDF handover export, charts.

### Design
Reuse existing MPG system (charcoal + green, `mpgCard()`, `Brand` tokens). Sync/status uses amber pending, green synced, red failed.</parameter>
</invoke>