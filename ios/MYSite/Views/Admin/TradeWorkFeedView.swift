import SwiftUI

/// Admin view: pick a trade and see every tradesman's work for that trade in
/// one combined, newest-first timeline (records, allocations and photos).
struct TradeWorkFeedView: View {
  @Environment(AppStore.self) private var store
  @State private var selectedTrade: String?

  private var trades: [String] { store.distinctTrades() }

  private var items: [TradeWorkItem] {
    guard let selectedTrade else { return [] }
    return store.workTimeline(forTrade: selectedTrade)
  }

  var body: some View {
    NavigationStack {
      ZStack {
        MPGBackground()
        Group {
          if trades.isEmpty {
            EmptyStateView(
              symbol: "hammer",
              title: "No trades yet",
              message: "Trades appear here once staff profiles and work allocations exist."
            )
            .mpgCard()
            .padding(16)
          } else {
            ScrollView {
              LazyVStack(spacing: 14) {
                tradePicker
                  .padding(.top, 4)

                if let selectedTrade {
                  crew(for: selectedTrade)
                  if items.isEmpty {
                    EmptyStateView(
                      symbol: "tray",
                      title: "No work logged",
                      message: "No records, allocations or photos for \(selectedTrade) yet."
                    )
                    .mpgCard()
                    .padding(.horizontal, 14)
                  } else {
                    ForEach(items) { item in
                      TradeWorkRow(item: item)
                        .padding(.horizontal, 14)
                    }
                  }
                } else {
                  EmptyStateView(
                    symbol: "hand.point.up.left",
                    title: "Choose a trade",
                    message: "Select a trade above to see all of its work in one feed."
                  )
                  .mpgCard()
                  .padding(.horizontal, 14)
                }
              }
              .padding(.vertical, 12)
            }
          }
        }
      }
      .navigationTitle("Work by Trade")
      .onAppear {
        if selectedTrade == nil { selectedTrade = trades.first }
      }
    }
    .__tenxTrackView("TradeWorkFeedView")
  }

  private var tradePicker: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        ForEach(trades, id: \.self) { trade in
          FilterChip(title: trade, selected: selectedTrade == trade) {
            withAnimation(.snappy) { selectedTrade = trade }
          }
        }
      }
      // Inset lives inside the scroll view so the selected chip's shadow
      // isn't clipped at the leading and trailing edges.
      .padding(.horizontal, 14)
      .padding(.vertical, 4)
    }
  }

  private func crew(for trade: String) -> some View {
    let people = store.tradesmen(inTrade: trade)
    return Group {
      if !people.isEmpty {
        VStack(alignment: .leading, spacing: 10) {
          SectionHeader(title: "\(trade) crew", subtitle: "\(people.count) on this trade")
          ForEach(people) { u in
            HStack(spacing: 12) {
              ZStack {
                Circle().fill(Brand.lightGreen)
                Image(systemName: "hammer.fill").foregroundStyle(Brand.oliveDark)
              }
              .frame(width: 36, height: 36)
              Text(u.name).font(.subheadline.weight(.semibold)).foregroundStyle(Brand.ink)
              Spacer()
              Text(
                "\(store.workTimeline(forTrade: trade).filter { $0.userName == u.name }.count) items"
              )
              .font(.caption).monospacedDigit().foregroundStyle(Brand.inkSoft)
            }
          }
        }
        .mpgCard()
        .padding(.horizontal, 14)
      }
    }
  }
}

private struct TradeWorkRow: View {
  let item: TradeWorkItem

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Image(systemName: item.kind.symbol)
          .font(.footnote.weight(.semibold))
          .foregroundStyle(Brand.oliveDark)
          .frame(width: 32, height: 32)
          .background(
            Brand.lightGreen, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        VStack(alignment: .leading, spacing: 1) {
          Text(item.userName).font(.subheadline.weight(.semibold)).foregroundStyle(Brand.ink)
          Label(item.siteName, systemImage: "mappin.and.ellipse")
            .font(.caption).foregroundStyle(Brand.inkSoft)
        }
        Spacer()
        StatusChip(text: item.kind.rawValue, color: Brand.blue)
      }
      Text(item.title)
        .font(.subheadline).foregroundStyle(Brand.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
      HStack {
        Text(item.subtitle).font(.caption).foregroundStyle(Brand.inkSoft)
        Spacer(minLength: 10)
        Text(item.date.relativeShort.uppercased())
          .font(.caption2.weight(.medium))
          .tracking(0.5)
          .foregroundStyle(Brand.inkSoft.opacity(0.8))
          .layoutPriority(1)
      }
      .padding(.top, 2)
    }
    .mpgCard()
  }
}

#Preview {
  TradeWorkFeedView().environment(
    {
      let s = AppStore()
      s.login(as: s.users.first { $0.role == .admin }!)
      return s
    }())
}
