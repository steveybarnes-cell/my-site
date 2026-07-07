import AuthenticationServices
import Foundation
import UIKit

/// Talks to the deployed Supabase Edge Functions that make Xero live:
///   • `xero-oauth`        — starts the consent flow + stores tokens server-side
///   • `xero-push-invoice` — turns an approved submission into a draft Xero invoice
///
/// The Client Secret never touches the app — it lives as a backend secret and is
/// only used inside the Edge Functions. The app only ever holds the signed-in
/// user's Supabase access token (JWT), which authorises these calls.
@MainActor
final class XeroService: NSObject, ASWebAuthenticationPresentationContextProviding {

  static let shared = XeroService()

  private var webSession: ASWebAuthenticationSession?

  /// Base URL for Edge Functions, e.g. https://<ref>.supabase.co/functions/v1
  private var functionsBase: URL? {
    SupabaseConfig.url?.appendingPathComponent("functions/v1")
  }

  // MARK: - Line item wire model

  struct LineItem: Encodable {
    let description: String
    let quantity: Double
    let unitAmount: Double
    let accountCode: String?
  }

  struct PushResult: Decodable {
    let invoiceId: String?
    let invoiceNumber: String?
    let status: String?
  }

  private struct StartResponse: Decodable {
    let url: String
    let state: String?
  }

  // MARK: - Connect flow

  /// Opens Xero consent in a secure web session, then returns once Xero has
  /// redirected back into the app via `mpgsiterecords://xero-connected`.
  /// Throws on cancel/failure so the caller can surface a message.
  func connect(token: String) async throws {
    let start = try await requestStartURL(token: token)
    let callback = try await runConsent(consentURL: start)

    // Callback arrives as mpgsiterecords://xero-connected?status=connected|error
    let status =
      URLComponents(url: callback, resolvingAgainstBaseURL: false)?
      .queryItems?.first(where: { $0.name == "status" })?.value
    if status == "error" {
      throw SupabaseError.oauthFailed("Xero didn't complete the connection. Please try again.")
    }
  }

  private func requestStartURL(token: String) async throws -> URL {
    guard let base = functionsBase, let key = SupabaseConfig.anonKey else {
      throw SupabaseError.notConfigured
    }
    var req = URLRequest(url: base.appendingPathComponent("xero-oauth/start"))
    req.httpMethod = "GET"
    req.setValue(key, forHTTPHeaderField: "apikey")
    req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    let (data, response) = try await URLSession.shared.data(for: req)
    try SupabaseClient.validate(response, data: data)
    let decoded = try JSONDecoder().decode(StartResponse.self, from: data)
    guard let url = URL(string: decoded.url) else {
      throw SupabaseError.oauthFailed("Xero returned an invalid consent link.")
    }
    return url
  }

  private func runConsent(consentURL: URL) async throws -> URL {
    try await withCheckedThrowingContinuation { continuation in
      let session = ASWebAuthenticationSession(
        url: consentURL, callbackURLScheme: SupabaseConfig.callbackScheme
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
          continuation.resume(throwing: SupabaseError.oauthFailed("No callback from Xero."))
          return
        }
        continuation.resume(returning: url)
      }
      session.presentationContextProvider = self
      session.prefersEphemeralWebBrowserSession = false
      self.webSession = session
      if !session.start() {
        continuation.resume(throwing: SupabaseError.oauthFailed("Couldn't start the Xero flow."))
      }
    }
  }

  // MARK: - Push invoice

  /// Creates a draft ACCREC invoice in Xero from an approved submission.
  func pushInvoice(
    contactName: String, reference: String?, lineItems: [LineItem], token: String
  ) async throws -> PushResult {
    guard let base = functionsBase, let key = SupabaseConfig.anonKey else {
      throw SupabaseError.notConfigured
    }
    var req = URLRequest(url: base.appendingPathComponent("xero-push-invoice"))
    req.httpMethod = "POST"
    req.setValue(key, forHTTPHeaderField: "apikey")
    req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let body: [String: Any] = [
      "contactName": contactName,
      "reference": reference ?? "",
      "lineItems": lineItems.map {
        [
          "description": $0.description,
          "quantity": $0.quantity,
          "unitAmount": $0.unitAmount,
          "accountCode": $0.accountCode ?? "200",
        ]
      },
    ]
    req.httpBody = try JSONSerialization.data(withJSONObject: body)

    let (data, response) = try await URLSession.shared.data(for: req)
    try SupabaseClient.validate(response, data: data)
    return try JSONDecoder().decode(PushResult.self, from: data)
  }

  // MARK: - Presentation anchor

  func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
    let scene =
      UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first { $0.activationState == .foregroundActive }
      ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    if let window = scene?.keyWindow { return window }
    if let scene { return UIWindow(windowScene: scene) }
    return ASPresentationAnchor()
  }
}
