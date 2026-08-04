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
  /// Where a password-reset email sends the user. Must also be listed under
  /// Supabase → Authentication → URL Configuration → Redirect URLs, or the
  /// auth server refuses to redirect there and the link dead-ends.
  static let passwordResetURL = "\(callbackScheme)://reset-password"

  /// Client-safe public defaults baked into the app so device / TestFlight / App Store
  /// builds work even when no environment variables or Info.plist build settings are
  /// present. These are the public project URL + publishable (anon) key ONLY — both are
  /// designed to ship inside the client. Never put the service_role key or any secret here.
  private static let defaultURL = "https://jzzsatsmdmckgjllohst.supabase.co"
  /// Publishable / anon key. Safe to ship. Populate this with your project's public key.
  private static let defaultAnonKey = "sb_publishable_aLr4R2Og756SVAe-0vX7DA_p5hrv7xl"

  static var url: URL? {
    if let raw = value(for: "SUPABASE_URL"), let u = URL(string: raw) { return u }
    return URL(string: defaultURL)
  }

  static var anonKey: String? {
    if let raw = value(for: "SUPABASE_PUBLISHABLE_KEY") ?? value(for: "SUPABASE_ANON_KEY"),
      !raw.isEmpty
    {
      return raw
    }
    return defaultAnonKey.isEmpty ? nil : defaultAnonKey
  }
  static var isConfigured: Bool { url != nil && (anonKey?.isEmpty == false) }

  static var authBaseURL: URL? { url?.appendingPathComponent("auth/v1") }
  static var restBaseURL: URL? { url?.appendingPathComponent("rest/v1") }
  static var storageBaseURL: URL? { url?.appendingPathComponent("storage/v1") }

  /// Private bucket holding all site evidence (photos, receipts, supplier invoices).
  static let evidenceBucket = "site-evidence"

  private static func value(for key: String) -> String? {
    // 1. Development: environment variables injected by Xcode / the 10x simulator.
    if let raw = ProcessInfo.processInfo.environment[key]?.trimmingCharacters(
      in: .whitespacesAndNewlines), !raw.isEmpty
    {
      return raw
    }
    // 2. Shipped builds (TestFlight / App Store): read the public value baked into
    //    the app bundle. These are the client-safe URL + publishable key only —
    //    never the service_role key or any admin secret.
    let infoKey: String?
    switch key {
    case "SUPABASE_URL": infoKey = "SupabaseURL"
    case "SUPABASE_PUBLISHABLE_KEY", "SUPABASE_ANON_KEY": infoKey = "SupabasePublishableKey"
    default: infoKey = nil
    }
    if let infoKey,
      let raw = (Bundle.main.object(forInfoDictionaryKey: infoKey) as? String)?
        .trimmingCharacters(in: .whitespacesAndNewlines),
      !raw.isEmpty, !raw.hasPrefix("$(")
    {
      return raw
    }
    return nil
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
