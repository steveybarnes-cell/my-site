import AuthenticationServices
import Foundation
import UIKit

/// Runs the Google sign-in flow through Supabase's hosted OAuth endpoint using
/// `ASWebAuthenticationSession`, then returns a real Supabase session.
///
/// Flow:
///   1. Open  {SUPABASE}/auth/v1/authorize?provider=google&redirect_to=<app scheme>
///   2. Supabase completes Google OAuth and redirects back to our app scheme with
///      access_token + refresh_token in the URL fragment.
///   3. We parse the fragment and hydrate a SupabaseSession.
@MainActor
final class OAuthFlow: NSObject, ASWebAuthenticationPresentationContextProviding {
  private var session: ASWebAuthenticationSession?

  func signInWithGoogle() async throws -> SupabaseSession {
    guard let authBase = SupabaseConfig.authBaseURL, SupabaseConfig.isConfigured else {
      throw SupabaseError.notConfigured
    }

    var comps = URLComponents(
      url: authBase.appendingPathComponent("authorize"), resolvingAgainstBaseURL: false)!
    comps.queryItems = [
      URLQueryItem(name: "provider", value: "google"),
      URLQueryItem(name: "redirect_to", value: SupabaseConfig.callbackURL),
    ]
    guard let authURL = comps.url else { throw SupabaseError.oauthFailed("Bad authorize URL.") }

    let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
      let webSession = ASWebAuthenticationSession(
        url: authURL, callbackURLScheme: SupabaseConfig.callbackScheme
      ) { url, error in
        if let error {
          let nsError = error as NSError
          if nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
            continuation.resume(throwing: SupabaseError.oauthCancelled)
          } else {
            continuation.resume(throwing: SupabaseError.oauthFailed(error.localizedDescription))
          }
          return
        }
        guard let url else {
          continuation.resume(throwing: SupabaseError.oauthFailed("No callback URL returned."))
          return
        }
        continuation.resume(returning: url)
      }
      webSession.presentationContextProvider = self
      webSession.prefersEphemeralWebBrowserSession = false
      self.session = webSession
      if !webSession.start() {
        continuation.resume(throwing: SupabaseError.oauthFailed("Couldn't start sign-in."))
      }
    }

    return try await makeSession(from: callbackURL)
  }

  private func makeSession(from url: URL) async throws -> SupabaseSession {
    // Tokens arrive in the URL fragment: #access_token=...&refresh_token=...&expires_in=...
    guard let fragment = URLComponents(url: url, resolvingAgainstBaseURL: false)?.fragment else {
      // Some errors come back as query params instead.
      if let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
        let desc = query.first(where: { $0.name == "error_description" })?.value
      {
        throw SupabaseError.oauthFailed(desc.replacingOccurrences(of: "+", with: " "))
      }
      throw SupabaseError.oauthFailed("No tokens returned from sign-in.")
    }

    var params: [String: String] = [:]
    for pair in fragment.split(separator: "&") {
      let kv = pair.split(separator: "=", maxSplits: 1).map(String.init)
      if kv.count == 2 {
        params[kv[0]] = kv[1].removingPercentEncoding ?? kv[1]
      }
    }

    if let desc = params["error_description"] {
      throw SupabaseError.oauthFailed(desc.replacingOccurrences(of: "+", with: " "))
    }
    guard let accessToken = params["access_token"], let refreshToken = params["refresh_token"] else {
      throw SupabaseError.oauthFailed("Sign-in didn't return a valid session.")
    }
    let expiresIn = Double(params["expires_in"] ?? "3600") ?? 3600

    return try await SupabaseClient.shared.session(
      fromCallbackTokens: accessToken, refreshToken: refreshToken, expiresIn: expiresIn)
  }

  func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
    let scene = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first { $0.activationState == .foregroundActive }
      ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    if let window = scene?.keyWindow {
      return window
    }
    if let scene {
      return UIWindow(windowScene: scene)
    }
    return ASPresentationAnchor(frame: .zero)
  }
}
