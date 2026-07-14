import Foundation

/// A single line of a structured answer (a fact, a metric or a list row).
struct AskAnswerRow: Identifiable, Hashable {
  let id = UUID()
  var title: String
  var detail: String
  var value: String
  var symbol: String
}

/// A full answer to an admin's natural-language question, assembled locally
/// from `AppStore` data — no network, fully deterministic and explainable.
struct AskAnswer: Identifiable, Hashable {
  let id = UUID()
  var headline: String
  var summary: String
  var rows: [AskAnswerRow]
  var symbol: String
}

/// "Ask MPG" — a local natural-language query engine over the company's live
/// data. It interprets the admin's question, resolves any named site or
/// tradesman, applies an optional amount threshold and time window, and returns
/// a structured, explainable answer. The numbers always come from the same
/// analytics used across the app, so answers stay authoritative.
enum AskMPG {
  // Suggested prompts surfaced in the UI.
  static let suggestions: [String] = [
    "How much do we owe right now?",
    "Which invoices are awaiting approval?",
    "What did we spend this week?",
    "Any materials missing a receipt?",
    "Who worked the most hours?",
    "Which site is costing us the most?",
    "Show unpaid invoices over £500",
    "Any invoices submitted late?",
    "Which invoices did we query?",
    "How many are ready to pay?",
  ]

  static func answer(to raw: String, store: AppStore) -> AskAnswer {
    let q = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    guard !q.isEmpty else {
      return AskAnswer(
        headline: "Ask me anything",
        summary: "Try one of the suggestions below.",
        rows: [], symbol: "sparkles")
    }

    let site = matchedSite(in: q, store: store)
    let tradesman = matchedTradesman(in: q, store: store)
    let threshold = amountThreshold(in: q)
    let thisWeek = q.contains("this week") || q.contains("week")

    // --- Intent routing (first match wins) ---

    if contains(q, ["owe", "outstanding", "owed", "to pay", "still pay", "unpaid balance"]) {
      return owedAnswer(store: store, site: site, tradesman: tradesman, threshold: threshold)
    }
    if contains(q, ["late", "after deadline", "missed deadline", "overdue submit"]) {
      return lateAnswer(store: store)
    }
    if contains(q, ["missing receipt", "no receipt", "without receipt", "receipt missing"]) {
      return missingReceiptAnswer(store: store, site: site)
    }
    if contains(q, ["awaiting approval", "to review", "to approve", "needs approval", "pending approval", "review"]) {
      return statusAnswer(
        store: store, statuses: [.submitted, .awaitingSM, .approvedSM, .onHold],
        label: "awaiting approval", symbol: "tray.full", threshold: threshold, site: site)
    }
    if contains(q, ["query", "queried", "disputed", "on hold", "rejected"]) {
      return statusAnswer(
        store: store, statuses: [.queryRaised, .onHold, .rejected],
        label: "queried or on hold", symbol: "questionmark.circle", threshold: threshold, site: site)
    }
    if contains(q, ["ready to pay", "approved for payment", "to be paid", "ready for payment"]) {
      return statusAnswer(
        store: store, statuses: [.approvedPayment],
        label: "approved for payment", symbol: "checkmark.seal", threshold: threshold, site: site)
    }
    if contains(q, ["paid"]) && !contains(q, ["unpaid"]) {
      return statusAnswer(
        store: store, statuses: [.paid],
        label: "paid", symbol: "banknote", threshold: threshold, site: site)
    }
    if contains(q, ["unpaid", "not paid", "still unpaid"]) {
      return unpaidAnswer(store: store, threshold: threshold, site: site)
    }
    if contains(q, ["hours", "worked most", "who worked"]) {
      return hoursAnswer(store: store, thisWeek: thisWeek, tradesman: tradesman)
    }
    if contains(q, ["costing", "most expensive", "biggest cost", "cost the most", "spend by site", "which site"]) {
      return siteSpendAnswer(store: store, thisWeek: thisWeek)
    }
    if contains(q, ["spend", "spent", "cost", "total cost"]) {
      return spendAnswer(store: store, thisWeek: thisWeek, site: site)
    }
    if let tradesman { return tradesmanAnswer(store: store, tradesman: tradesman) }
    if let site { return siteAnswer(store: store, site: site) }

    // Fallback: a compact company snapshot.
    return snapshotAnswer(store: store)
  }

