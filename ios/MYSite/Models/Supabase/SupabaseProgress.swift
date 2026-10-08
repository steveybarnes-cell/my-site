import Foundation

/// PostgREST mapping for `allocation_progress` and `material_requests`.
///
/// Column names are the schema's, not the Swift model's. Naming a select after
/// the Swift side is what silently broke `send-to-hubdoc` and
/// `xero-push-invoice`, and the failure mode is a 400 nobody ever sees.
extension SupabaseData {

  // MARK: - Allocation progress

  struct ProgressRow: Decodable {
    let id: String
    let allocation_id: String
    let user_id: String
    let percent: Int?
    let note: String?
    let created_at: String?

    var model: AllocationProgress? {
      guard let uid = UUID(uuidString: id),
        let alloc = UUID(uuidString: allocation_id),
        let user = UUID(uuidString: user_id)
      else { return nil }
      return AllocationProgress(
        id: uid, allocationId: alloc, userId: user, percent: percent ?? 0,
        note: note ?? "", createdAt: parseTimestamp(created_at) ?? Date())
    }
  }

  static func body(for p: AllocationProgress) -> [String: Any] {
    [
      "id": p.id.uuidString.lowercased(),
      "allocation_id": p.allocationId.uuidString.lowercased(),
      "user_id": p.userId.uuidString.lowercased(),
      "percent": p.percent,
      "note": p.note,
      "created_at": timestamp.string(from: p.createdAt),
    ]
  }

  static func loadProgress(token: String) async throws -> [AllocationProgress] {
    let data = try await SupabaseClient.shared.get(
      table: "allocation_progress", query: "select=*&order=created_at.desc&limit=500",
      accessToken: token)
    return try JSONDecoder().decode([ProgressRow].self, from: data).compactMap { $0.model }
  }

  static func save(_ p: AllocationProgress, token: String) async throws {
    try await SupabaseClient.shared.upsert(
      table: "allocation_progress", body: try encode(body(for: p)), accessToken: token)
  }

  static func operation(for p: AllocationProgress) -> SyncOperation? {
    guard let data = try? encode(body(for: p)) else { return nil }
    return SyncOperation(
      table: "allocation_progress", method: .upsert, bodyData: data,
      label: "Progress — \(p.percent)%")
  }

  // MARK: - Material requests

  struct MaterialRequestRow: Decodable {
    let id: String
    let user_id: String
    let site_id: String
    let allocation_id: String?
    let description: String?
    let quantity: String?
    let needed_by: String?
    let status: String?
    let office_note: String?
    let created_at: String?

    var model: MaterialRequest? {
      guard let uid = UUID(uuidString: id),
        let user = UUID(uuidString: user_id),
        let site = UUID(uuidString: site_id)
      else { return nil }
      return MaterialRequest(
        id: uid, userId: user, siteId: site,
        allocationId: allocation_id.flatMap { UUID(uuidString: $0) },
        description: description ?? "", quantity: quantity ?? "",
        neededBy: parseDate(needed_by),
        status: MaterialRequestStatus(rawValue: status ?? "") ?? .requested,
        officeNote: office_note ?? "",
        createdAt: parseTimestamp(created_at) ?? Date())
    }
  }

  static func body(for r: MaterialRequest) -> [String: Any] {
    var dict: [String: Any] = [
      "id": r.id.uuidString.lowercased(),
      "user_id": r.userId.uuidString.lowercased(),
      "site_id": r.siteId.uuidString.lowercased(),
      "description": r.description,
      "quantity": r.quantity,
      "status": r.status.rawValue,
      "office_note": r.officeNote,
      "created_at": timestamp.string(from: r.createdAt),
    ]
    if let a = r.allocationId { dict["allocation_id"] = a.uuidString.lowercased() }
    if let n = r.neededBy { dict["needed_by"] = dateOnly.string(from: n) }
    return dict
  }

  static func loadMaterialRequests(token: String) async throws -> [MaterialRequest] {
    let data = try await SupabaseClient.shared.get(
      table: "material_requests", query: "select=*&order=created_at.desc&limit=200",
      accessToken: token)
    return try JSONDecoder().decode([MaterialRequestRow].self, from: data).compactMap { $0.model }
  }

  static func save(_ r: MaterialRequest, token: String) async throws {
    try await SupabaseClient.shared.upsert(
      table: "material_requests", body: try encode(body(for: r)), accessToken: token)
  }

  static func operation(for r: MaterialRequest) -> SyncOperation? {
    guard let data = try? encode(body(for: r)) else { return nil }
    return SyncOperation(
      table: "material_requests", method: .upsert, bodyData: data,
      label: "Materials — \(r.description.prefix(30))")
  }
}
