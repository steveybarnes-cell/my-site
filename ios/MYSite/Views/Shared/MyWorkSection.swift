import SwiftUI

/// The signed-in person's own allocated work, wherever they happen to be.
///
/// In a firm of this size the boss is usually also on the tools. The app used
/// to force a choice: be an Admin and lose your own job list, or be a Tradesman
/// and lose the office screens. The workaround was demoting yourself in SQL to
/// tick a job off from site, which is not a workaround so much as an admission.
///
/// So this is the tradesman's Today list, extracted, and dropped onto the admin
/// and site-manager dashboards. It appears only when there is work allocated —
/// an office-only admin never sees it and nothing changes for them.
struct MyWorkSection: View {
  @Environment(AppStore.self) private var store

  private var mine: [WorkAllocation] {
    guard let me = store.currentUser else { return [] }
    return store.todaysAllocations(for: me.id)
  }

  var body: some View {
    if !mine.isEmpty {
      VStack(alignment: .leading, spacing: 10) {
        SectionHeader(
          title: "My work",
          subtitle: mine.count == 1
            ? "One job allocated to you" : "\(mine.count) jobs allocated to you")
        ForEach(mine) { alloc in
          NavigationLink(value: alloc) {
            MyWorkRow(allocation: alloc)
          }
          .buttonStyle(.plain)
        }
      }
    }
  }
}

/// Deliberately not `AllocationCard`. That card is built for the tradesman's
/// full-width Today screen; here it sits among office metrics, so it stays
/// compact and leads with progress — the thing you came to change.
private struct MyWorkRow: View {
  @Environment(AppStore.self) private var store
  let allocation: WorkAllocation

  private var live: WorkAllocation {
    store.allocations.first { $0.id == allocation.id } ?? allocation
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 9) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 3) {
          Text(live.taskDescription.isEmpty ? "Work" : live.taskDescription)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Brand.ink)
            .multilineTextAlignment(.leading)
          Text(
            "\(store.site(live.siteId)?.name ?? "Site") · \(Fmt.date(live.date))"
          )
          .font(.caption)
          .foregroundStyle(Brand.inkSoft)
        }
        Spacer(minLength: 8)
        Text("\(live.percentComplete)%")
          .font(.subheadline.bold())
          .monospacedDigit()
          .foregroundStyle(live.percentComplete >= 100 ? Brand.oliveDark : Brand.ink)
      }
      GeometryReader { geo in
        ZStack(alignment: .leading) {
          Capsule().fill(Brand.lightGreen)
          Capsule().fill(Brand.olive)
            .frame(width: max(0, geo.size.width * CGFloat(live.percentComplete) / 100))
        }
      }
      .frame(height: 7)
    }
    .mpgCard()
  }
}
