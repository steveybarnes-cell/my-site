import Foundation

/// Uploads and reads real file bytes from the private `site-evidence` Storage bucket.
///
/// Object path convention mirrors the RLS policy in 0002_storage.sql:
///     <site_id>/<user_id>/<filename>
/// so the folder segments authorise access (segment 1 = site, segment 2 = owner).
enum SupabaseStorage {

  /// Builds the RLS-friendly object path for a piece of site evidence.
  static func objectPath(siteId: UUID, userId: UUID, fileName: String) -> String {
    "\(siteId.uuidString.lowercased())/\(userId.uuidString.lowercased())/\(fileName)"
  }

  /// Uploads bytes to the bucket and returns the stored object path.
  /// `upsert` overwrites any existing object at the same path.
  @discardableResult
  static func upload(
    data: Data, path: String, contentType: String = "image/jpeg", token: String
  ) async throws -> String {
    guard let base = SupabaseConfig.storageBaseURL, let key = SupabaseConfig.anonKey else {
      throw SupabaseError.notConfigured
    }
    let url =
      base
      .appendingPathComponent("object")
      .appendingPathComponent(SupabaseConfig.evidenceBucket)
      .appendingPathComponent(path)

    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.setValue(key, forHTTPHeaderField: "apikey")
    req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    req.setValue(contentType, forHTTPHeaderField: "Content-Type")
    req.setValue("true", forHTTPHeaderField: "x-upsert")
    req.httpBody = data

    let (respData, response) = try await URLSession.shared.data(for: req)
    try SupabaseClient.validate(response, data: respData)
    return path
  }

  private struct SignedURLResponse: Decodable {
    let signedURL: String
  }

  /// Creates a time-limited signed URL for a private object so the app can display it.
  /// `expiresIn` is in seconds (default 7 days).
  static func signedURL(path: String, expiresIn: Int = 604_800, token: String) async throws -> URL {
    guard let base = SupabaseConfig.storageBaseURL, let key = SupabaseConfig.anonKey,
      let siteBase = SupabaseConfig.url
    else { throw SupabaseError.notConfigured }

    let url =
      base
      .appendingPathComponent("object/sign")
      .appendingPathComponent(SupabaseConfig.evidenceBucket)
      .appendingPathComponent(path)

    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.setValue(key, forHTTPHeaderField: "apikey")
    req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.httpBody = try JSONSerialization.data(withJSONObject: ["expiresIn": expiresIn])

    let (data, response) = try await URLSession.shared.data(for: req)
    try SupabaseClient.validate(response, data: data)
    let decoded = try JSONDecoder().decode(SignedURLResponse.self, from: data)

    // The API returns a path like "/object/sign/site-evidence/...?token=..."
    let relative = decoded.signedURL.hasPrefix("/") ? String(decoded.signedURL.dropFirst()) : decoded.signedURL
    guard let full = URL(string: "storage/v1/\(relative)", relativeTo: siteBase)?.absoluteURL else {
      throw SupabaseError.invalidResponse
    }
    return full
  }
}
