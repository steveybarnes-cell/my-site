import Foundation

/// Builds replayable `SyncOperation`s from app models, reusing the existing
/// `body(for:)` encoders. Used by `AppStore` to queue writes that fail offline.
extension SupabaseData {

  private static func upsertOperation(
    table: String, body: [String: Any], label: String
  ) -> SyncOperation? {
    guard let data = try? encode(body) else { return nil }
    return SyncOperation(table: table, method: .upsert, bodyData: data, label: label)
  }

  static func operation(for r: ClockRecord) -> SyncOperation? {
    upsertOperation(
      table: "clock_records", body: body(for: r),
      label: "Clock record — \(r.siteName)")
  }

  static func operation(for r: DailyRecord) -> SyncOperation? {
    upsertOperation(
      table: "daily_records", body: body(for: r),
      label: "Daily record — \(SupabaseData.dateOnly.string(from: r.date))")
  }

  static func operation(for r: WeeklySubmission) -> SyncOperation? {
    upsertOperation(
      table: "weekly_submissions", body: body(for: r),
      label: "Invoice \(r.invoiceNumber)")
  }

  static func operation(for a: WorkAllocation) -> SyncOperation? {
    upsertOperation(
      table: "work_allocations", body: body(for: a),
      label: "Allocation — \(a.taskDescription)")
  }

  static func operation(for s: Site) -> SyncOperation? {
    upsertOperation(
      table: "sites", body: siteBody(for: s),
      label: "Site — \(s.name)")
  }

  static func operation(for u: AppUser) -> SyncOperation? {
    upsertOperation(
      table: "profiles", body: profileBody(for: u),
      label: "Team member — \(u.name)")
  }

  static func operation(for m: MaterialItem) -> SyncOperation? {
    upsertOperation(
      table: "materials", body: body(for: m),
      label: "Material — \(m.supplier)")
  }

  static func operation(for p: SitePhoto) -> SyncOperation? {
    upsertOperation(
      table: "site_photos", body: body(for: p),
      label: "File — \(p.description)")
  }

  static func operation(for n: AppNotification) -> SyncOperation? {
    upsertOperation(
      table: "notifications", body: body(for: n),
      label: "Notification — \(n.type)")
  }

  static func operation(for c: QueryComment) -> SyncOperation? {
    upsertOperation(
      table: "query_comments", body: body(for: c),
      label: "Query comment")
  }

  static func markNotificationsReadOperation(userId: UUID) -> SyncOperation? {
    guard let data = try? encode(["read": true]) else { return nil }
    return SyncOperation(
      table: "notifications", method: .patch,
      query: "user_id=eq.\(userId.uuidString.lowercased())&read=eq.false",
      bodyData: data, label: "Mark notifications read")
  }
}
