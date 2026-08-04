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

// MARK: - Onboarding
// =====================================================================

/// Someone who has created an account but hasn't been attached to a company
/// yet. Until an admin adopts them they can sign in but see nothing, because
/// every row in the database is scoped to a company.
struct PendingSignup: Identifiable, Decodable, Equatable {
  let id: UUID
  let name: String?
  let email: String?
  let createdAt: Date?

  enum CodingKeys: String, CodingKey {
    case id, name, email
    case createdAt = "created_at"
  }

  /// Signups made through the web form sometimes arrive with a blank name, so
  /// fall back to the email rather than showing an empty row.
  var displayName: String {
    let trimmed = (name ?? "").trimmingCharacters(in: .whitespaces)
    if !trimmed.isEmpty { return trimmed }
    return email ?? "Unnamed account"
  }
}

/// A profile row inside the caller's own company.
struct CompanyMember: Identifiable, Decodable, Equatable {
  let id: UUID
  let name: String?
  let email: String?
  let role: UserRole
  let active: Bool?

  var displayName: String {
    let trimmed = (name ?? "").trimmingCharacters(in: .whitespaces)
    if !trimmed.isEmpty { return trimmed }
    return email ?? "Unnamed account"
  }
}

/// Letting new signups in, and changing the role of people already in.
///
/// Both writes are Postgres functions, not table updates. That matters more
/// than it looks: the RLS policy on `profiles` scopes rows to the caller's
/// company, and a brand-new signup has no company — so a plain `update` matches
/// zero rows and reports success while doing nothing. The functions raise a
/// specific error instead, which is what the screens below display.
enum OnboardingService {

  /// Everyone waiting to be let into a company. Admins only; the view returns
  /// nothing for anyone else.
  static func pendingSignups(token: String) async throws -> [PendingSignup] {
    let data = try await SupabaseClient.shared.get(
      table: "pending_signups", query: "select=*&order=created_at.desc", accessToken: token)
    return (try? decoder.decode([PendingSignup].self, from: data)) ?? []
  }

  /// Everyone already in the caller's company.
  static func members(token: String) async throws -> [CompanyMember] {
    let data = try await SupabaseClient.shared.get(
      table: "profiles",
      query: "select=id,name,email,role,active&order=name.asc", accessToken: token)
    return (try? decoder.decode([CompanyMember].self, from: data)) ?? []
  }

  /// Adds a signup to the caller's company with the given role.
  static func adopt(user: UUID, role: UserRole, token: String) async throws {
    let body = try JSONSerialization.data(withJSONObject: [
      "p_user": user.uuidString.lowercased(),
      "p_role": role.rawValue,
    ])
    _ = try await SupabaseClient.shared.rpc(
      "adopt_user_into_company", body: body, accessToken: token)
  }

  /// Changes the role of someone already in the caller's company.
  static func setRole(user: UUID, role: UserRole, token: String) async throws {
    let body = try JSONSerialization.data(withJSONObject: [
      "p_user": user.uuidString.lowercased(),
      "p_role": role.rawValue,
    ])
    _ = try await SupabaseClient.shared.rpc("set_user_role", body: body, accessToken: token)
  }

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

// MARK: - Signing a firm up
// =====================================================================

extension OnboardingService {

  /// What the app needs before it can decide which screen to show.
  ///
  /// Asked through a function rather than read from `companies`, because the
  /// select policy on that table scopes rows to your own company — which is
  /// precisely the thing a new signup doesn't have yet.
  struct MyState: Decodable, Equatable {
    let hasCompany: Bool
    let companyName: String?
    let role: UserRole?
    let needsHubdoc: Bool

    enum CodingKeys: String, CodingKey {
      case hasCompany = "has_company"
      case companyName = "company_name"
      case role
      case needsHubdoc = "needs_hubdoc"
    }

    static let unknown = MyState(
      hasCompany: false, companyName: nil, role: nil, needsHubdoc: false)
  }

  /// Whether this account belongs to a company yet, and what it still needs.
  static func myState(token: String) async throws -> MyState {
    let body = try JSONSerialization.data(withJSONObject: [String: String]())
    let data = try await SupabaseClient.shared.rpc(
      "my_onboarding_state", body: body, accessToken: token)
    let rows = (try? JSONDecoder().decode([MyState].self, from: data)) ?? []
    return rows.first ?? .unknown
  }

  /// Creates a company and makes the caller its admin.
  ///
  /// Only works for an account that doesn't already belong to one — the
  /// database refuses otherwise, because leaving a company would strand every
  /// record the person had created in it.
  static func createCompany(
    name: String, hubdocEmail: String, token: String
  ) async throws {
    var args: [String: Any] = ["p_name": name]
    // Sent as a real null rather than "" so the column stays null and the
    // "needs a Hubdoc address" prompt keeps firing.
    let trimmed = hubdocEmail.trimmingCharacters(in: .whitespaces)
    args["p_hubdoc_email"] = trimmed.isEmpty ? NSNull() : trimmed
    let body = try JSONSerialization.data(withJSONObject: args)
    _ = try await SupabaseClient.shared.rpc("create_company", body: body, accessToken: token)
  }
}
