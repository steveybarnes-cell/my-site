import SwiftUI

/// Admin control centre: add & edit jobs/sites, team members and work allocations.
struct ManageView: View {
  @Environment(AppStore.self) private var store

  enum Segment: String, CaseIterable, Identifiable {
    case sites = "Sites"
    case team = "Team"
    case allocations = "Work"
    var id: String { rawValue }
    var symbol: String {
      switch self {
      case .sites: return "mappin.and.ellipse"
      case .team: return "person.2.fill"
      case .allocations: return "hammer.fill"
      }
    }
  }

  @State private var segment: Segment = .sites
  @State private var editingSite: Site?
  @State private var editingUser: AppUser?
  @State private var editingAllocation: WorkAllocation?
  @State private var newSite = false
  @State private var newUser = false
  @State private var newAllocation = false

  var body: some View {
    Group {
      NavigationStack {
        ZStack {
          MPGBackground()
          ScrollView {
            VStack(spacing: 16) {
              picker
              switch segment {
              case .sites: sitesList
              case .team: teamList
              case .allocations: allocationsList
              }
            }
            .padding(16)
          }
        }
        .navigationTitle("Manage")
        .toolbar {
          ToolbarItem(placement: .primaryAction) {
            Button {
              switch segment {
              case .sites: newSite = true
              case .team: newUser = true
              case .allocations: newAllocation = true
              }
            } label: {
              Image(systemName: "plus")
            }
          }
        }
        .sheet(isPresented: $newSite) { SiteFormView(site: nil) }
        .sheet(item: $editingSite) { SiteFormView(site: $0) }
        .sheet(isPresented: $newUser) { StaffFormView(user: nil) }
        .sheet(item: $editingUser) { StaffFormView(user: $0) }
        .sheet(isPresented: $newAllocation) { AllocationFormView(allocation: nil) }
        .sheet(item: $editingAllocation) { AllocationFormView(allocation: $0) }
      }
    }
    .__tenxTrackView("ManageView")
  }

  private var picker: some View {
    Picker("Section", selection: $segment) {
      ForEach(Segment.allCases) { seg in
        Label(seg.rawValue, systemImage: seg.symbol).tag(seg)
      }
    }
    .pickerStyle(.segmented)
  }

  // MARK: - Sites

  private var sitesList: some View {
    VStack(spacing: 12) {
      if store.sites.isEmpty {
        EmptyStateView(
          symbol: "mappin.slash", title: "No sites yet",
          message: "Add your first job/site to start allocating work.",
          actionTitle: "Add Site"
        ) { newSite = true }
        .mpgCard()
      }
      ForEach(store.sites) { site in
        Button {
          editingSite = site
        } label: {
          siteRow(site)
        }
        .buttonStyle(.plain)
      }
    }
  }

