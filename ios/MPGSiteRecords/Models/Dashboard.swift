import Foundation

// MARK: - Dashboard filters
//
// Mirrors the central Google Sheets dashboard for My Project Group Ltd.
// Every rollup below is what a live Google Sheet (fed by the app tabs) would
// compute with pivot tables / QUERY(). Local-first now, backend-ready later.

struct DashboardFilter {
  var weekEnding: Date? = nil
  var siteId: UUID? = nil
  var tradesmanId: UUID? = nil
  var trade: String? = nil
  var submissionStatus: SubmissionStatus? = nil
  var workCategory: WorkCategory? = nil
  var missingReceiptOnly: Bool = false
  var variationOnly: Bool = false

  var isActive: Bool {
    weekEnding != nil || siteId != nil || tradesmanId != nil || trade != nil
      || submissionStatus != nil || workCategory != nil || missingReceiptOnly || variationOnly
  }
}

// MARK: - Rollup value types

struct WeekSummary {
  var totalHours: Double = 0
  var labourValue: Double = 0
  var materialsValue: Double = 0
  var cisDeduction: Double = 0
  var netDue: Double = 0
  var invoicesSubmitted = 0
  var pendingApproval = 0
  var approved = 0
  var paid = 0
  var queried = 0
}

struct SiteCostRow: Identifiable {
  let id: UUID
  var siteName: String
  var labour: Double
  var materials: Double
  var variation: Double
  var missingReceipts: Int
  var total: Double { labour + materials }
}

struct TradesmanRow: Identifiable {
  let id: UUID
  var name: String
  var hours: Double
  var invoiceValue: Double
  var missingReceipts: Int
  var lateSubmissions: Int
  var queries: Int
}

struct AllocationTracker {
  var allocated = 0
  var accepted = 0
  var started = 0
  var completed = 0
  var notSubmitted = 0
  var cancelled = 0
}

struct MissingEvidence {
  var materialsNoReceipt: [MaterialItem] = []
  var variationNoPhotos: [DailyRecord] = []
  var delaysNoEvidence: [DailyRecord] = []
  var recordsUnapproved: [DailyRecord] = []
}

struct PaymentRunRow: Identifiable {
  let id: UUID
  var contractor: String
  var weekEnding: Date
  var invoiceNumber: String
  var gross: Double
  var cis: Double
  var netDue: Double
  var approvalStatus: String
  var paymentStatus: String
  var paymentDate: Date?
}

// MARK: - Analytics engine

/// Computes every dashboard section, scoped to the visible sites for the
/// current viewer (admin = all sites, site manager = assigned sites only).
struct DashboardAnalytics {
  let store: AppStore
  var filter: DashboardFilter

  /// Sites this viewer is allowed to see.
  var visibleSites: [Site] {
    guard let me = store.currentUser else { return [] }
    switch me.role {
    case .admin: return store.sites
    case .siteManager: return store.sitesManaged(by: me.id)
    case .tradesman: return []
    }
  }

  private var visibleSiteIds: Set<UUID> { Set(visibleSites.map { $0.id }) }

  /// Sites after applying the site filter (still bounded by visibility).
  var scopedSites: [Site] {
    visibleSites.filter { filter.siteId == nil || $0.id == filter.siteId }
  }
  private var scopedSiteIds: Set<UUID> { Set(scopedSites.map { $0.id }) }

  // MARK: Filtered base collections

  private func sameWeek(_ date: Date) -> Bool {
    guard let we = filter.weekEnding else { return true }
    let a = FileStorage.weekEndingSunday(for: date)
    let b = FileStorage.weekEndingSunday(for: we)
    return Calendar.current.isDate(a, inSameDayAs: b)
  }

  var records: [DailyRecord] {
    store.dailyRecords.filter { r in
      scopedSiteIds.contains(r.siteId)
        && (filter.tradesmanId == nil || r.userId == filter.tradesmanId)
        && (filter.trade == nil || r.trade == filter.trade)
        && (filter.workCategory == nil || r.category == filter.workCategory)
        && (!filter.variationOnly || r.category == .variation)
        && sameWeek(r.date)
    }
  }

