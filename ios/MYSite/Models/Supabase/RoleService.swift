import Foundation

/// A pending or decided request from a user to be upgraded to Site Manager or Admin.
struct RoleRequest: Identifiable, Decodable, Equatable {
  let id: UUID
  let userId: UUID
  let requestedRole: UserRole
  let status: String
  let note: String
  let createdAt: Date?

  enum CodingKeys: String, CodingKey {
    case id
    case userId = "user_id"
    case requestedRole = "requested_role"
    case status
    case note
    case createdAt = "created_at"
  }

  var isPending: Bool { status == "Pending" }
}

/// An invite code created by an admin, granting a role when redeemed.
struct RoleInvite: Identifiable, Decodable, Equatable {
  let id: UUID
  let code: String
  let role: UserRole
  let expiresAt: Date?
  let usedBy: UUID?
  let revoked: Bool

  enum CodingKeys: String, CodingKey {
    case id, code, role, revoked
    case expiresAt = "expires_at"
    case usedBy = "used_by"
  }

  var isRedeemed: Bool { usedBy != nil }
  var isExpired: Bool { (expiresAt ?? .distantFuture) < Date() }

  var statusLabel: String {
    if revoked { return "Revoked" }
    if isRedeemed { return "Used" }
    if isExpired { return "Expired" }
    return "Active"
  }
}

/// Role authorisation: invite codes and upgrade requests.
///
/// Every operation here is a Postgres function call, not a table write. Roles
/// are deliberately not writable from the client — a database trigger rejects
/// any change to `profiles.role` that doesn't come from an admin or from one
/// of these audited functions. See migration 0004.
enum RoleService {

  // MARK: - Invites (admin)

  /// Creates a single-use invite code for the given role. Admin only.
  static func createInvite(role: UserRole, expiresInDays: Int = 7, token: String) async throws
    -> String
  {
    let body = try JSONSerialization.data(withJSONObject: [
      "p_role": role.rawValue,
      "p_expires_days": expiresInDays,
    ])
    let data = try await SupabaseClient.shared.rpc(
      "create_role_invite", body: body, accessToken: token)
    // The function returns a bare JSON string, e.g. "MPG-K7P4-N2WX".
    if let code = try? JSONDecoder().decode(String.self, from: data) { return code }
    throw SupabaseError.decoding("Couldn't read the invite code.")
  }

  /// All invites this admin can see, newest first.
  static func invites(token: String) async throws -> [RoleInvite] {
    let data = try await SupabaseClient.shared.get(
      table: "role_invites", query: "select=*&order=created_at.desc", accessToken: token)
    return (try? decoder.decode([RoleInvite].self, from: data)) ?? []
  }

  /// Revokes an unused invite so it can no longer be redeemed.
  static func revokeInvite(id: UUID, token: String) async throws {
    let body = try JSONEncoder().encode(["revoked": true])
    try await SupabaseClient.shared.patch(
      table: "role_invites", query: "id=eq.\(id.uuidString.lowercased())", body: body,
      accessToken: token)
  }

  // MARK: - Redeeming (any signed-in user)

  /// Redeems a code and returns the role just granted.
  static func redeemInvite(code: String, token: String) async throws -> UserRole {
    let body = try JSONSerialization.data(withJSONObject: ["p_code": code])
    let data = try await SupabaseClient.shared.rpc(
      "redeem_role_invite", body: body, accessToken: token)
    guard let raw = try? JSONDecoder().decode(String.self, from: data),
      let role = UserRole(rawValue: raw)
    else {
      throw SupabaseError.decoding("Couldn't read the granted role.")
    }
    return role
  }

  // MARK: - Requests

  /// Files a request to be upgraded. One open request per person.
  static func requestRole(_ role: UserRole, note: String = "", token: String) async throws {
    let body = try JSONSerialization.data(withJSONObject: [
      "p_role": role.rawValue,
      "p_note": note,
    ])
    _ = try await SupabaseClient.shared.rpc("request_role", body: body, accessToken: token)
  }

  /// The signed-in user's own requests (RLS limits this to their rows).
  static func myRequests(token: String) async throws -> [RoleRequest] {
    let data = try await SupabaseClient.shared.get(
      table: "role_requests", query: "select=*&order=created_at.desc", accessToken: token)
    return (try? decoder.decode([RoleRequest].self, from: data)) ?? []
  }

  /// Every pending request. Admins see all rows; others see only their own.
  static func pendingRequests(token: String) async throws -> [RoleRequest] {
    let data = try await SupabaseClient.shared.get(
      table: "role_requests",
      query: "select=*&status=eq.Pending&order=created_at.desc", accessToken: token)
    return (try? decoder.decode([RoleRequest].self, from: data)) ?? []
  }

  /// Approves or declines a request. Approving applies the role server-side.
  static func decide(requestId: UUID, approve: Bool, token: String) async throws {
    let body = try JSONSerialization.data(withJSONObject: [
      "p_id": requestId.uuidString.lowercased(),
      "p_approve": approve,
    ])
    _ = try await SupabaseClient.shared.rpc("decide_role_request", body: body, accessToken: token)
  }

  // MARK: - Decoding

  private static let decoder: JSONDecoder = {
    let d = JSONDecoder()
    d.dateDecodingStrategy = .custom { decoder in
      let raw = try decoder.singleValueContainer().decode(String.self)
      let iso = ISO8601DateFormatter()
      iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
      if let date = iso.date(from: raw) { return date }
      iso.formatOptions = [.withInternetDateTime]
      return iso.date(from: raw) ?? Date()
    }
    return d
  }()
}
