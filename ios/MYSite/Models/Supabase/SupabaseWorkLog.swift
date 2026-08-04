import Foundation

/// PostgREST mapping for `work_log_entries`.
///
/// Kept in its own file rather than bolted onto `SupabaseDataExtra`, which is
/// already carrying four unrelated tables. Column names are the schema's, not
/// the Swift model's — naming a select after the Swift side is what silently
/// broke `send-to-hubdoc` and `xero-push-invoice`, and the failure mode is a
/// 400 that never reaches the user.
extension SupabaseData {

  struct WorkLogRow: Decodable {
    let id: String
    let user_id: String
    let site_id: String
    let allocation_id: String?
    let date: String?
    let description: String?
    let category: String?
    let minutes: Int?
    let created_at: String?
    let voided: Bool?

    var model: WorkLogEntry? {
      guard let uid = UUID(uuidString: id),
        let userUUID = UUID(uuidString: user_id),
        let siteUUID = UUID(uuidString: site_id)
      else { return nil }
      return WorkLogEntry(
        id: uid, userId: userUUID, siteId: siteUUID,
        allocationId: allocation_id.flatMap { UUID(uuidString: $0) },
        date: parseDate(date) ?? Date(),
        description: description ?? "",
        category: WorkCategory(rawValue: category ?? "") ?? .contract,
        minutes: minutes ?? 0,
        createdAt: parseTimestamp(created_at) ?? Date(),
        voided: voided ?? false)
    }
  }

  static func body(for e: WorkLogEntry) -> [String: Any] {
    var dict: [String: Any] = [
      "id": e.id.uuidString.lowercased(),
      "user_id": e.userId.uuidString.lowercased(),
      "site_id": e.siteId.uuidString.lowercased(),
      "date": dateOnly.string(from: e.date),
      "description": e.description,
      "category": e.category.rawValue,
      "minutes": e.minutes,
      "created_at": timestamp.string(from: e.createdAt),
      "voided": e.voided,
    ]
    if let a = e.allocationId { dict["allocation_id"] = a.uuidString.lowercased() }
    return dict
  }

  static func loadWorkLog(token: String) async throws -> [WorkLogEntry] {
    let data = try await SupabaseClient.shared.get(
      table: "work_log_entries", query: "select=*&order=created_at.asc", accessToken: token)
    let rows = try JSONDecoder().decode([WorkLogRow].self, from: data)
    return rows.compactMap { $0.model }
  }

  static func save(_ e: WorkLogEntry, token: String) async throws {
    try await SupabaseClient.shared.upsert(
      table: "work_log_entries", body: try encode(body(for: e)), accessToken: token)
  }

  static func operation(for e: WorkLogEntry) -> SyncOperation? {
    guard let data = try? encode(body(for: e)) else { return nil }
    return SyncOperation(
      table: "work_log_entries", method: .upsert, bodyData: data,
      label: "Work — \(e.description.prefix(30))")
  }
}
