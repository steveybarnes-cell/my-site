import Charts
import SwiftUI

/// Visual analytics for the Company Dashboard, built with Swift Charts from the
/// same `DashboardAnalytics` rollups the tables use. Admin + Site Manager only.
struct DashboardCharts: View {
  let analytics: DashboardAnalytics

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(
        title: "Insights", subtitle: "Live charts from this selection")

      siteCostChart
      weeklyValueChart
      allocationStatusChart
    }
    .mpgCard()
  }

  // MARK: - Site cost (stacked bar: labour vs materials)

  private struct SiteCostBar: Identifiable {
    let id = UUID()
    let site: String
    let kind: String
    let amount: Double
  }

  private var siteCostBars: [SiteCostBar] {
    analytics.siteCosts
      .filter { $0.total > 0 }
      .flatMap { row in
        [
          SiteCostBar(site: row.siteName, kind: "Labour", amount: row.labour),
          SiteCostBar(site: row.siteName, kind: "Materials", amount: row.materials),
        ]
      }
  }

  @ViewBuilder private var siteCostChart: some View {
    let bars = siteCostBars
    chartBlock(title: "Site cost breakdown", symbol: "chart.bar.fill") {
      if bars.isEmpty {
        emptyChart("No site costs for this selection")
      } else {
        Chart(bars) { bar in
          BarMark(
            x: .value("Cost", bar.amount),
            y: .value("Site", bar.site)
          )
          .foregroundStyle(by: .value("Type", bar.kind))
          .cornerRadius(4)
        }
        .chartForegroundStyleScale(["Labour": Brand.olive, "Materials": Brand.amber])
        .chartLegend(position: .bottom, spacing: 8)
        .chartXAxis {
          AxisMarks { value in
            AxisGridLine()
            AxisValueLabel {
              if let v = value.as(Double.self) { Text(shortGBP(v)) }
            }
          }
        }
        .frame(height: max(120, Double(analytics.siteCosts.filter { $0.total > 0 }.count) * 46))
      }
    }
  }

  // MARK: - Weekly net value trend (line)

  private struct WeekPoint: Identifiable {
    let id = UUID()
    let week: Date
    let net: Double
  }

  private var weekPoints: [WeekPoint] {
    let grouped = Dictionary(grouping: analytics.paymentRun) {
      FileStorage.weekEndingSunday(for: $0.weekEnding)
    }
    return grouped
      .map { WeekPoint(week: $0.key, net: $0.value.reduce(0) { $0 + $1.netDue }) }
      .sorted { $0.week < $1.week }
  }

  @ViewBuilder private var weeklyValueChart: some View {
    let points = weekPoints
    chartBlock(title: "Weekly net value", symbol: "chart.line.uptrend.xyaxis") {
      if points.count < 2 {
        emptyChart("Not enough weeks to plot a trend yet")
      } else {
        Chart(points) { p in
          AreaMark(
            x: .value("Week", p.week, unit: .weekOfYear),
            y: .value("Net", p.net)
          )
          .foregroundStyle(
            .linearGradient(
              colors: [Brand.olive.opacity(0.35), Brand.olive.opacity(0.02)],
              startPoint: .top, endPoint: .bottom)
          )
          .interpolationMethod(.catmullRom)
          LineMark(
            x: .value("Week", p.week, unit: .weekOfYear),
            y: .value("Net", p.net)
          )
          .foregroundStyle(Brand.oliveDark)
          .interpolationMethod(.catmullRom)
          PointMark(
            x: .value("Week", p.week, unit: .weekOfYear),
            y: .value("Net", p.net)
          )
          .foregroundStyle(Brand.oliveDark)
        }
        .chartYAxis {
          AxisMarks { value in
            AxisGridLine()
            AxisValueLabel {
              if let v = value.as(Double.self) { Text(shortGBP(v)) }
            }
          }
        }
        .frame(height: 180)
      }
    }
  }

  // MARK: - Allocation status (donut, iOS 17+)

  private struct StatusSlice: Identifiable {
    let id = UUID()
    let label: String
    let count: Int
    let color: Color
  }

  private var statusSlices: [StatusSlice] {
    let t = analytics.allocationTracker
    return [
      StatusSlice(label: "Allocated", count: t.allocated, color: Brand.blue),
      StatusSlice(label: "Accepted", count: t.accepted, color: Brand.olive),
      StatusSlice(label: "Started", count: t.started, color: Brand.amber),
      StatusSlice(label: "Completed", count: t.completed, color: Brand.paidGreen),
      StatusSlice(label: "Cancelled", count: t.cancelled, color: Brand.inkSoft),
    ].filter { $0.count > 0 }
  }

  @ViewBuilder private var allocationStatusChart: some View {
    let slices = statusSlices
    chartBlock(title: "Allocation status", symbol: "chart.pie.fill") {
      if slices.isEmpty {
        emptyChart("No allocations for this selection")
      } else {
        Chart(slices) { slice in
          SectorMark(
            angle: .value("Count", slice.count),
            innerRadius: .ratio(0.6),
            angularInset: 1.5
          )
          .cornerRadius(4)
          .foregroundStyle(slice.color)
        }
        .chartForegroundStyleScale(
          domain: slices.map(\.label), range: slices.map(\.color))
        .chartLegend(position: .bottom, spacing: 8)
        .frame(height: 200)
      }
    }
  }

  // MARK: - Helpers

  @ViewBuilder
  private func chartBlock<Content: View>(
    title: String, symbol: String, @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Label(title, systemImage: symbol)
        .font(.caption.weight(.bold))
        .foregroundStyle(Brand.oliveDark)
      content()
    }
    .mpgFormSection(padding: 12)
  }

  private func emptyChart(_ text: String) -> some View {
    Text(text)
      .font(.footnote)
      .foregroundStyle(Brand.inkSoft)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, 8)
  }

  private func shortGBP(_ v: Double) -> String {
    if abs(v) >= 1000 { return "£\(String(format: "%.1f", v / 1000))k" }
    return "£\(Int(v))"
  }
}
