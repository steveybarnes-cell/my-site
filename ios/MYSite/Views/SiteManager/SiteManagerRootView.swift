import SwiftUI

struct SiteManagerRootView: View {
  @Environment(AppStore.self) private var store

  var body: some View {
    Group {
      TabView {
        Tab("Team", systemImage: "bubble.left.and.bubble.right.fill") {
          CompanyFeedView()
        }
        Tab("My Sites", systemImage: "mappin.and.ellipse") {
          SiteManagerSitesView()
        }
        Tab("Records", systemImage: "list.clipboard.fill") {
          SiteManagerRecordsView()
        }
        .badge(store.invoiceActionCount)
        Tab("Alerts", systemImage: "bell.fill") {
          NotificationsView()
        }
        .badge(store.unreadCount)
        Tab("More", systemImage: "ellipsis.circle.fill") {
          SiteManagerMoreView()
        }
      }
    }
    .__tenxTrackView("SiteManagerRootView")
  }
}

struct SiteManagerSitesView: View {
  @Environment(AppStore.self) private var store
  private var mySites: [Site] {
    store.currentUser.map { store.sitesManaged(by: $0.id) } ?? []
  }

  var body: some View {
    NavigationStack {
      ZStack {
        MPGBackground()
        ScrollView {
          VStack(spacing: 16) {
            if mySites.isEmpty {
              EmptyStateView(
                symbol: "mappin.slash", title: "No sites assigned",
                message: "Sites you manage will appear here."
              ).mpgCard()
            } else {
              ForEach(mySites) { site in
                siteCard(site)
              }
            }
          }
          .padding(16)
        }
      }
      .navigationTitle("My Sites")
    }
  }

  private func siteCard(_ site: Site) -> some View {
    let allocs = store.allocations.filter { $0.siteId == site.id }
    return VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text(site.name).font(.headline).foregroundStyle(Brand.ink)
        Spacer()
        StatusChip(
          text: site.status.rawValue,
          color: site.status == .active ? Brand.paidGreen : Brand.amber)
      }
      Text(site.address).font(.caption).foregroundStyle(Brand.inkSoft)
      if !site.notes.isEmpty {
        Text(site.notes).font(.footnote).foregroundStyle(Brand.ink)
          .frame(maxWidth: .infinity, alignment: .leading)
          .mpgFormSection(padding: 10)
      }
      Divider().overlay(Brand.hairline)
      Text("\(allocs.count) allocation(s)").font(.caption.weight(.semibold)).foregroundStyle(
        Brand.olive)
      ForEach(allocs) { a in
        HStack(spacing: 10) {
          Image(systemName: "hammer.fill").font(.caption).foregroundStyle(Brand.olive)
          VStack(alignment: .leading, spacing: 1) {
            Text(store.user(a.tradesmanId)?.name ?? "").font(.subheadline.weight(.medium))
              .foregroundStyle(Brand.ink)
            Text(a.taskDescription).font(.caption).foregroundStyle(Brand.inkSoft).lineLimit(1)
          }
          Spacer()
          StatusChip(text: a.status.rawValue, color: a.status.color)
        }
      }
    }
    .mpgCard()
  }
}

struct SiteManagerRecordsView: View {
  @Environment(AppStore.self) private var store

  private var siteRecords: [DailyRecord] {
    guard let me = store.currentUser else { return [] }
    let siteIds = Set(store.sitesManaged(by: me.id).map { $0.id })
    return store.dailyRecords.filter { siteIds.contains($0.siteId) }.sorted { $0.date > $1.date }
  }

  var body: some View {
    NavigationStack {
      ZStack {
        MPGBackground()
        ScrollView {
          VStack(spacing: 12) {
            if siteRecords.isEmpty {
              EmptyStateView(
                symbol: "list.clipboard", title: "No records",
                message: "Daily records for your sites will appear here for review."
              ).mpgCard()
            } else {
              ForEach(siteRecords) { r in
                VStack(alignment: .leading, spacing: 8) {
                  HStack {
                    Text(store.user(r.userId)?.name ?? "").font(.headline).foregroundStyle(
                      Brand.ink)
                    Spacer()
                    StatusChip(text: r.category.rawValue, color: Brand.olive)
                  }
                  Text(store.site(r.siteId)?.name ?? "").font(.caption).foregroundStyle(
                    Brand.inkSoft)
                  Text(r.description).font(.subheadline).foregroundStyle(Brand.inkSoft).lineLimit(3)
                  HStack(spacing: 14) {
                    Label(Fmt.hours(r.totalHours), systemImage: "hourglass")
                    Label(Fmt.date(r.date), systemImage: "calendar")
                    if r.delayReason != .none {
                      Label(r.delayReason.rawValue, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(Brand.amber)
                    }
                  }
                  .font(.caption).foregroundStyle(Brand.inkSoft)
                }
                .mpgCard()
              }
            }
          }
          .padding(16)
        }
      }
      .navigationTitle("Site Records")
    }
  }
}

// MARK: - More hub

struct SiteManagerMoreView: View {
  var body: some View {
    MoreHubView(
      roleTitle: "Site Manager",
      roleSymbol: "person.bust",
      items: [
        MoreHubItem(
          title: "Dashboard",
          subtitle: "Site metrics & overview",
          symbol: "square.grid.2x2.fill"
        ) { DashboardView() },
        MoreHubItem(
          title: "Attendance",
          subtitle: "Clock-ins, geofence & approvals",
          symbol: "location.fill.viewfinder",
          tint: Brand.blue
        ) { AttendanceView() },
        MoreHubItem(
          title: "Files",
          subtitle: "Site file hub & registers",
          symbol: "folder.fill"
        ) { FilesView() },
        MoreHubItem(
          title: "Profile",
          subtitle: "Contact details & log out",
          symbol: "person.crop.circle.fill",
          tint: Brand.charcoal
        ) { SiteManagerProfileView() },
      ]
    )
  }
}

struct SiteManagerProfileView: View {
  @Environment(AppStore.self) private var store

  var body: some View {
    NavigationStack {
      ZStack {
        MPGBackground()
        ScrollView {
          VStack(spacing: 16) {
            VStack(spacing: 8) {
              Image(systemName: "person.bust").font(.system(size: 40)).foregroundStyle(.white)
              Text(store.currentUser?.name ?? "").font(.title3.bold()).foregroundStyle(.white)
              Text("Site Manager").font(.subheadline).foregroundStyle(.white.opacity(0.75))
            }
            .frame(maxWidth: .infinity).padding(22)
            .background(Brand.charcoal, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 12) {
              SectionHeader(title: "Contact")
              InfoRow(label: "Email", value: store.currentUser?.email ?? "", symbol: "envelope")
              InfoRow(label: "Phone", value: store.currentUser?.phone ?? "", symbol: "phone")
            }
            .mpgCard()

            PrimaryButton(
              title: "Log Out", symbol: "rectangle.portrait.and.arrow.right", tint: Brand.charcoal
            ) {
              store.logout()
            }
          }
          .padding(16)
        }
      }
      .navigationTitle("Profile")
    }
  }
}

#Preview {
  SiteManagerRootView().environment(
    {
      let s = AppStore()
      s.login(as: s.siteManagers().first!)
      return s
    }())
}
