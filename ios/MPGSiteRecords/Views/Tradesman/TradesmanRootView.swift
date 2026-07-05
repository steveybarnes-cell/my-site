import SwiftUI

struct TradesmanRootView: View {
  @Environment(AppStore.self) private var store

  var body: some View {
    Group {
      TabView {
        Tab("Today", systemImage: "sun.max.fill") {
          TradesmanTodayView()
        }
        Tab("Records", systemImage: "list.clipboard.fill") {
          TradesmanRecordsView()
        }
        Tab("Files", systemImage: "folder.fill") {
          FilesView()
        }
        Tab("Invoices", systemImage: "sterlingsign.circle.fill") {
          TradesmanSubmissionsView()
        }
        Tab("Alerts", systemImage: "bell.fill") {
          NotificationsView()
        }
        .badge(store.unreadCount)
        Tab("Profile", systemImage: "person.crop.circle.fill") {
          ProfileView()
        }
      }
    }
    .__tenxTrackView("TradesmanRootView")
  }
}

// MARK: - Today

struct TradesmanTodayView: View {
  @Environment(AppStore.self) private var store

  private var me: AppUser? { store.currentUser }

  var body: some View {
    NavigationStack {
      ZStack {
        MPGBackground()
        ScrollView {
          VStack(spacing: 16) {
            greeting
            let allocs = me.map { store.todaysAllocations(for: $0.id) } ?? []
            if allocs.isEmpty {
              EmptyStateView(
                symbol: "checkmark.circle", title: "No work scheduled",
                message: "You have no allocations for today or tomorrow. Enjoy the break."
              )
              .mpgCard()
            } else {
              ForEach(allocs) { alloc in
                NavigationLink(value: alloc) {
                  AllocationCard(allocation: alloc, showTradesman: false)
                }
                .buttonStyle(.plain)
              }
            }
          }
          .padding(16)
        }
      }
      .navigationTitle("Today's Work")
      .navigationDestination(for: WorkAllocation.self) { AllocationDetailView(allocation: $0) }
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          NavigationLink {
            NotificationsView()
          } label: {
            Image(systemName: "bell")
          }
        }
      }
    }
  }

  private var greeting: some View {
    let first = (me?.name.split(separator: " ").first).map(String.init) ?? "there"
    return VStack(alignment: .leading, spacing: 6) {
      Text("Good morning, \(first)")
        .font(.title2.bold())
        .foregroundStyle(.white)
      Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide)))
        .font(.subheadline)
        .foregroundStyle(.white.opacity(0.75))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(18)
    .background(Brand.charcoal, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
