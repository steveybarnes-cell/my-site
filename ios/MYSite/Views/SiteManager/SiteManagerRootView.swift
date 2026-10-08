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
        Tab("Today", systemImage: "sun.max.fill") {
          TodayView()
        }
        Tab("Records", systemImage: "list.clipboard.fill") {
          SiteManagerRecordsView()
        }
        .badge(store.invoiceActionCount)
        Tab("More", systemImage: "ellipsis.circle.fill") {
          SiteManagerMoreView()
        }
        // iPad only: the sidebar carries the whole office. On the phone these
        // stay behind More.
        TabSection("Sites") {
          Tab("Site Board", systemImage: "rectangle.3.group.fill") { SiteBoardView() }
          Tab("Alerts", systemImage: "bell.fill") { NotificationsView() }
            .badge(store.unreadCount)
          Tab("Dashboard", systemImage: "square.grid.2x2.fill") { DashboardView() }
          Tab("Attendance", systemImage: "person.badge.clock.fill") { AttendanceView() }
          Tab("Files", systemImage: "folder.fill") { FilesView() }
        }
        .defaultVisibility(.hidden, for: .tabBar)
        TabSection("Tools") {
          Tab("Scan Receipt", systemImage: "doc.text.viewfinder") {
            ScanReceiptView(presentedModally: false)
          }
          Tab("Profile", systemImage: "person.crop.circle.fill") { SiteManagerProfileView() }
        }
        .defaultVisibility(.hidden, for: .tabBar)
      }
      .tabViewStyle(.sidebarAdaptable)
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
            ScanReceiptCard()
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
  @Environment(AppStore.self) private var store

  var body: some View {
    MoreHubView(
      roleTitle: "Site Manager",
      roleSymbol: "person.bust",
      items: [
        MoreHubItem(
          title: "Alerts",
          subtitle: "Notifications and things needing a look",
          symbol: "bell.fill",
          tint: Brand.amber,
          badge: store.unreadCount
        ) { NotificationsView() },
        MoreHubItem(
          title: "Scan Invoice / Receipt",
          subtitle: "Photograph it — details read for you",
          symbol: "doc.text.viewfinder",
          tint: Brand.blue
        ) { ScanReceiptView(presentedModally: false) },
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
  @Environment(AuthManager.self) private var auth

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
              // Revokes the token and returns to LoginView. store.logout()
              // alone leaves auth.phase == .signedIn, which drops the user
              // into the tradesman app instead of signing them out.
              Task { await auth.signOut() }
            }
            DeleteAccountSection()
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

// MARK: - Site Board (iPad)

/// Every live site on one screen: who is on it right now, what is being done,
/// how far along it is, and what evidence came in today.
///
/// Only offered from the iPad sidebar. On a phone the same information is a
/// screen per site and that is right for a phone; a board needs the width.
/// Reads straight from the store, so it moves as the crew clock on and move
/// jobs along — a wall screen in the office, not a report.
struct SiteBoardView: View {
  @Environment(AppStore.self) private var store

  private var sites: [Site] {
    guard let me = store.currentUser else { return [] }
    let mine = me.role == .admin ? store.sites : store.sitesManaged(by: me.id)
    return mine.filter { $0.status == .active }.sorted { $0.name < $1.name }
  }

  private let columns = [
    GridItem(.adaptive(minimum: 340, maximum: 520), spacing: 16, alignment: .top)
  ]

  var body: some View {
    NavigationStack {
      ZStack {
        MPGBackground()
        ScrollView {
          VStack(alignment: .leading, spacing: 16) {
            headline
            if sites.isEmpty {
              EmptyStateView(
                symbol: "mappin.slash", title: "No active sites",
                message: "Sites you manage show up here as soon as they're set to Active."
              ).mpgCard()
            } else {
              LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                ForEach(sites) { site in
                  SiteBoardCard(site: site)
                }
              }
            }
          }
          .padding(16)
        }
      }
      .navigationTitle("Site Board")
      .navigationDestination(for: WorkAllocation.self) { AllocationDetailView(allocation: $0) }
    }
  }

  private var headline: some View {
    let onSite = store.clockRecords.filter {
      $0.isOpen && Calendar.current.isDateInToday($0.date)
    }.count
    let jobs = store.allocations.filter {
      Calendar.current.isDateInToday($0.date) && $0.status != .cancelled
    }
    let done = jobs.filter { $0.status == .completed }.count
    return HStack(spacing: 12) {
      boardStat("\(onSite)", "on site now", "person.2.fill")
      boardStat("\(jobs.count)", "jobs today", "hammer.fill")
      boardStat("\(done)", "finished", "checkmark.circle.fill")
      Spacer()
      Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide)))
        .font(.subheadline).foregroundStyle(Brand.inkSoft)
    }
    .mpgCard()
  }

  private func boardStat(_ value: String, _ label: String, _ symbol: String) -> some View {
    HStack(spacing: 8) {
      Image(systemName: symbol).foregroundStyle(Brand.olive)
      VStack(alignment: .leading, spacing: 0) {
        Text(value).font(.title3.bold()).monospacedDigit().foregroundStyle(Brand.ink)
        Text(label).font(.caption).foregroundStyle(Brand.inkSoft)
      }
    }
    .padding(.trailing, 8)
  }
}

