import Foundation

// MARK: - Audit severity

/// How serious an individual audit finding is.
enum AuditSeverity: Int, Comparable, CaseIterable {
  case pass = 0
  case info = 1
  case warning = 2
  case critical = 3

  static func < (lhs: AuditSeverity, rhs: AuditSeverity) -> Bool {
    lhs.rawValue < rhs.rawValue
  }

  var label: String {
    switch self {
    case .pass: return "Clear"
    case .info: return "Note"
    case .warning: return "Check"
    case .critical: return "Flag"
    }
  }

  var symbol: String {
    switch self {
    case .pass: return "checkmark.seal.fill"
    case .info: return "info.circle.fill"
    case .warning: return "exclamationmark.triangle.fill"
    case .critical: return "xmark.octagon.fill"
    }
  }
}

// MARK: - A single audit finding

struct AuditFinding: Identifiable, Hashable {
  let id = UUID()
  var severity: AuditSeverity
  var title: String
  var detail: String
  /// Points added to the risk score (0–100). Higher = more risk.
  var weight: Int
}

// MARK: - Full audit report for one weekly submission

struct InvoiceAudit: Identifiable {
  let id: UUID  // submission id
  var findings: [AuditFinding]

  /// 0 = clean, 100 = maximum risk. Capped.
  var riskScore: Int {
    min(100, findings.reduce(0) { $0 + $1.weight })
  }

  var topSeverity: AuditSeverity {
    findings.map(\.severity).max() ?? .pass
  }

  /// A short verdict Steve can read in a second.
  var verdict: String {
    switch riskScore {
    case 0: return "Looks clean — safe to approve."
    case 1..<25: return "Minor notes only — low risk."
    case 25..<55: return "Worth a quick check before approving."
    default: return "Several issues — review carefully before paying."
    }
  }

  var band: AuditSeverity {
    switch riskScore {
    case 0: return .pass
    case 1..<25: return .info
    case 25..<55: return .warning
    default: return .critical
    }
  }

  /// Plain-English one-line summary suitable for a feed / notification.
  var headline: String {
    let flags = findings.filter { $0.severity >= .warning }.count
    if flags == 0 { return "Auditor: no issues found." }
    return "Auditor: \(flags) item\(flags == 1 ? "" : "s") to review (risk \(riskScore)/100)."
  }
}

// MARK: - The auditor engine

/// Deterministic pre-approval auditor. Cross-references a weekly invoice against
/// the tradesman's GPS clock records, receipts, site photos and the Monday 13:00
/// deadline, then produces a scored, plain-English report so the office reviews
/// exceptions instead of reading every invoice line by line.
///
/// This is fully local and explainable. A hosted LLM pass (via the existing
/// Edge Function pattern) can later enrich the wording, but the numbers and
/// flags come from real data the app already holds.
enum InvoiceAuditor {

  /// Number of days in the week ending `weekEnding` used to gather records.
  private static let weekSpan = 7

