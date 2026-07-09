import Foundation

/// Calls the deployed `delete-account` Supabase Edge Function, which uses the
/// server-side service-role key to permanently delete the signed-in user's auth
/// account and cascaded data. The app only sends the user's Supabase access
/// token (JWT); the service-role key never leaves the server.
enum AccountService {

  private struct DeleteResponse: Decodable { let deleted: Bool? }

  /// Permanently deletes the account identified by the caller's access token.
  /// - Parameter token: The signed-in user's Supabase access token.
  static func deleteAccount(token: String) async throws {
    guard let base = SupabaseConfig.url?.appendingPathComponent("functions/v1"),
      let key = SupabaseConfig.anonKey
    else {
      throw SupabaseError.notConfigured
    }

    var req = URLRequest(url: base.appendingPathComponent("delete-account"))
    req.httpMethod = "POST"
    req.timeoutInterval = 30
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.setValue(key, forHTTPHeaderField: "apikey")
    req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    req.httpBody = try JSONSerialization.data(withJSONObject: [String: String]())

    let (data, response) = try await URLSession.shared.data(for: req)
    try SupabaseClient.validate(response, data: data)
    _ = try? JSONDecoder().decode(DeleteResponse.self, from: data)
  }
}