  // MARK: - Intent builders

  private static func owedAnswer(
    store: AppStore, site: Site?, tradesman: AppUser?, threshold: Double?
  ) -> AskAnswer {
    var subs = store.submissions.filter { $0.status != .paid && $0.status != .draft }
    if let tradesman { subs = subs.filter { $0.userId == tradesman.id } }
    if let threshold { subs = subs.filter { $0.netDue >= threshold } }
    let total = subs.reduce(0) { $0 + $1.netDue }
    let scope =
      tradesman.map { " to \($0.name)" } ?? (threshold != nil ? " over \(Fmt.gbp(threshold!))" : "")
    return AskAnswer(
      headline: Fmt.gbp(total),
      summary:
        "Outstanding across \(subs.count) invoice\(subs.count == 1 ? "" : "s")\(scope) not yet paid.",
      rows: submissionRows(subs, store: store),
      symbol: "sterlingsign.circle.fill")
  }

  private static func unpaidAnswer(store: AppStore, threshold: Double?, site: Site?) -> AskAnswer {
    var subs = store.submissions.filter { $0.status != .paid && $0.status != .draft }
    if let threshold { subs = subs.filter { $0.netDue >= threshold } }
    let total = subs.reduce(0) { $0 + $1.netDue }
    let scope = threshold != nil ? " over \(Fmt.gbp(threshold!))" : ""
    return AskAnswer(
      headline: "\(subs.count) unpaid",
      summary: "\(Fmt.gbp(total)) still owed across unpaid invoices\(scope).",
      rows: submissionRows(subs, store: store),
      symbol: "doc.text.fill")
  }

  private static func lateAnswer(store: AppStore) -> AskAnswer {
    let late = store.lateSubmissions()
    let total = late.reduce(0) { $0 + $1.netDue }
    return AskAnswer(
      headline: "\(late.count) late",
      summary: late.isEmpty
        ? "No invoices were submitted after the Monday 13:00 deadline. Nicely on time."
        : "\(late.count) invoice\(late.count == 1 ? "" : "s") landed after the Monday 13:00 deadline (\(Fmt.gbp(total))).",
      rows: submissionRows(late, store: store),
      symbol: "clock.badge.exclamationmark")
  }

  private static func missingReceiptAnswer(store: AppStore, site: Site?) -> AskAnswer {
    var mats = store.missingReceiptMaterials()
    if let site { mats = mats.filter { $0.siteId == site.id } }
    let total = mats.reduce(0) { $0 + $1.total }
    let rows = mats.sorted { $0.total > $1.total }.prefix(12).map { m in
      AskAnswerRow(
        title: m.supplier.isEmpty ? "Materials" : m.supplier,
        detail: "\(store.site(m.siteId)?.name ?? "Site") • \(Fmt.date(m.date))",
        value: Fmt.gbp(m.total),
        symbol: "doc.badge.ellipsis")
    }
    return AskAnswer(
      headline: mats.isEmpty ? "All clear" : "\(mats.count) missing",
      summary: mats.isEmpty
        ? "Every materials purchase has a receipt attached."
        : "\(mats.count) purchase\(mats.count == 1 ? "" : "s") worth \(Fmt.gbp(total)) still need a receipt before payment.",
      rows: Array(rows),
      symbol: "doc.badge.ellipsis")
  }

  private static func statusAnswer(
    store: AppStore, statuses: [SubmissionStatus], label: String, symbol: String,
    threshold: Double?, site: Site?
  ) -> AskAnswer {
    var subs = store.submissions.filter { statuses.contains($0.status) }
    if let threshold { subs = subs.filter { $0.netDue >= threshold } }
    let total = subs.reduce(0) { $0 + $1.netDue }
    let scope = threshold != nil ? " over \(Fmt.gbp(threshold!))" : ""
    return AskAnswer(
      headline: "\(subs.count) \(subs.count == 1 ? "invoice" : "invoices")",
      summary: subs.isEmpty
        ? "Nothing is \(label) right now\(scope)."
        : "\(Fmt.gbp(total)) across invoices \(label)\(scope).",
      rows: submissionRows(subs, store: store),
      symbol: symbol)
  }

