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
                  .padding(.horizontal, 14)
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
              .font(.caption).foregroundStyle(Brand.inkSoft)
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
          .foregroundStyle(Brand.olive)
          .frame(width: 30, height: 30)
          .background(Brand.lightGreen, in: RoundedRectangle(cornerRadius: 9))
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
        Spacer()
        Text(item.date.relativeShort.uppercased())
          .font(.caption2).foregroundStyle(Brand.inkSoft)
      }
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
