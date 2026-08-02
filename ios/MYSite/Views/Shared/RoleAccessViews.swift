import SwiftUI

// MARK: - Non-admin: redeem a code or request an upgrade

/// Shown on a Tradesman's or Site Manager's profile. Lets them redeem an invite
/// code from an admin, or ask to be upgraded.
struct RoleAccessCard: View {
  @Environment(AppStore.self) private var store
  @Environment(AuthManager.self) private var auth

  @State private var code = ""
  @State private var requestedRole: UserRole = .siteManager
  @State private var myRequests: [RoleRequest] = []
  @State private var working = false
  @State private var message: String?
  @State private var isError = false

  private var token: String? { store.backendToken }
  private var pending: RoleRequest? { myRequests.first(where: { $0.isPending }) }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(
        title: "Access level",
        subtitle: "You're signed in as \(store.currentUser?.role.rawValue ?? "Tradesman")")

      if let message {
        Label(message, systemImage: isError ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
          .font(.footnote.weight(.medium))
          .foregroundStyle(isError ? Brand.red : Brand.paidGreen)
          .frame(maxWidth: .infinity, alignment: .leading)
      }

      if let pending {
        Label(
          "\(pending.requestedRole.rawValue) access requested — waiting for an admin to approve.",
          systemImage: "clock.badge.questionmark"
        )
        .font(.footnote)
        .foregroundStyle(Brand.inkSoft)
        .frame(maxWidth: .infinity, alignment: .leading)
      } else {
        VStack(alignment: .leading, spacing: 8) {
          Text("Have an invite code?")
            .font(.subheadline.weight(.semibold)).foregroundStyle(Brand.ink)
          HStack(spacing: 8) {
            TextField("MPG-XXXX-XXXX", text: $code)
              .textInputAutocapitalization(.characters)
              .autocorrectionDisabled()
              .font(.subheadline.monospaced())
              .padding(.horizontal, 12).padding(.vertical, 10)
              .background(
                Brand.lightGreen.opacity(0.5),
                in: RoundedRectangle(cornerRadius: Brand.Radius.inner, style: .continuous)
              )
              .overlay(
                RoundedRectangle(cornerRadius: Brand.Radius.inner, style: .continuous)
                  .stroke(Brand.hairline, lineWidth: 1))
            Button("Redeem") { Task { await redeem() } }
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(.white)
              .padding(.horizontal, 14).padding(.vertical, 10)
              .background(Brand.olive, in: Capsule())
              .disabled(code.trimmingCharacters(in: .whitespaces).isEmpty || working)
              .opacity(code.trimmingCharacters(in: .whitespaces).isEmpty || working ? 0.5 : 1)
          }

          Divider().overlay(Brand.hairline).padding(.vertical, 4)

          Text("Or ask an admin for access")
            .font(.subheadline.weight(.semibold)).foregroundStyle(Brand.ink)
          Picker("Role", selection: $requestedRole) {
            Text("Site Manager").tag(UserRole.siteManager)
            Text("Admin").tag(UserRole.admin)
          }
          .pickerStyle(.segmented)

          Button("Request \(requestedRole.rawValue) access") { Task { await request() } }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Brand.olive)
            .disabled(working)
        }
      }
    }
    .mpgCard()
    .task { await load() }
  }

  private func load() async {
    guard let token else { return }
    myRequests = (try? await RoleService.myRequests(token: token)) ?? []
  }

  private func redeem() async {
    guard let token else { return }
    working = true
    defer { working = false }
    do {
      let granted = try await RoleService.redeemInvite(
        code: code.trimmingCharacters(in: .whitespaces), token: token)
      code = ""
      isError = false
      message = "You're now \(granted.rawValue). Switching you over…"
      // Re-reads the profile and swaps the whole interface in place.
      await auth.refreshRole()
    } catch let e as SupabaseError {
      isError = true
      message = e.errorDescription
    } catch {
      isError = true
      message = error.localizedDescription
    }
  }

  private func request() async {
    guard let token else { return }
    working = true
    defer { working = false }
    do {
      try await RoleService.requestRole(requestedRole, token: token)
      isError = false
      message = "Request sent. An admin will review it."
      await load()
    } catch let e as SupabaseError {
      isError = true
      message = e.errorDescription
    } catch {
      isError = true
      message = error.localizedDescription
    }
  }
}

// MARK: - Admin: create invites and decide requests

/// Admin-only screen for granting access: generate invite codes to share, and
/// approve or decline upgrade requests.
struct RoleAdminView: View {
  @Environment(AppStore.self) private var store

  @State private var newRole: UserRole = .siteManager
  @State private var expiryDays = 7
  @State private var generated: String?
  @State private var invites: [RoleInvite] = []
  @State private var requests: [RoleRequest] = []
  @State private var working = false
  @State private var errorText: String?

  private var token: String? { store.backendToken }

  var body: some View {
    ZStack {
      MPGBackground()
      ScrollView {
        VStack(spacing: 16) {
          if let errorText {
            WarningBanner(message: errorText, tint: Brand.red)
          }
          inviteCreator
          if !requests.isEmpty { requestsCard }
          if !invites.isEmpty { invitesCard }
        }
        .padding(16)
      }
    }
    .navigationTitle("Access & Invites")
    .task { await load() }
  }

