import Foundation

/// Calls the deployed `scan-receipt` Supabase Edge Function, which uses OpenAI
/// vision to read a receipt/supplier-invoice photo and return the supplier,
/// costs, VAT and purchase date. The OpenAI key stays server-side; the app only
/// sends the image bytes plus the signed-in user's Supabase access token (JWT).
enum ReceiptScanService {

  /// Structured details extracted from a receipt image.
  struct ScannedReceipt: Decodable {
    var supplier: String?
    var description: String?
    var costExVat: Double?
    var vatAmount: Double?
    var total: Double?
    var date: String?
    var confidence: Double?

    /// Parsed purchase date, if the model returned a recognisable ISO date.
    var purchaseDate: Date? {
      guard let date, !date.isEmpty else { return nil }
      let iso = DateFormatter()
      iso.locale = Locale(identifier: "en_US_POSIX")
      iso.dateFormat = "yyyy-MM-dd"
      return iso.date(from: date)
    }
  }

  private struct Envelope: Decodable { let result: ScannedReceipt }

  /// Sends the image to the Edge Function and returns the parsed details.
  /// - Parameters:
  ///   - imageData: JPEG/PNG bytes of the receipt photo.
  ///   - token: The signed-in user's Supabase access token.
  static func scan(imageData: Data, token: String) async throws -> ScannedReceipt {
    guard let base = SupabaseConfig.url?.appendingPathComponent("functions/v1"),
      let key = SupabaseConfig.anonKey
    else {
      throw SupabaseError.notConfigured
    }

    var req = URLRequest(url: base.appendingPathComponent("scan-receipt"))
    req.httpMethod = "POST"
    req.timeoutInterval = 60
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.setValue(key, forHTTPHeaderField: "apikey")
    req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

    let payload: [String: Any] = [
      "image": imageData.base64EncodedString(),
      "mimeType": "image/jpeg",
    ]
    req.httpBody = try JSONSerialization.data(withJSONObject: payload)

    let (data, response) = try await URLSession.shared.data(for: req)
    try SupabaseClient.validate(response, data: data)
    let decoded = try JSONDecoder().decode(Envelope.self, from: data)
    return decoded.result
  }
}

// =====================================================================
// MARK: - Hubdoc
// =====================================================================

/// Sends captured receipts to a company's Hubdoc inbox, and manages the
/// address they go to.
///
/// Hubdoc has no public API. Every Hubdoc organisation is given a unique
/// upload email address, and emailing a document there is the only supported
/// programmatic way in — so "send to Hubdoc" means an Edge Function emails the
/// receipt as an attachment. The address lives on the company row rather than
/// in the app, because one firm's receipts must never land in another's books.
enum HubdocService {

  /// What the settings screen needs: where receipts go and how it's been going.
  struct Settings: Decodable, Equatable {
    var hubdocEmail: String?
    var delivered: Int
    var failed: Int

    enum CodingKeys: String, CodingKey {
      case hubdocEmail = "hubdoc_email"
      case delivered, failed
    }

    static let none = Settings(hubdocEmail: nil, delivered: 0, failed: 0)
    var isConfigured: Bool { !(hubdocEmail ?? "").isEmpty }
  }

  /// Outcome of asking for one receipt to be sent.
  ///
  /// `notConfigured` and `alreadySent` are ordinary states, not failures — the
  /// first is every company that hasn't set Hubdoc up, and the second is a
  /// double-tap or a retry. Neither should show the user an error.
  enum Outcome: Equatable {
    case sent(to: String)
    case notConfigured
    case alreadySent
  }

  private struct SendResponse: Decodable {
    let sent: Bool
    let to: String?
    let reason: String?
  }

  /// Asks the backend to email a stored receipt to Hubdoc.
  /// - Parameter photoId: The `site_photos` row holding the receipt image.
  static func send(photoId: UUID, token: String) async throws -> Outcome {
    guard let base = SupabaseConfig.url?.appendingPathComponent("functions/v1"),
      let key = SupabaseConfig.anonKey
    else {
      throw SupabaseError.notConfigured
    }

    var req = URLRequest(url: base.appendingPathComponent("send-to-hubdoc"))
    req.httpMethod = "POST"
    // Generous: the function downloads the image and waits on an email
    // provider before answering.
    req.timeoutInterval = 45
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.setValue(key, forHTTPHeaderField: "apikey")
    req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    req.httpBody = try JSONSerialization.data(withJSONObject: [
      "photoId": photoId.uuidString.lowercased()
    ])

    let (data, response) = try await URLSession.shared.data(for: req)
    try SupabaseClient.validate(response, data: data)
    let decoded = try JSONDecoder().decode(SendResponse.self, from: data)

    if decoded.sent { return .sent(to: decoded.to ?? "Hubdoc") }
    return decoded.reason == "already_sent" ? .alreadySent : .notConfigured
  }

  /// Current Hubdoc address and delivery counts for the caller's company.
  static func settings(token: String) async throws -> Settings {
    let body = try JSONSerialization.data(withJSONObject: [String: String]())
    let data = try await SupabaseClient.shared.rpc(
      "hubdoc_settings", body: body, accessToken: token)
    // The function returns a set, so PostgREST answers with an array.
    let rows = (try? JSONDecoder().decode([Settings].self, from: data)) ?? []
    return rows.first ?? .none
  }

  /// Sets or clears the company's Hubdoc address. Admin only, enforced in the
  /// database — an empty string turns Hubdoc delivery off.
  static func setEmail(_ email: String, token: String) async throws {
    let body = try JSONSerialization.data(withJSONObject: ["p_email": email])
    _ = try await SupabaseClient.shared.rpc("set_hubdoc_email", body: body, accessToken: token)
  }
}
