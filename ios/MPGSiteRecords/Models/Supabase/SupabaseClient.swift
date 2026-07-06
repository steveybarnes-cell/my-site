import Foundation

/// A persisted Supabase auth session (Codable for Keychain storage).
struct SupabaseSession: Codable, Equatable {
  var accessToken: String
  var refreshToken: String
  var expiresAt: Date
  var userId: String
  var email: String?

  var isExpired: Bool { Date() >= expiresAt.addingTimeInterval(-60) }
}

/// Auth user payload returned by GoTrue.
struct AuthUser: Codable {
  let id: String
  let email: String?
}

/// Raw token response from GoTrue `/token` and `/signup`.
private struct TokenResponse: Decodable {
  let accessToken: String
  let refreshToken: String
  let expiresIn: Double?
  let expiresAt: Double?
  let user: AuthUser?

  enum CodingKeys: String, CodingKey {
    case accessToken = "access_token"
    case refreshToken = "refresh_token"
    case expiresIn = "expires_in"
    case expiresAt = "expires_at"
    case user
  }

  var session: SupabaseSession {
    let expiry: Date
    if let absolute = expiresAt {
      expiry = Date(timeIntervalSince1970: absolute)
    } else {
      expiry = Date().addingTimeInterval(expiresIn ?? 3600)
    }
    return SupabaseSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiry,
      userId: user?.id ?? "",
      email: user?.email)
  }
}

/// Low-level Supabase GoTrue (auth) + PostgREST client using URLSession.
/// Handles real session creation, refresh, sign-out and authenticated reads.
struct SupabaseClient {
  static let shared = SupabaseClient()

  private let session = URLSession.shared

  // MARK: - Auth

  /// Email + password sign-in.
  func signIn(email: String, password: String) async throws -> SupabaseSession {
    try await token(grant: "password", body: ["email": email, "password": password])
  }

  /// Email + password sign-up (a profile row is auto-created by the DB trigger).
  func signUp(email: String, password: String) async throws -> SupabaseSession {
    guard let base = SupabaseConfig.authBaseURL, let key = SupabaseConfig.anonKey else {
      throw SupabaseError.notConfigured
    }
    let url = base.appendingPathComponent("signup")
    let data = try await post(url: url, apiKey: key, body: ["email": email, "password": password])
    return try decodeSession(data)
  }

  /// Refresh an access token using the stored refresh token.
  func refresh(refreshToken: String) async throws -> SupabaseSession {
    try await token(grant: "refresh_token", body: ["refresh_token": refreshToken])
  }