  var materials: [MaterialItem] {
    store.materials.filter { m in
      scopedSiteIds.contains(m.siteId)
        && (filter.tradesmanId == nil || m.userId == filter.tradesmanId)
        && (!filter.missingReceiptOnly || !m.receiptUploaded)
        && sameWeek(m.date)
    }
  }

  var allocations: [WorkAllocation] {
    store.allocations.filter { a in
      scopedSiteIds.contains(a.siteId)
        && (filter.tradesmanId == nil || a.tradesmanId == filter.tradesmanId)
        && (filter.trade == nil || a.trade == filter.trade)
        && (filter.workCategory == nil || a.category == filter.workCategory)
        && (!filter.variationOnly || a.category == .variation)
        && sameWeek(a.date)
    }
  }

  /// Submissions scoped to visible tradesmen (those who have work on visible sites).
  var submissions: [WeeklySubmission] {
    let visibleTradesmen = Set(
      store.allocations.filter { visibleSiteIds.contains($0.siteId) }.map { $0.tradesmanId }
    )
    return store.submissions.filter { s in
      (store.currentUser?.role == .admin || visibleTradesmen.contains(s.userId))
        && (filter.tradesmanId == nil || s.userId == filter.tradesmanId)
        && (filter.submissionStatus == nil || s.status == filter.submissionStatus)
        && (filter.weekEnding == nil
          || Calendar.current.isDate(
            FileStorage.weekEndingSunday(for: s.weekEnding),
            inSameDayAs: FileStorage.weekEndingSunday(for: filter.weekEnding!)))
    }
  }

  // MARK: 1. This week summary

  var weekSummary: WeekSummary {
    var s = WeekSummary()
    for sub in submissions {
      s.totalHours += sub.totalHours
      s.labourValue += sub.labourTotal
      s.materialsValue += sub.materialsTotal
      s.cisDeduction += sub.cisDeduction
      s.netDue += sub.netDue
      if sub.status != .draft { s.invoicesSubmitted += 1 }
      switch sub.status {
      case .submitted, .awaitingSM, .approvedSM, .onHold:
        s.pendingApproval += 1
      case .approvedPayment:
        s.approved += 1
      case .paid:
        s.paid += 1
      case .queryRaised, .rejected:
        s.queried += 1
      case .draft:
        break
      }
    }
    return s
  }

  // MARK: 2. Site cost summary

  var siteCosts: [SiteCostRow] {
    scopedSites.map { site in
      let recs = records.filter { $0.siteId == site.id }
      let labour = recs.reduce(0.0) { acc, r in
        acc + r.totalHours * (store.profile(for: r.userId)?.hourlyRate ?? 0)
      }
      let mats = materials.filter { $0.siteId == site.id }
      let materialsTotal = mats.reduce(0.0) { $0 + $1.total }
      let variation = recs.filter { $0.category == .variation }.reduce(0.0) { acc, r in
        acc + r.totalHours * (store.profile(for: r.userId)?.hourlyRate ?? 0)
      }
      let missing = mats.filter { !$0.receiptUploaded }.count
      return SiteCostRow(
        id: site.id, siteName: site.name, labour: labour,
        materials: materialsTotal, variation: variation, missingReceipts: missing)
    }
  }

  // MARK: 3. Tradesman summary

  var tradesmanRows: [TradesmanRow] {
    let ids = Set(records.map { $0.userId })
      .union(materials.map { $0.userId })
      .union(submissions.map { $0.userId })
    return ids.compactMap { id -> TradesmanRow? in
      guard let u = store.user(id) else { return nil }
      let hours = records.filter { $0.userId == id }.reduce(0.0) { $0 + $1.totalHours }
      let invoiceValue = submissions.filter { $0.userId == id }.reduce(0.0) { $0 + $1.netDue }
      let missing = materials.filter { $0.userId == id && !$0.receiptUploaded }.count
      let late = submissions.filter { sub in
        guard sub.userId == id, let submitted = sub.submittedAt else { return false }
        return submitted > store.deadline(for: sub.weekEnding)
      }.count
      let subIds = Set(submissions.filter { $0.userId == id }.map { $0.id })
      let queries = store.comments.filter { subIds.contains($0.submissionId) && $0.fromAdmin }.count
      return TradesmanRow(
        id: id, name: u.name, hours: hours, invoiceValue: invoiceValue,
        missingReceipts: missing, lateSubmissions: late, queries: queries)
    }
    .sorted { $0.name < $1.name }
  }

