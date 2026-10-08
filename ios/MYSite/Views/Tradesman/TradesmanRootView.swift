import SwiftUI

struct TradesmanRootView: View {
  @Environment(AppStore.self) private var store

  var body: some View {
    Group {
      // Today sits in the middle on purpose. It is the screen a man on site
      // opens twenty times a day, and the middle of five is the one position
      // a thumb reaches without looking or shifting grip.
      TabView {
        Tab("Team", systemImage: "bubble.left.and.bubble.right.fill") {
          CompanyFeedView()
        }
        Tab("Files", systemImage: "folder.fill") {
          FilesView()
        }
        Tab("Today", systemImage: "sun.max.fill") {
          TodayView()
        }
        Tab("Alerts", systemImage: "bell.fill") {
          NotificationsView()
        }
        .badge(store.unreadCount)
        Tab("More", systemImage: "ellipsis.circle.fill") {
          TradesmanMoreView()
        }
        // On an iPad the More hub unfolds into the sidebar, so every tool is
        // one tap away. Hidden from the phone's tab bar, where More does the job.
        TabSection("Tools") {
          Tab("Scan Receipt", systemImage: "doc.text.viewfinder") {
            ScanReceiptView(presentedModally: false)
          }
          Tab("My Records", systemImage: "list.clipboard.fill") { TradesmanRecordsView() }
          Tab("Ask for Materials", systemImage: "cart.badge.plus") { MaterialRequestView() }
          Tab("Invoices & Timesheets", systemImage: "sterlingsign.circle.fill") {
            TradesmanSubmissionsView()
          }
          .badge(store.invoiceActionCount)
          Tab("Profile", systemImage: "person.crop.circle.fill") { ProfileView() }
        }
        .defaultVisibility(.hidden, for: .tabBar)
      }
      .tabViewStyle(.sidebarAdaptable)
    }
    .__tenxTrackView("TradesmanRootView")
  }
}

// MARK: - More hub

struct TradesmanMoreView: View {
  @Environment(AppStore.self) private var store

  var body: some View {
    MoreHubView(
      roleTitle: "Tradesman",
      roleSymbol: "hammer.fill",
      items: [
        MoreHubItem(
          title: "Scan Invoice / Receipt",
          subtitle: "Photograph it — details read for you",
          symbol: "doc.text.viewfinder",
          tint: Brand.blue
        ) { ScanReceiptView(presentedModally: false) },
        MoreHubItem(
          title: "My Records",
          subtitle: "Daily records, photos & materials",
          symbol: "list.clipboard.fill"
        ) { TradesmanRecordsView() },
        MoreHubItem(
          title: "Ask for Materials",
          subtitle: "Tell the office what you're short of",
          symbol: "cart.badge.plus",
          tint: Brand.amber
        ) { MaterialRequestView() },
        MoreHubItem(
          title: "Invoices & Timesheets",
          subtitle: "Submit and track weekly pay",
          symbol: "sterlingsign.circle.fill",
          tint: Brand.blue,
          badge: store.invoiceActionCount
        ) { TradesmanSubmissionsView() },
        MoreHubItem(
          title: "Profile",
          subtitle: "Account, contact & log out",
          symbol: "person.crop.circle.fill",
          tint: Brand.charcoal
        ) { ProfileView() },
      ]
    )
  }
}

// MARK: - Allocation card

struct AllocationCard: View {
  @Environment(AppStore.self) private var store
  let allocation: WorkAllocation
  var showTradesman: Bool = true

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        StatusChip(text: allocation.category.rawValue, color: Brand.olive)
        if allocation.priority == .urgent || allocation.priority == .high {
          StatusChip(
            text: allocation.priority.rawValue, color: allocation.priority.color, filled: true)
        }
        Spacer()
        StatusChip(text: allocation.status.rawValue, color: allocation.status.color)
      }
      VStack(alignment: .leading, spacing: 3) {
        Text(store.site(allocation.siteId)?.name ?? "Site")
          .font(.headline).foregroundStyle(Brand.ink)
        Text(store.site(allocation.siteId)?.address ?? "")
          .font(.caption).foregroundStyle(Brand.inkSoft)
      }
      Text(allocation.taskDescription)
        .font(.subheadline)
        .foregroundStyle(Brand.ink)
        .lineLimit(2)

      Divider().overlay(Brand.hairline)

      HStack(spacing: 14) {
        Label("\(allocation.startTime)–\(allocation.expectedFinish)", systemImage: "clock")
        Label(allocation.trade, systemImage: "hammer")
        if allocation.requiredPhotos {
          Label("Photos", systemImage: "camera").foregroundStyle(Brand.amber)
        }
      }
      .font(.caption)
      .foregroundStyle(Brand.inkSoft)

      if showTradesman, let t = store.user(allocation.tradesmanId) {
        Label(t.name, systemImage: "person").font(.caption).foregroundStyle(Brand.inkSoft)
      }
    }
    .mpgCard()
  }
}

#Preview {
  TradesmanRootView().environment(
    {
      let s = AppStore()
      s.login(as: s.tradesmen().first!)
      return s
    }())
}