  private static func hoursAnswer(
    store: AppStore, thisWeek: Bool, tradesman: AppUser?
  ) -> AskAnswer {
    let rows = analytics(store: store, thisWeek: thisWeek).tradesmanRows
      .filter { tradesman == nil || $0.id == tradesman!.id }
      .sorted { $0.hours > $1.hours }
    let top = rows.first
    return AskAnswer(
      headline: top.map { Fmt.hours($0.hours) } ?? "0h",
      summary: top.map {
        "\($0.name) logged the most hours\(thisWeek ? " this week" : "") at \(Fmt.hours($0.hours))."
      } ?? "No hours logged\(thisWeek ? " this week" : "") yet.",
      rows: rows.prefix(10).map { r in
        AskAnswerRow(
          title: r.name, detail: "\(Fmt.gbp(r.invoiceValue)) invoiced",
          value: Fmt.hours(r.hours), symbol: "clock")
      },
      symbol: "clock.fill")
  }

  private static func siteSpendAnswer(store: AppStore, thisWeek: Bool) -> AskAnswer {
    let rows = analytics(store: store, thisWeek: thisWeek).siteCosts
      .filter { $0.total > 0 }.sorted { $0.total > $1.total }
    let top = rows.first
    return AskAnswer(
      headline: top.map { Fmt.gbp($0.total) } ?? "£0",
      summary: top.map {
        "\($0.siteName) is the biggest cost centre\(thisWeek ? " this week" : "") at \(Fmt.gbp($0.total))."
      } ?? "No site spend recorded\(thisWeek ? " this week" : "") yet.",
      rows: rows.prefix(10).map { r in
        AskAnswerRow(
          title: r.siteName,
          detail: "Labour \(Fmt.gbp(r.labour)) • Materials \(Fmt.gbp(r.materials))",
          value: Fmt.gbp(r.total), symbol: "building.2")
      },
      symbol: "mappin.and.ellipse")
  }

  private static func spendAnswer(store: AppStore, thisWeek: Bool, site: Site?) -> AskAnswer {
    var a = analytics(store: store, thisWeek: thisWeek)
    if let site {
      var f = a.filter
      f.siteId = site.id
      a.filter = f
    }
    let s = a.weekSummary
    let total = s.labourValue + s.materialsValue
    return AskAnswer(
      headline: Fmt.gbp(total),
      summary:
        "\(thisWeek ? "This week" : "To date")\(site.map { " at \($0.name)" } ?? ""): \(Fmt.gbp(s.labourValue)) labour + \(Fmt.gbp(s.materialsValue)) materials, \(Fmt.gbp(s.netDue)) net to pay.",
      rows: [
        AskAnswerRow(title: "Labour", detail: "\(Fmt.hours(s.totalHours)) on site", value: Fmt.gbp(s.labourValue), symbol: "hammer"),
        AskAnswerRow(title: "Materials", detail: "Purchases + supplier invoices", value: Fmt.gbp(s.materialsValue), symbol: "shippingbox"),
        AskAnswerRow(title: "Net to pay", detail: "After CIS + VAT", value: Fmt.gbp(s.netDue), symbol: "banknote"),
        AskAnswerRow(title: "Invoices", detail: "\(s.pendingApproval) pending • \(s.paid) paid", value: "\(s.invoicesSubmitted)", symbol: "doc.text"),
      ],
      symbol: "chart.bar.fill")
  }

  private static func tradesmanAnswer(store: AppStore, tradesman: AppUser) -> AskAnswer {
    let subs = store.submissions.filter { $0.userId == tradesman.id }
    let outstanding = subs.filter { $0.status != .paid && $0.status != .draft }
      .reduce(0) { $0 + $1.netDue }
    let hours = store.dailyRecords.filter { $0.userId == tradesman.id }.reduce(0) { $0 + $1.totalHours }
    let missing = store.missingReceiptMaterials().filter { $0.userId == tradesman.id }.count
    return AskAnswer(
      headline: tradesman.name,
      summary:
        "\(Fmt.gbp(outstanding)) outstanding • \(Fmt.hours(hours)) logged • \(subs.count) invoice\(subs.count == 1 ? "" : "s").",
      rows: submissionRows(subs, store: store) + (missing > 0 ? [
        AskAnswerRow(title: "Missing receipts", detail: "Chase before payment", value: "\(missing)", symbol: "doc.badge.ellipsis")
      ] : []),
      symbol: "person.crop.circle.fill")
  }

