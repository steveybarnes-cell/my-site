import Foundation

/// A single thing done on a day: "second fix to plots 3 and 4, two and a half
/// hours".
///
/// The app already had `DailyRecord`, which is one row per person per day with
/// one description and one hours figure. That works right up until a day is
/// split — an hour of snagging at Marlborough and the rest of the day on
/// contract work at Clifton is two different jobs, two different sites, and
/// potentially two different charge codes, and squeezing that into a single
/// free-text box loses the detail exactly where the money is.
///
/// So the day is now a list of these, and `DailyRecord` becomes the day's
/// summary rather than its only content. Hours on the invoice are the sum of
/// these lines, which is why `minutes` is an `Int`: half-hours and quarter-hours
/// are the real unit of a working day, and storing them as `Double` hours
/// invites 7.499999 to appear on somebody's invoice.
struct WorkLogEntry: Identifiable, Hashable {
  let id: UUID
  var userId: UUID
  var siteId: UUID
  var allocationId: UUID?
  /// Day this belongs to. Time component is ignored — compared by calendar day.
  var date: Date
  var description: String
  var category: WorkCategory
  var minutes: Int
  var createdAt: Date
  /// Removed by the tradesman, kept in the table.
  ///
  /// Hard-deleting is tempting and wrong: once a day has been invoiced, a row
  /// vanishing rewrites what was billed with nothing to show it happened. It
  /// also needs DELETE plumbing through the offline sync queue, which only
  /// speaks upsert — so a delete made on site with no signal would come back
  /// on the next full reload. Voiding is one boolean and survives both.
  var voided: Bool

  init(
    id: UUID = UUID(), userId: UUID, siteId: UUID, allocationId: UUID? = nil,
    date: Date = Date(), description: String, category: WorkCategory = .contract,
    minutes: Int, createdAt: Date = Date(), voided: Bool = false
  ) {
    self.id = id
    self.userId = userId
    self.siteId = siteId
    self.allocationId = allocationId
    self.date = date
    self.description = description
    self.category = category
    self.minutes = minutes
    self.createdAt = createdAt
    self.voided = voided
  }

  var hours: Double { Double(minutes) / 60.0 }

  /// "2h 30m" — how a builder writes it on a day sheet, not "2.5".
  var durationLabel: String {
    let h = minutes / 60
    let m = minutes % 60
    if h == 0 { return "\(m)m" }
    if m == 0 { return "\(h)h" }
    return "\(h)h \(m)m"
  }
}

extension Array where Element == WorkLogEntry {
  /// Voided lines are excluded everywhere a total is taken, so callers can't
  /// forget to filter and quietly over-bill.
  var live: [WorkLogEntry] { filter { !$0.voided } }
  var totalMinutes: Int { live.reduce(0) { $0 + $1.minutes } }
  var totalHours: Double { Double(totalMinutes) / 60.0 }
}
