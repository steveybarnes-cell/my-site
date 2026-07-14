import SwiftUI

/// AI-style weekly recap for the office. Picks a week and reads back a
/// plain-English summary of company spend, invoice pipeline and anything worth
/// chasing — all computed locally from the app's real data.
struct WeeklySpendSummaryView: View {
  @Environment(AppStore.self) private var store
  @State private var weekEnding: Date = FileStorage.weekEndingSunday(for: Date())

  private var weeks: [Date] { WeeklySpendSummarizer.availableWeeks(store: store) }

  private var summary: WeeklySpendSummary {
    WeeklySpendSummarizer.summary(for: weekEnding, store: store)
  }

  var body: some View {
    NavigationStack {
      ZStack {
        MPGBackground()
        ScrollView {
          VStack(spacing: 16) {
            weekPicker
            recapCard
            metrics
            if let site = summary.topSite, site.spend > 0 { breakdownCard }
            disclaimer
          }
          .padding(16)
        }
      }
      .navigationTitle("Weekly Recap")
      .navigationBarTitleDisplayMode(.inline)
      .onAppear {
        if let latest = weeks.first { weekEnding = latest }
      }
    }
    .__tenxTrackView("WeeklySpendSummaryView")
  }

  // MARK: - Week picker

  private var weekPicker: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        ForEach(weeks, id: \.self) { week in
          let selected = Calendar.current.isDate(week, inSameDayAs: weekEnding)
          Button {
            weekEnding = week
          } label: {
            Text("W/E \(Fmt.date(week))")
              .font(.caption.weight(.semibold))
              .padding(.vertical, 8).padding(.horizontal, 12)
              .background(
                selected ? Brand.olive : Brand.lightGreen.opacity(0.7),
                in: Capsule()
              )
              .foregroundStyle(selected ? .white : Brand.ink)
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 2)
    }
  }

  // MARK: - Narrative

  private var recapCard: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(spacing: 10) {
        ZStack {
          Circle().fill(toneColor.opacity(0.18)).frame(width: 40, height: 40)
          Image(systemName: "sparkles")
            .font(.headline).foregroundStyle(toneColor)
        }
        VStack(alignment: .leading, spacing: 1) {
          Text("Office recap").font(.subheadline.weight(.semibold)).foregroundStyle(Brand.ink)
          Text("Week ending \(Fmt.fullDate(summary.weekEnding))")
            .font(.caption).foregroundStyle(Brand.inkSoft)
        }
        Spacer()
      }

      VStack(alignment: .leading, spacing: 10) {
        ForEach(Array(summary.narrative.enumerated()), id: \.offset) { _, line in
          HStack(alignment: .top, spacing: 8) {
            Circle().fill(Brand.olive).frame(width: 5, height: 5).padding(.top, 7)
            Text(line)
              .font(.subheadline)
              .foregroundStyle(Brand.ink)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .mpgCard()
  }

  private var toneColor: Color {
    switch summary.tone {
    case .calm: return Brand.paidGreen
    case .watch: return Brand.amber
    case .alert: return Brand.red
    }
  }

  // MARK: - Metrics

  private var metrics: some View {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
      MetricTile(
        value: Fmt.gbp(summary.spend), label: "Total spend",
        symbol: "sterlingsign.circle")
      MetricTile(
        value: Fmt.hours(summary.totalHours), label: "Hours on site",
        symbol: "clock", tint: Brand.blue)
      MetricTile(
        value: Fmt.gbp(summary.netDue), label: "Net to pay",
        symbol: "banknote", tint: Brand.amber)
      MetricTile(
        value: "\(summary.pendingApproval)", label: "Awaiting approval",
        symbol: "tray.full",
        tint: summary.pendingApproval > 0 ? Brand.red : Brand.paidGreen)
    }
  }

  // MARK: - Site breakdown

  private var breakdownCard: some View {
    let rows = DashboardAnalytics(
      store: store,
      filter: {
        var f = DashboardFilter()
        f.weekEnding = summary.weekEnding
        return f
      }()
    ).siteCosts.filter { $0.total > 0 }.sorted { $0.total > $1.total }

    let maxSpend = rows.map { $0.total }.max() ?? 1

    return VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Where the money went")
      ForEach(rows) { row in
        VStack(alignment: .leading, spacing: 6) {
          HStack {
            Text(row.siteName).font(.subheadline.weight(.semibold)).foregroundStyle(Brand.ink)
            Spacer()
            Text(Fmt.gbp(row.total)).font(.subheadline.weight(.semibold))
              .foregroundStyle(Brand.olive)
          }
          GeometryReader { geo in
            ZStack(alignment: .leading) {
              Capsule().fill(Brand.lightGreen.opacity(0.6))
              Capsule().fill(Brand.olive)
                .frame(width: geo.size.width * CGFloat(row.total / maxSpend))
            }
          }
          .frame(height: 6)
          HStack(spacing: 10) {
            Text("Labour \(Fmt.gbp(row.labour))")
            Text("Materials \(Fmt.gbp(row.materials))")
            if row.missingReceipts > 0 {
              Label("\(row.missingReceipts)", systemImage: "doc.badge.ellipsis")
                .foregroundStyle(Brand.red)
            }
          }
          .font(.caption2).foregroundStyle(Brand.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .mpgFormSection(padding: 12)
      }
    }
    .mpgCard()
  }

  // MARK: - Disclaimer

  private var disclaimer: some View {
    Text(
      "Generated from your live site records, materials and invoices. Figures update as tradesmen submit — always confirm before paying."
    )
    .font(.caption2).foregroundStyle(Brand.inkSoft)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

#Preview {
  WeeklySpendSummaryView().environment(
    {
      let s = AppStore()
      s.login(as: s.users.first { $0.role == .admin }!)
      return s
    }())
}