  private func siteRow(_ site: Site) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text(site.name).font(.headline).foregroundStyle(Brand.ink)
        Spacer()
        StatusChip(
          text: site.status.rawValue,
          color: site.status == .active ? Brand.paidGreen : Brand.amber)
      }
      Text(site.address).font(.caption).foregroundStyle(Brand.inkSoft)
      HStack(spacing: 12) {
        if !site.client.isEmpty {
          Label(site.client, systemImage: "building.2").font(.caption2).foregroundStyle(
            Brand.inkSoft)
        }
        if let sm = site.siteManagerId.flatMap(store.user) {
          Label(sm.name, systemImage: "person.bust").font(.caption2).foregroundStyle(Brand.inkSoft)
        }
      }
      HStack {
        Spacer()
        Label("Edit", systemImage: "pencil").font(.caption.weight(.semibold)).foregroundStyle(
          Brand.olive)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .mpgCard(padding: 12)
  }

  // MARK: - Team

  private var teamList: some View {
    VStack(spacing: 12) {
      PeopleAdminSection()
      let team = store.users.filter { $0.role != .admin }
      if team.isEmpty {
        EmptyStateView(
          symbol: "person.crop.circle.badge.plus", title: "No team members",
          message: "Add tradesmen and site managers here.",
          actionTitle: "Add Member"
        ) { newUser = true }
        .mpgCard()
      }
      ForEach(team) { u in
        Button {
          editingUser = u
        } label: {
          staffRow(u)
        }
        .buttonStyle(.plain)
      }
    }
  }

  private func staffRow(_ u: AppUser) -> some View {
    HStack(spacing: 12) {
      Image(systemName: u.role.icon).foregroundStyle(Brand.olive)
        .frame(width: 34, height: 34).background(Brand.lightGreen, in: Circle())
      VStack(alignment: .leading, spacing: 2) {
        Text(u.name).font(.subheadline.weight(.semibold)).foregroundStyle(Brand.ink)
        Text(u.role.rawValue).font(.caption).foregroundStyle(Brand.inkSoft)
        if !u.phone.isEmpty {
          Text(u.phone).font(.caption2).foregroundStyle(Brand.inkSoft)
        }
      }
      Spacer()
      if !u.active {
        StatusChip(text: "Inactive", color: Brand.inkSoft)
      }
      Image(systemName: "pencil").font(.footnote).foregroundStyle(Brand.olive)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .mpgCard(padding: 12)
  }

  // MARK: - Allocations

  private var allocationsList: some View {
    VStack(spacing: 12) {
      let allocs = store.allocations.sorted { $0.date > $1.date }
      if allocs.isEmpty {
        EmptyStateView(
          symbol: "hammer", title: "No work allocated",
          message: "Allocate jobs to your tradesmen for the days ahead.",
          actionTitle: "Allocate Work"
        ) { newAllocation = true }
        .mpgCard()
      }
      ForEach(allocs) { a in
        Button {
          editingAllocation = a
        } label: {
          allocationRow(a)
        }
        .buttonStyle(.plain)
      }
    }
  }

  private func allocationRow(_ a: WorkAllocation) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text(store.site(a.siteId)?.name ?? "Site").font(.subheadline.weight(.semibold))
          .foregroundStyle(Brand.ink)
        Spacer()
        StatusChip(text: a.status.rawValue, color: a.status.color)
      }
      Text(a.taskDescription).font(.caption).foregroundStyle(Brand.inkSoft).lineLimit(2)
      HStack(spacing: 12) {
        Label(store.user(a.tradesmanId)?.name ?? "Unassigned", systemImage: "hammer.fill")
          .font(.caption2).foregroundStyle(Brand.inkSoft)
        Label(Fmt.date(a.date), systemImage: "calendar").font(.caption2).foregroundStyle(
          Brand.inkSoft)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .mpgCard(padding: 12)
  }
}

#Preview {
  ManageView().environment(
    {
      let s = AppStore()
      s.login(as: s.users.first { $0.role == .admin }!)
      return s
    }())
}

// =====================================================================
// MARK: - People administration
// =====================================================================

/// Pending signups and role changes, shown at the top of Manage → Team.
///
/// This screen exists because per-company isolation made new signups invisible.
/// Their profile row has no company, every policy scopes rows to a company, and
/// the two never meet — so an admin couldn't see a new starter at all, and an
/// attempt to promote one silently updated nothing. Until now the only way in
/// was a hand-written SQL statement.
///
/// Both actions go through Postgres functions rather than table writes, so a
/// refusal comes back as a real message ("That user already belongs to another
/// company") instead of a successful no-op.
struct PeopleAdminSection: View {
  @Environment(AppStore.self) private var store
  @Environment(AuthManager.self) private var auth: AuthManager?

  @State private var pending: [PendingSignup] = []
  @State private var members: [CompanyMember] = []
  @State private var chosenRole: [UUID: UserRole] = [:]
  @State private var busyUser: UUID?
  @State private var errorMessage: String?
  @State private var notice: String?
  @State private var hasLoaded = false

  private var isAdmin: Bool { store.currentUser?.role == .admin }
  private var token: String? { auth?.session?.accessToken }

  var body: some View {
    VStack(spacing: 12) {
      if isAdmin && token != nil {
        if !pending.isEmpty { pendingCard }
        if hasLoaded && members.count > 1 { rolesCard }
        if let errorMessage {
          banner(errorMessage, symbol: "exclamationmark.triangle.fill", color: Brand.red)
        }
        if let notice {
          banner(notice, symbol: "checkmark.circle.fill", color: Brand.paidGreen)
        }
      }
    }
    .task { await reload() }
  }

  // MARK: - Waiting to join

  private var pendingCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(
        title: "Waiting to join",
        subtitle: "New accounts see nothing until you add them to the company")

