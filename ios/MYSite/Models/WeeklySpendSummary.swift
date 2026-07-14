import Foundation

// MARK: - Weekly plain-English spend summary
//
// Turns the numbers the app already holds (labour, materials, invoices, missing
// receipts, week-on-week movement) into an office-ready recap Steve can read in
// a few seconds. Fully local and deterministic so it works offline with no API
// cost. The wording is generated from real figures — an optional hosted LLM pass
// (via the existing Edge Function pattern) can later rephrase the narrative, but
// the numbers stay grounded in this engine.

struct WeeklySpendSummary: Identifiable {
  let id: Date  // week ending (Sunday)
  var weekEnding: Date

  // Headline figures for this week
  var labour: Double
  var materials: Double
  var netDue: Double
  var totalHours: Double
  var invoicesSubmitted: Int
  var pendingApproval: Int
  var approved: Int
  var paid: Int

  // Movement vs the previous week
  var previousSpend: Double?  // labour + materials last week

  // Exceptions worth calling out
  var missingReceipts: Int
  var missingReceiptValue: Double
  var lateSubmissions: Int
  var topSite: (name: String, spend: Double)?
  var busiestTradesman: (name: String, hours: Double)?

  var spend: Double { labour + materials }

  /// Percentage change vs last week, if we have a comparison.
  var changePct: Double? {
    guard let prev = previousSpend, prev > 0 else { return nil }
    return (spend - prev) / prev * 100
  }

  /// A short mood token used to colour the header.
  enum Tone { case calm, watch, alert }
  var tone: Tone {
    if missingReceipts > 0 && missingReceiptValue >= 250 { return .alert }
    if missingReceipts > 0 || lateSubmissions > 0 { return .watch }
    if let c = changePct, c >= 40 { return .watch }
    return .calm
  }

  /// The full plain-English recap, assembled from real figures.
  var narrative: [String] {
    var lines: [String] = []

    // Opening line — spend + movement.
    var opener =
      "Company spend this week was \(Fmt.gbp(spend)) — "
      + "\(Fmt.gbp(labour)) labour and \(Fmt.gbp(materials)) materials"
    if let c = changePct {
      let dir = c >= 0 ? "up" : "down"
      opener += ", \(dir) \(abs(Int(c.rounded())))% on last week."
    } else {
      opener += "."
    }
    lines.append(opener)

    // Invoice pipeline.
    if invoicesSubmitted > 0 {
      var pipe = "\(invoicesSubmitted) invoice\(invoicesSubmitted == 1 ? "" : "s") came in"
      pipe += ", totalling \(Fmt.gbp(netDue)) net to pay."
      if pendingApproval > 0 {
        pipe += " \(pendingApproval) still need\(pendingApproval == 1 ? "s" : "") your approval."
      } else if approved > 0 || paid > 0 {
        pipe += " All have been actioned."
      }
      lines.append(pipe)
    } else {
      lines.append("No invoices were submitted for this week yet.")
    }

    // Where the money went.
    if let site = topSite, site.spend > 0 {
      lines.append(
        "\(site.name) was the biggest cost centre at \(Fmt.gbp(site.spend)).")
    }
    if let man = busiestTradesman, man.hours > 0 {
      lines.append(
        "\(man.name) logged the most time on site — \(Fmt.hours(man.hours)).")
    }

    // Exceptions to chase.
    if missingReceipts > 0 {
      lines.append(
        "⚠️ \(missingReceipts) materials line\(missingReceipts == 1 ? "" : "s") "
          + "(\(Fmt.gbp(missingReceiptValue))) are still missing a receipt — worth chasing before you pay."
      )
    }
    if lateSubmissions > 0 {
      lines.append(
        "\(lateSubmissions) invoice\(lateSubmissions == 1 ? " was" : "s were") "
          + "submitted after the Monday 13:00 deadline.")
    }
    if missingReceipts == 0 && lateSubmissions == 0 && invoicesSubmitted > 0 {
      lines.append("✅ Nothing outstanding — receipts and deadlines are all clean this week.")
    }

    return lines
  }

  /// One-line version for a notification or feed.
  var headline: String {
    var s = "This week: \(Fmt.gbp(spend)) spent"
    if let c = changePct {
      s += " (\(c >= 0 ? "+" : "")\(Int(c.rounded()))%)"
    }
    if missingReceipts > 0 {
      s += " • \(missingReceipts) receipt\(missingReceipts == 1 ? "" : "s") missing"
    }
    return s
  }
}

// MARK: - Builder

enum WeeklySpendSummarizer {

  /// Build the summary for the given week ending, using the same visibility
  /// scoping as the dashboard (admin = all sites, SM = their sites).
  static func summary(for weekEnding: Date, store: AppStore) -> WeeklySpendSummary {
    let week = FileStorage.weekEndingSunday(for: weekEnding)

    var filter = DashboardFilter()
    filter.weekEnding = week
    let analytics = DashboardAnalytics(store: store, filter: filter)

    let ws = analytics.weekSummary
    let siteCosts = analytics.siteCosts
    let tradesmanRows = analytics.tradesmanRows

    // Missing receipts inside this week.
    let missing = analytics.materials.filter { !$0.receiptUploaded }
    let missingValue = missing.reduce(0.0) { $0 + $1.total }

    // Late submissions inside this week.
    let late = analytics.submissions.filter { sub in
      guard let submitted = sub.submittedAt else { return false }
      return submitted > store.deadline(for: sub.weekEnding)
    }.count

    // Biggest-cost site and busiest tradesman this week.
    let topSite = siteCosts.max(by: { $0.total < $1.total })
      .map { (name: $0.siteName, spend: $0.total) }
    let busiest = tradesmanRows.max(by: { $0.hours < $1.hours })
      .flatMap { $0.hours > 0 ? (name: $0.name, hours: $0.hours) : nil }

    // Previous week comparison.
    let prevWeek = Calendar.current.date(byAdding: .day, value: -7, to: week) ?? week
    var prevFilter = DashboardFilter()
    prevFilter.weekEnding = prevWeek
    let prevAnalytics = DashboardAnalytics(store: store, filter: prevFilter)
    let prevSpend = prevAnalytics.weekSummary.labourValue + prevAnalytics.weekSummary.materialsValue
    let prevHadData =
      prevAnalytics.weekSummary.invoicesSubmitted > 0
      || prevAnalytics.materials.isEmpty == false

    return WeeklySpendSummary(
      id: week,
      weekEnding: week,
      labour: ws.labourValue,
      materials: ws.materialsValue,
      netDue: ws.netDue,
      totalHours: ws.totalHours,
      invoicesSubmitted: ws.invoicesSubmitted,
      pendingApproval: ws.pendingApproval,
      approved: ws.approved,
      paid: ws.paid,
      previousSpend: prevHadData ? prevSpend : nil,
      missingReceipts: missing.count,
      missingReceiptValue: missingValue,
      lateSubmissions: late,
      topSite: topSite,
      busiestTradesman: busiest)
  }

  /// The list of weeks that have any submissions, most recent first, for the picker.
  static func availableWeeks(store: AppStore) -> [Date] {
    let weeks = Set(store.submissions.map { FileStorage.weekEndingSunday(for: $0.weekEnding) })
    if weeks.isEmpty {
      return [FileStorage.weekEndingSunday(for: Date())]
    }
    return weeks.sorted(by: >)
  }
}
