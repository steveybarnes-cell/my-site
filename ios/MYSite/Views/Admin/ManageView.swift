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