  private static func siteAnswer(store: AppStore, site: Site) -> AskAnswer {
    let row = analytics(store: store, thisWeek: false).siteCosts.first { $0.id == site.id }
    return AskAnswer(
      headline: site.name,
      summary:
        "\(site.status.rawValue) • \(row.map { Fmt.gbp($0.total) } ?? "£0") spent • \(row?.missingReceipts ?? 0) missing receipt\((row?.missingReceipts ?? 0) == 1 ? "" : "s").",
      rows: [
        AskAnswerRow(title: "Labour", detail: site.client, value: Fmt.gbp(row?.labour ?? 0), symbol: "hammer"),
        AskAnswerRow(title: "Materials", detail: site.address, value: Fmt.gbp(row?.materials ?? 0), symbol: "shippingbox"),
      ],
      symbol: "mappin.and.ellipse")
  }

  private static func snapshotAnswer(store: AppStore) -> AskAnswer {
    let outstanding = store.submissions.filter { $0.status != .paid && $0.status != .draft }
      .reduce(0) { $0 + $1.netDue }
    let toReview = store.submissions.filter {
      [.submitted, .awaitingSM, .approvedSM, .onHold].contains($0.status)
    }.count
    let missing = store.missingReceiptMaterials().count
    return AskAnswer(
      headline: "Company snapshot",
      summary: "Here's where things stand. Try asking about spend, invoices, sites or a person by name.",
      rows: [
        AskAnswerRow(title: "Outstanding", detail: "Not yet paid", value: Fmt.gbp(outstanding), symbol: "sterlingsign.circle"),
        AskAnswerRow(title: "To review", detail: "Invoices awaiting approval", value: "\(toReview)", symbol: "tray.full"),
        AskAnswerRow(title: "Active sites", detail: "Currently on the books", value: "\(store.sites.filter { $0.status == .active }.count)", symbol: "mappin.and.ellipse"),
        AskAnswerRow(title: "Missing receipts", detail: "Chase before payment", value: "\(missing)", symbol: "doc.badge.ellipsis"),
      ],
      symbol: "sparkles")
  }

  // MARK: - Helpers

  private static func submissionRows(
    _ subs: [WeeklySubmission], store: AppStore
  ) -> [AskAnswerRow] {
    subs.sorted { $0.netDue > $1.netDue }.prefix(12).map { s in
      AskAnswerRow(
        title: store.user(s.userId)?.name ?? "Subcontractor",
        detail: "\(s.invoiceNumber) • \(s.status.rawValue) • W/E \(Fmt.date(s.weekEnding))",
        value: Fmt.gbp(s.netDue),
        symbol: "doc.text")
    }
  }

  private static func analytics(store: AppStore, thisWeek: Bool) -> DashboardAnalytics {
    var f = DashboardFilter()
    if thisWeek {
      f.weekEnding = FileStorage.weekEndingSunday(for: Date())
    }
    return DashboardAnalytics(store: store, filter: f)
  }

  private static func contains(_ q: String, _ keys: [String]) -> Bool {
    keys.contains { q.contains($0) }
  }

  private static func matchedSite(in q: String, store: AppStore) -> Site? {
    store.sites.first { site in
      let name = site.name.lowercased()
      return name.count > 3 && q.contains(name)
    } ?? store.sites.first { site in
      // Match on the first significant word of the site name/address.
      let token = site.name.lowercased().split(separator: " ").first.map(String.init) ?? ""
      return token.count > 4 && q.contains(token)
    }
  }

  private static func matchedTradesman(in q: String, store: AppStore) -> AppUser? {
    store.users.first { u in
      guard u.role == .tradesman || u.role == .siteManager else { return false }
      let first = u.name.lowercased().split(separator: " ").first.map(String.init) ?? ""
      return first.count > 2 && q.contains(first)
    }
  }

  /// Extracts an amount threshold from phrases like "over £500" or "above 1000".
  private static func amountThreshold(in q: String) -> Double? {
    guard contains(q, ["over", "above", "more than", "greater than", ">"]) else { return nil }
    let cleaned = q.replacingOccurrences(of: "£", with: " ")
      .replacingOccurrences(of: ",", with: "")
    let scanner = cleaned.split { !$0.isNumber && $0 != "." }
    for token in scanner {
      if let v = Double(token), v > 0 { return v }
    }
    return nil
  }
}
