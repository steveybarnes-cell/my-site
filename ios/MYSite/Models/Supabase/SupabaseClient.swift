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

  /// A URLSession with tight timeouts so a slow / unreachable network can never
  /// hang a request indefinitely. The default `URLSession.shared` waits up to 60s,
  /// which can leave launch stuck on the "restoring" spinner long enough for iOS
  /// to fire the 0x8BADF00D watchdog kill when the app is backgrounded.
  private let session: URLSession = {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = 15
    config.timeoutIntervalForResource = 25
    config.waitsForConnectivity = false
    return URLSession(configuration: config)
  }()

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

  /// Exchanges a native identity token (Sign in with Apple) for a Supabase
  /// session. `nonce` is the raw nonce whose SHA-256 was put in the request.
  func signInWithIdToken(provider: String, idToken: String, nonce: String) async throws
    -> SupabaseSession
  {
    try await token(
      grant: "id_token", body: ["provider": provider, "id_token": idToken, "nonce": nonce])
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

  /// Sends a password recovery email.
  ///
  /// The auth server answers 200 whether or not the address is registered, so
  /// this can't be used to discover who has an account — the UI says the same
  /// thing either way to preserve that.
  func sendPasswordReset(email: String, redirectTo: String) async throws {
    guard let base = SupabaseConfig.authBaseURL, let key = SupabaseConfig.anonKey else {
      throw SupabaseError.notConfigured
    }
    var comps = URLComponents(
      url: base.appendingPathComponent("recover"), resolvingAgainstBaseURL: false)!
    comps.queryItems = [URLQueryItem(name: "redirect_to", value: redirectTo)]
    _ = try await post(url: comps.url!, apiKey: key, body: ["email": email])
  }

  /// Sets a new password for the user owning `accessToken`.
  func updatePassword(_ newPassword: String, accessToken: String) async throws {
    guard let base = SupabaseConfig.authBaseURL, let key = SupabaseConfig.anonKey else {
      throw SupabaseError.notConfigured
    }
    var req = URLRequest(url: base.appendingPathComponent("user"))
    req.httpMethod = "PUT"
    req.setValue(key, forHTTPHeaderField: "apikey")
    req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.httpBody = try JSONSerialization.data(withJSONObject: ["password": newPassword])
    let (data, response) = try await session.data(for: req)
    try Self.validate(response, data: data)
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

  /// Call a Postgres function via PostgREST RPC. Used for anything that must be
  /// enforced server-side rather than trusted from the client — role changes in
  /// particular. `body` is the encoded argument object, or nil for no arguments.
  func rpc(_ function: String, body: Data? = nil, accessToken: String) async throws -> Data {
    guard let base = SupabaseConfig.restBaseURL, let key = SupabaseConfig.anonKey else {
      throw SupabaseError.notConfigured
    }
    var req = URLRequest(url: base.appendingPathComponent("rpc").appendingPathComponent(function))
    req.httpMethod = "POST"
    req.setValue(key, forHTTPHeaderField: "apikey")
    req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.httpBody = body ?? Data("{}".utf8)
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

  /// Deletes the rows matching `query` (PostgREST filter, e.g. `id=eq.<uuid>`).
  func delete(table: String, query: String, accessToken: String) async throws {
    try await write(
      table: table, query: query, method: "DELETE", body: Data(),
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

  /// Decodes a GoTrue token payload into a session.
  ///
  /// This must go through `TokenResponse`, not `SupabaseSession` directly:
  /// GoTrue returns snake_case (`access_token`, `refresh_token`, `expires_in`),
  /// whereas `SupabaseSession` is the app's own camelCase model used for
  /// Keychain storage. Decoding the server payload straight into
  /// `SupabaseSession` fails with `keyNotFound: "accessToken"`.
  private func decodeSession(_ data: Data) throws -> SupabaseSession {
    do {
      return try JSONDecoder().decode(TokenResponse.self, from: data).session
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