  // MARK: 4. Work allocation tracker

  var allocationTracker: AllocationTracker {
    var t = AllocationTracker()
    let submittedRecordAllocs = Set(store.dailyRecords.compactMap { $0.allocationId })
    for a in allocations {
      switch a.status {
      case .allocated: t.allocated += 1
      case .accepted: t.accepted += 1
      case .started, .inProgress: t.started += 1
      case .completed: t.completed += 1
      case .cancelled: t.cancelled += 1
      case .queried: break
      }
      if a.status != .cancelled && a.status != .completed
        && !submittedRecordAllocs.contains(a.id)
      {
        t.notSubmitted += 1
      }
    }
    return t
  }

  // MARK: 5. Missing evidence

  var missingEvidence: MissingEvidence {
    var m = MissingEvidence()
    m.materialsNoReceipt = materials.filter { !$0.receiptUploaded }

    let photosByRecord = Set(store.photos.compactMap { $0.dailyRecordId })
    let variationPhotoAllocs = Set(
      store.photos.filter { $0.type == .variation }.compactMap { $0.allocationId })
    m.variationNoPhotos = records.filter { r in
      r.category == .variation
        && !photosByRecord.contains(r.id)
        && !(r.allocationId.map { variationPhotoAllocs.contains($0) } ?? false)
    }

    let delayPhotoRecords = Set(
      store.photos.filter { $0.type == .delay }.compactMap { $0.dailyRecordId })
    m.delaysNoEvidence = records.filter { r in
      r.delayReason != .none
        && r.delayNote.trimmingCharacters(in: .whitespaces).isEmpty
        && !delayPhotoRecords.contains(r.id)
    }

    // No dedicated SM-approval flag on daily records: treat records tied to a
    // still-open allocation as awaiting site manager sign-off.
    let openAllocs = Set(
      store.allocations.filter { $0.status != .completed }.map { $0.id })
    m.recordsUnapproved = records.filter { r in
      r.allocationId.map { openAllocs.contains($0) } ?? false
    }
    return m
  }

  // MARK: 6. Payment run

  var paymentRun: [PaymentRunRow] {
    submissions
      .sorted { $0.weekEnding > $1.weekEnding }
      .map { sub in
        PaymentRunRow(
          id: sub.id,
          contractor: store.user(sub.userId)?.name ?? "—",
          weekEnding: sub.weekEnding,
          invoiceNumber: sub.invoiceNumber,
          gross: sub.gross,
          cis: sub.cisDeduction,
          netDue: sub.netDue,
          approvalStatus: sub.approvedBy != nil ? "Approved" : sub.status.rawValue,
          paymentStatus: sub.status == .paid ? "Paid" : "Unpaid",
          paymentDate: sub.paidDate)
      }
  }

  // MARK: Filter option sources

  var availableTrades: [String] {
    Set(
      store.allocations.filter { visibleSiteIds.contains($0.siteId) }.map { $0.trade }
    ).sorted()
  }

  var availableWeekEndings: [Date] {
    Set(store.submissions.map { FileStorage.weekEndingSunday(for: $0.weekEnding) })
      .sorted(by: >)
  }

  var availableTradesmen: [AppUser] {
    let ids = Set(
      store.allocations.filter { visibleSiteIds.contains($0.siteId) }.map { $0.tradesmanId })
    return store.users.filter { ids.contains($0.id) }.sorted { $0.name < $1.name }
  }
}