  static func audit(_ submission: WeeklySubmission, store: AppStore) -> InvoiceAudit {
    var findings: [AuditFinding] = []
    let cal = Calendar.current

    // The 7-day window this invoice covers.
    let end = cal.startOfDay(for: submission.weekEnding)
    let start = cal.date(byAdding: .day, value: -(weekSpan - 1), to: end) ?? end
    func inWeek(_ d: Date) -> Bool {
      let day = cal.startOfDay(for: d)
      return day >= start && day <= end
    }

    let userId = submission.userId

    // Records for this tradesman inside the invoice week.
    let clocks = store.clockRecords(for: userId).filter { inWeek($0.date) }
    let closedClocks = clocks.filter { !$0.isOpen }
    let materials = store.materials(for: userId).filter { inWeek($0.date) }
    let photos = store.photos.filter { $0.userId == userId && inWeek($0.timestamp) }

    // 1) Hours claimed vs GPS attendance ------------------------------------
    let gpsHours: Double = closedClocks.compactMap { $0.timeOnSite }.reduce(0, +)
    if !closedClocks.isEmpty {
      let diff = submission.totalHours - gpsHours
      let pct = gpsHours > 0 ? abs(diff) / gpsHours : (submission.totalHours > 0 ? 1 : 0)
      if pct >= 0.20 && abs(diff) >= 1 {
        let over = diff > 0
        findings.append(
          AuditFinding(
            severity: over ? .critical : .warning,
            title: over ? "Claimed hours exceed GPS time on site" : "Claimed hours below GPS time",
            detail:
              "Invoice claims \(Fmt.hours(submission.totalHours)) but geofenced attendance shows "
              + "\(Fmt.hours(gpsHours)) — a \(over ? "+" : "")\(Fmt.hours(diff)) difference"
              + " (\(Int(pct * 100))%).",
            weight: over ? 40 : 18))
      } else {
        findings.append(
          AuditFinding(
            severity: .pass, title: "Hours match attendance",
            detail:
              "Claimed \(Fmt.hours(submission.totalHours)) vs \(Fmt.hours(gpsHours)) on site — within tolerance.",
            weight: 0))
      }
    } else if submission.totalHours > 0 {
      findings.append(
        AuditFinding(
          severity: .warning, title: "No GPS clock records to verify hours",
          detail:
            "This invoice claims \(Fmt.hours(submission.totalHours)) of labour but there are no "
            + "geofenced clock-ins this week to cross-check against.",
          weight: 20))
    }

    // 2) Outside-geofence / unapproved attendance ---------------------------
    let flaggedClocks = clocks.filter { $0.overallStatus.needsReview }
    let unapproved = flaggedClocks.filter { $0.adminApproved != true }
    if !unapproved.isEmpty {
      findings.append(
        AuditFinding(
          severity: .critical, title: "Attendance flagged and not yet approved",
          detail:
            "\(unapproved.count) clock event\(unapproved.count == 1 ? "" : "s") this week "
            + "\(unapproved.count == 1 ? "is" : "are") outside the site geofence or missing "
            + "location, and haven't been approved. Resolve before paying.",
          weight: 25))
    }

    // 3) Materials without a receipt ----------------------------------------
    let missingReceipts = materials.filter { !$0.receiptUploaded }
    if submission.materialsTotal > 0 {
      if !missingReceipts.isEmpty {
        let sum = missingReceipts.reduce(0.0) { $0 + $1.total }
        findings.append(
          AuditFinding(
            severity: .warning, title: "Materials claimed without a receipt",
            detail:
              "\(missingReceipts.count) material line\(missingReceipts.count == 1 ? "" : "s") "
              + "(\(Fmt.gbp(sum))) have no receipt attached. Invoice materials total is "
              + "\(Fmt.gbp(submission.materialsTotal)).",
            weight: 22))
      } else if materials.isEmpty {
        findings.append(
          AuditFinding(
            severity: .warning, title: "Materials billed but none logged",
            detail:
              "Invoice bills \(Fmt.gbp(submission.materialsTotal)) of materials but no material "
              + "purchases were logged this week.",
            weight: 18))
      } else {
        findings.append(
          AuditFinding(
            severity: .pass, title: "Materials receipts present",
            detail: "All \(materials.count) logged material lines have a receipt attached.",
            weight: 0))
      }
    }

    // 4) Evidence photos ----------------------------------------------------
    let workTypes: [PhotoType] = [.before, .during, .completed, .variation, .snagging]
    let workPhotos = photos.filter { workTypes.contains($0.type) }
    if submission.labourTotal > 0 && workPhotos.isEmpty {
      findings.append(
        AuditFinding(
          severity: .warning, title: "No work photos this week",
          detail:
            "Labour of \(Fmt.gbp(submission.labourTotal)) is claimed but no before/during/"
            + "completed photos were uploaded to evidence the work.",
          weight: 12))
    } else if !workPhotos.isEmpty {
      findings.append(
        AuditFinding(
          severity: .pass, title: "Work evidenced with photos",
          detail:
            "\(workPhotos.count) site photo\(workPhotos.count == 1 ? "" : "s") uploaded this week.",
          weight: 0))
    }

    // 5) Late submission ----------------------------------------------------
    if let submittedAt = submission.submittedAt {
      let deadline = store.deadline(for: submission.weekEnding)
      if submittedAt > deadline {
        let lateHrs = submittedAt.timeIntervalSince(deadline) / 3600
        findings.append(
          AuditFinding(
            severity: .info, title: "Submitted after the deadline",
            detail:
              "Sent \(Fmt.hours(lateHrs)) after the Monday 13:00 cut-off "
              + "(\(Fmt.time(deadline)) \(Fmt.date(deadline))).",
            weight: 6))
      }
    }

    // 6) Duplicate invoice number -------------------------------------------
    let dupes = store.submissions.filter {
      $0.id != submission.id && !$0.invoiceNumber.isEmpty
        && $0.invoiceNumber.caseInsensitiveCompare(submission.invoiceNumber) == .orderedSame
    }
    if !dupes.isEmpty {
      findings.append(
        AuditFinding(
          severity: .critical, title: "Duplicate invoice number",
          detail:
            "Invoice number \(submission.invoiceNumber) is already used on "
            + "\(dupes.count) other submission\(dupes.count == 1 ? "" : "s").",
          weight: 30))
    }

    // Sort worst-first so the report leads with what matters.
    findings.sort { ($0.severity, $0.weight) > ($1.severity, $1.weight) }

    return InvoiceAudit(id: submission.id, findings: findings)
  }
}