      ForEach(pending) { signup in
        VStack(alignment: .leading, spacing: 10) {
          VStack(alignment: .leading, spacing: 2) {
            Text(signup.displayName)
              .font(.subheadline.weight(.semibold)).foregroundStyle(Brand.ink)
            if let email = signup.email, email != signup.displayName {
              Text(email).font(.caption).foregroundStyle(Brand.inkSoft)
            }
            if let created = signup.createdAt {
              Text("Signed up \(Fmt.date(created))")
                .font(.caption2).foregroundStyle(Brand.inkSoft)
            }
          }

          Picker("Role", selection: roleBinding(for: signup.id)) {
            ForEach(UserRole.allCases) { Text($0.rawValue).tag($0) }
          }
          .pickerStyle(.segmented)
          .disabled(busyUser != nil)

          Button {
            Task { await adopt(signup) }
          } label: {
            Label(
              busyUser == signup.id ? "Adding…" : "Add to company",
              systemImage: busyUser == signup.id ? "hourglass" : "person.badge.plus"
            )
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Brand.olive, in: Capsule())
            .foregroundStyle(.white)
          }
          .buttonStyle(.plain)
          .disabled(busyUser != nil)
          .opacity(busyUser != nil ? 0.6 : 1)
        }
        .padding(12)
        .background(
          RoundedRectangle(cornerRadius: Brand.Radius.inner, style: .continuous)
            .fill(Brand.lightGreen.opacity(0.45)))
      }
    }
    .mpgCard()
  }

  // MARK: - Roles

  private var rolesCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Roles", subtitle: "Change what someone can see and do")

      ForEach(members) { member in
        HStack(spacing: 12) {
          Image(systemName: member.role.icon)
            .foregroundStyle(Brand.olive)
            .frame(width: 34, height: 34)
            .background(Brand.lightGreen, in: Circle())

          VStack(alignment: .leading, spacing: 2) {
            Text(member.displayName)
              .font(.subheadline.weight(.semibold)).foregroundStyle(Brand.ink)
            if let email = member.email, email != member.displayName {
              Text(email).font(.caption2).foregroundStyle(Brand.inkSoft)
            }
          }

          Spacer()

          if busyUser == member.id {
            ProgressView().controlSize(.small)
          } else if member.id == store.currentUser?.id {
            // The server refuses to let you drop your own admin access; saying
            // so here is friendlier than letting them find out by being told no.
            StatusChip(text: member.role.rawValue, color: Brand.inkSoft)
          } else {
            Menu {
              ForEach(UserRole.allCases) { role in
                Button {
                  Task { await changeRole(member, to: role) }
                } label: {
                  if role == member.role {
                    Label(role.rawValue, systemImage: "checkmark")
                  } else {
                    Text(role.rawValue)
                  }
                }
              }
            } label: {
              HStack(spacing: 4) {
                Text(member.role.rawValue).font(.caption.weight(.semibold))
                Image(systemName: "chevron.up.chevron.down").font(.caption2)
              }
              .foregroundStyle(Brand.olive)
              .padding(.vertical, 6).padding(.horizontal, 10)
              .background(Brand.lightGreen, in: Capsule())
            }
            .disabled(busyUser != nil)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .mpgCard()
  }

  private func banner(_ text: String, symbol: String, color: Color) -> some View {
    Label(text, systemImage: symbol)
      .font(.caption)
      .foregroundStyle(color)
      .frame(maxWidth: .infinity, alignment: .leading)
      .mpgCard(padding: 12)
  }

  // MARK: - Actions

  private func roleBinding(for id: UUID) -> Binding<UserRole> {
    Binding(
      get: { chosenRole[id] ?? .tradesman },
      set: { chosenRole[id] = $0 })
  }

  private func reload() async {
    guard isAdmin, let token else { return }
    pending = (try? await OnboardingService.pendingSignups(token: token)) ?? []
    members = (try? await OnboardingService.members(token: token)) ?? []
    hasLoaded = true
  }

  private func adopt(_ signup: PendingSignup) async {
    guard let token else { return }
    busyUser = signup.id
    errorMessage = nil
    notice = nil
    do {
      let role = chosenRole[signup.id] ?? .tradesman
      try await OnboardingService.adopt(user: signup.id, role: role, token: token)
      notice = "\(signup.displayName) added as \(role.rawValue)."
      await reload()
    } catch {
      errorMessage = error.localizedDescription
    }
    busyUser = nil
  }

  private func changeRole(_ member: CompanyMember, to role: UserRole) async {
    guard let token, role != member.role else { return }
    busyUser = member.id
    errorMessage = nil
    notice = nil
    do {
      try await OnboardingService.setRole(user: member.id, role: role, token: token)
      notice = "\(member.displayName) is now \(role.rawValue)."
      await reload()
    } catch {
      errorMessage = error.localizedDescription
    }
    busyUser = nil
  }
}