  private var inviteCreator: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(
        title: "Invite someone", subtitle: "Send a one-time code for a higher access level")

      Picker("Role", selection: $newRole) {
        Text("Site Manager").tag(UserRole.siteManager)
        Text("Admin").tag(UserRole.admin)
      }
      .pickerStyle(.segmented)

      Stepper("Expires in \(expiryDays) day\(expiryDays == 1 ? "" : "s")", value: $expiryDays, in: 1...30)
        .font(.subheadline)

      if let generated {
        VStack(alignment: .leading, spacing: 8) {
          Text("Share this code")
            .font(.caption.weight(.bold)).foregroundStyle(Brand.olive).tracking(0.8)
          Text(generated)
            .font(.title3.monospaced().weight(.bold))
            .foregroundStyle(Brand.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
              Brand.lime.opacity(0.28),
              in: RoundedRectangle(cornerRadius: Brand.Radius.inner, style: .continuous))
          ShareLink(
            item:
              "You've been invited to MY Site as \(newRole.rawValue). Download the app, create an account, then enter this code in Profile → Access level: \(generated)"
          ) {
            Label("Share code", systemImage: "square.and.arrow.up")
              .font(.subheadline.weight(.semibold))
              .frame(maxWidth: .infinity)
              .padding(.vertical, 12)
              .foregroundStyle(.white)
              .background(
                Brand.olive,
                in: RoundedRectangle(cornerRadius: Brand.Radius.inner, style: .continuous))
          }
        }
      }

      PrimaryButton(title: generated == nil ? "Generate code" : "Generate another", symbol: "key.fill")
      {
        Task { await generate() }
      }
      .disabled(working)
      .opacity(working ? 0.5 : 1)
    }
    .mpgCard()
  }

  private var requestsCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(
        title: "Pending requests", subtitle: "\(requests.count) waiting on you")
      ForEach(requests) { r in
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            VStack(alignment: .leading, spacing: 2) {
              Text(store.user(r.userId)?.name ?? "Unknown user")
                .font(.subheadline.weight(.semibold)).foregroundStyle(Brand.ink)
              Text("Wants \(r.requestedRole.rawValue) access")
                .font(.caption).foregroundStyle(Brand.inkSoft)
            }
            Spacer()
            StatusChip(text: r.requestedRole.rawValue, color: Brand.blue)
          }
          if !r.note.isEmpty {
            Text(r.note).font(.footnote).foregroundStyle(Brand.inkSoft)
          }
          HStack(spacing: 8) {
            Button("Approve") { Task { await decide(r, approve: true) } }
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(.white)
              .padding(.horizontal, 16).padding(.vertical, 8)
              .background(Brand.paidGreen, in: Capsule())
            Button("Decline") { Task { await decide(r, approve: false) } }
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(Brand.red)
              .padding(.horizontal, 16).padding(.vertical, 8)
              .background(Capsule().stroke(Brand.red.opacity(0.4), lineWidth: 1))
            Spacer()
          }
          .buttonStyle(.plain)
        }
        .mpgFormSection(padding: 12)
      }
    }
    .mpgCard()
  }

  private var invitesCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Invite history")
      ForEach(invites) { inv in
        HStack {
          VStack(alignment: .leading, spacing: 2) {
            Text(inv.code).font(.footnote.monospaced().weight(.semibold))
              .foregroundStyle(Brand.ink)
            Text(inv.role.rawValue).font(.caption2).foregroundStyle(Brand.inkSoft)
          }
          Spacer()
          StatusChip(
            text: inv.statusLabel,
            color: inv.statusLabel == "Active" ? Brand.paidGreen : Brand.inkSoft)
          if inv.statusLabel == "Active" {
            Button("Revoke") { Task { await revoke(inv) } }
              .font(.caption.weight(.semibold))
              .foregroundStyle(Brand.red)
              .buttonStyle(.plain)
          }
        }
        .padding(.vertical, 4)
      }
    }
    .mpgCard()
  }

  // MARK: - Actions

  private func load() async {
    guard let token else { return }
    requests = (try? await RoleService.pendingRequests(token: token)) ?? []
    invites = (try? await RoleService.invites(token: token)) ?? []
  }

  private func generate() async {
    guard let token else { return }
    working = true
    defer { working = false }
    do {
      generated = try await RoleService.createInvite(
        role: newRole, expiresInDays: expiryDays, token: token)
      errorText = nil
      await load()
    } catch let e as SupabaseError {
      errorText = e.errorDescription
    } catch {
      errorText = error.localizedDescription
    }
  }

  private func decide(_ r: RoleRequest, approve: Bool) async {
    guard let token else { return }
    do {
      try await RoleService.decide(requestId: r.id, approve: approve, token: token)
      errorText = nil
      await load()
    } catch let e as SupabaseError {
      errorText = e.errorDescription
    } catch {
      errorText = error.localizedDescription
    }
  }

  private func revoke(_ inv: RoleInvite) async {
    guard let token else { return }
    try? await RoleService.revokeInvite(id: inv.id, token: token)
    await load()
  }
}
