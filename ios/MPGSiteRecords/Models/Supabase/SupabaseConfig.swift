import Foundation

/// Runtime configuration for the connected Supabase project.
///
/// Values are read from the process environment at launch:
///   • `SUPABASE_URL`               e.g. https://abcd1234.supabase.co
///   • `SUPABASE_PUBLISHABLE_KEY`   the public (anon / publishable) key — safe to ship in-app.
///
/// These are populated by the 10x Supabase integration. Never put the
/// service_role key, database password, or any admin secret in the app.
enum SupabaseConfig {
  /// Deep-link scheme used for the OAuth callback (must match Info.plist + Supabase redirect URLs).
  static let callbackScheme = "mpgsiterecords"
  static let callbackURL = "\(callbackScheme)://auth-callback"

  static var url: URL? {
    guard let raw = value(for: "SUPABASE_URL"), let u = URL(string: raw) else { return nil }
    return u
  }

  static var anonKey: String? {
    value(for: "SUPABASE_PUBLISHABLE_KEY") ?? value(for: "SUPABASE_ANON_KEY")
  }
  static var isConfigured: Bool { url != nil && (anonKey?.isEmpty == false) }

  static var authBaseURL: URL? { url?.appendingPathComponent("auth/v1") }
  static var restBaseURL: URL? { url?.appendingPathComponent("rest/v1") }
  static var storageBaseURL: URL? { url?.appendingPathComponent("storage/v1") }

  /// Private bucket holding all site evidence (photos, receipts, supplier invoices).
  static let evidenceBucket = "site-evidence"

  private static func value(for key: String) -> String? {
    guard
      let raw = ProcessInfo.processInfo.environment[key]?.trimmingCharacters(
        in: .whitespacesAndNewlines), !raw.isEmpty
    else { return nil }
    return raw
  }
}

/// Typed auth/data errors surfaced to the UI.
enum SupabaseError: LocalizedError, Equatable {
  case notConfigured
  case invalidResponse
  case http(status: Int, message: String)
  case decoding(String)
  case oauthCancelled
  case oauthFailed(String)
  case noSession

  var errorDescription: String? {
    switch self {
    case .notConfigured:
      return "The app isn't connected to Supabase yet. Add the Supabase integration to sign in."
    case .invalidResponse:
      return "The server returned an unexpected response. Please try again."
    case .http(_, let message):
      return message
    case .decoding(let detail):
      return "Couldn't read the server response. (\(detail))"
    case .oauthCancelled:
      return "Sign-in was cancelled."
    case .oauthFailed(let detail):
      return detail
    case .noSession:
      return "Your session has expired. Please sign in again."
    }
  }
}
