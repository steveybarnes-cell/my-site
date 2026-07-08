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