  /// Exchange an OAuth callback's tokens (parsed from the redirect fragment) for a session,
  /// then hydrate the user id/email from the auth server.
  func session(fromCallbackTokens accessToken: String, refreshToken: String, expiresIn: Double)
    async throws -> SupabaseSession
  {
    let user = try await user(accessToken: accessToken)
    return SupabaseSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: Date().addingTimeInterval(expiresIn),
      userId: user.id,
      email: user.email)
  }

  /// Revoke the current session server-side.
  func signOut(accessToken: String) async {
    guard let base = SupabaseConfig.authBaseURL, let key = SupabaseConfig.anonKey else { return }
    let url = base.appendingPathComponent("logout")
    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.setValue(key, forHTTPHeaderField: "apikey")
    req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    _ = try? await session.data(for: req)
  }

  /// Fetch the auth user for an access token.
  func user(accessToken: String) async throws -> AuthUser {
    guard let base = SupabaseConfig.authBaseURL, let key = SupabaseConfig.anonKey else {
      throw SupabaseError.notConfigured
    }
    var req = URLRequest(url: base.appendingPathComponent("user"))
    req.setValue(key, forHTTPHeaderField: "apikey")
    req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    let (data, response) = try await session.data(for: req)
    try Self.validate(response, data: data)
    do {
      return try JSONDecoder().decode(AuthUser.self, from: data)
    } catch {
      throw SupabaseError.decoding("\(error)")
    }
  }

  // MARK: - Data (PostgREST)

  /// Authenticated GET against a table with an optional query string (RLS applies).
  func get(table: String, query: String, accessToken: String) async throws -> Data {
    guard let base = SupabaseConfig.restBaseURL, let key = SupabaseConfig.anonKey else {
      throw SupabaseError.notConfigured
    }
    var comps = URLComponents(
      url: base.appendingPathComponent(table), resolvingAgainstBaseURL: false)!
    if !query.isEmpty { comps.query = query }
    var req = URLRequest(url: comps.url!)
    req.setValue(key, forHTTPHeaderField: "apikey")
    req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    let (data, response) = try await session.data(for: req)
    try Self.validate(response, data: data)
    return data
  }

  /// Authenticated upsert (POST with merge-duplicates) of encoded rows. RLS applies.
  /// Pass the raw JSON body for one or more rows.
  func upsert(table: String, body: Data, accessToken: String) async throws {
    try await write(
      table: table, query: "", method: "POST", body: body, accessToken: accessToken,
      prefer: "resolution=merge-duplicates,return=minimal")
  }

  /// Authenticated PATCH of matching rows with an encoded partial body. RLS applies.
  func patch(table: String, query: String, body: Data, accessToken: String) async throws {
    try await write(
      table: table, query: query, method: "PATCH", body: body,
      accessToken: accessToken, prefer: "return=minimal")
  }

  private func write(
    table: String, query: String, method: String, body: Data, accessToken: String, prefer: String
  ) async throws {
    guard let base = SupabaseConfig.restBaseURL, let key = SupabaseConfig.anonKey else {
      throw SupabaseError.notConfigured
    }
    var comps = URLComponents(
      url: base.appendingPathComponent(table), resolvingAgainstBaseURL: false)!
    if !query.isEmpty { comps.query = query }
    var req = URLRequest(url: comps.url!)
    req.httpMethod = method
    req.setValue(key, forHTTPHeaderField: "apikey")
    req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.setValue(prefer, forHTTPHeaderField: "Prefer")
    req.httpBody = body
    let (data, response) = try await session.data(for: req)
    try Self.validate(response, data: data)
  }

  // MARK: - Internals

  private func token(grant: String, body: [String: String]) async throws -> SupabaseSession {
    guard let base = SupabaseConfig.authBaseURL, let key = SupabaseConfig.anonKey else {
      throw SupabaseError.notConfigured
    }
    var comps = URLComponents(
      url: base.appendingPathComponent("token"), resolvingAgainstBaseURL: false)!
    comps.queryItems = [URLQueryItem(name: "grant_type", value: grant)]
    let data = try await post(url: comps.url!, apiKey: key, body: body)
    return try decodeSession(data)
  }

  private func post(url: URL, apiKey: String, body: [String: String]) async throws -> Data {
    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.setValue(apiKey, forHTTPHeaderField: "apikey")
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.httpBody = try JSONSerialization.data(withJSONObject: body)
    let (data, response) = try await session.data(for: req)
    try Self.validate(response, data: data)
    return data
  }

  private func decodeSession(_ data: Data) throws -> SupabaseSession {
    do {
      return try JSONDecoder().decode(SupabaseSession.self, from: data)
    } catch {
      throw SupabaseError.decoding("\(error)")
    }
  }

  static func validate(_ response: URLResponse, data: Data) throws {
    guard let http = response as? HTTPURLResponse else { throw SupabaseError.invalidResponse }
    guard (200..<300).contains(http.statusCode) else {
      let message = Self.extractMessage(from: data) ?? "Request failed (\(http.statusCode))."
      throw SupabaseError.http(status: http.statusCode, message: message)
    }
  }

  private static func extractMessage(from data: Data) -> String? {
    guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      return nil
    }
    return (obj["error_description"] as? String)
      ?? (obj["msg"] as? String)
      ?? (obj["message"] as? String)
      ?? (obj["error"] as? String)
  }
}