private struct SiteBoardCard: View {
  @Environment(AppStore.self) private var store
  let site: Site

  private var onSiteNow: [ClockRecord] {
    store.clockRecords.filter {
      $0.siteId == site.id && $0.isOpen && Calendar.current.isDateInToday($0.date)
    }
  }

  private var todaysJobs: [WorkAllocation] {
    store.allocations
      .filter {
        $0.siteId == site.id && Calendar.current.isDateInToday($0.date) && $0.status != .cancelled
      }
      .sorted { $0.startTime < $1.startTime }
  }

  private var photosToday: Int {
    store.photos.filter { $0.siteId == site.id && Calendar.current.isDateInToday($0.timestamp) }
      .count
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 2) {
          Text(site.name).font(.headline).foregroundStyle(Brand.ink)
          Text(site.client.isEmpty ? site.address : site.client)
            .font(.caption).foregroundStyle(Brand.inkSoft).lineLimit(1)
        }
        Spacer()
        StatusChip(
          text: onSiteNow.isEmpty ? "Nobody on site" : "\(onSiteNow.count) on site",
          color: onSiteNow.isEmpty ? Brand.inkSoft : Brand.olive,
          filled: !onSiteNow.isEmpty)
      }

      if !onSiteNow.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
          ForEach(onSiteNow) { c in
            Label(
              "\(c.tradesmanName) · since \(Fmt.time(c.clockInTime))",
              systemImage: "clock.fill"
            )
            .font(.caption).foregroundStyle(Brand.ink)
          }
        }
      }

      Divider().overlay(Brand.hairline)

      if todaysJobs.isEmpty {
        Text("No jobs allocated today.")
          .font(.footnote).foregroundStyle(Brand.inkSoft)
      } else {
        VStack(spacing: 8) {
          ForEach(todaysJobs) { job in
            NavigationLink(value: job) {
              HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                  Text(job.taskDescription)
                    .font(.footnote.weight(.medium)).foregroundStyle(Brand.ink)
                    .lineLimit(2).multilineTextAlignment(.leading)
                  Text(
                    "\(store.user(job.tradesmanId)?.name ?? "Unassigned") · "
                      + "\(job.startTime)–\(job.expectedFinish)"
                  )
                  .font(.caption2).foregroundStyle(Brand.inkSoft)
                  ProgressView(value: Double(job.percentComplete), total: 100)
                    .tint(job.status == .completed ? Brand.paidGreen : Brand.olive)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 3) {
                  Text("\(job.percentComplete)%")
                    .font(.footnote.weight(.semibold)).monospacedDigit().foregroundStyle(Brand.ink)
                  StatusChip(text: job.status.rawValue, color: job.status.color)
                }
              }
              .padding(10)
              .background(
                Brand.lightGreen, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
          }
        }
      }

      HStack(spacing: 14) {
        Label("\(photosToday) photo\(photosToday == 1 ? "" : "s") today", systemImage: "camera.fill")
        Label("\(site.defaultStart)–\(site.defaultFinish)", systemImage: "clock")
      }
      .font(.caption).foregroundStyle(Brand.inkSoft)
    }
    .mpgCard()
  }
}
