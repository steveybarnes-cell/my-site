import Foundation

/// Tidies a rough site note into something that reads properly in the log.
///
/// Every failure returns the original text rather than throwing. A man who has
/// just typed out his day must never lose it because a tidy-up button had a bad
/// afternoon — so the worst case here is that nothing changes.
enum TidyNoteService {

  struct Result {
    let text: String
    let changed: Bool
    /// Why nothing changed, when nothing changed. Shown to the user only when
    /// it is something they can act on.
    let reason: String?
  }

  private struct Envelope: Decodable {
    let tidied: String?
    let changed: Bool?
    let reason: String?
  }

  static func tidy(_ text: String, token: String) async -> Result {
    let original = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard
      let base = SupabaseConfig.url?.appendingPathComponent("functions/v1"),
      let key = SupabaseConfig.anonKey,
      !original.isEmpty
    else {
      return Result(text: original, changed: false, reason: "not_configured")
    }

    var req = URLRequest(url: base.appendingPathComponent("tidy-note"))
    req.httpMethod = "POST"
    req.timeoutInterval = 30
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.setValue(key, forHTTPHeaderField: "apikey")
    req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    req.httpBody = try? JSONSerialization.data(withJSONObject: ["text": original])

    do {
      let (data, _) = try await URLSession.shared.data(for: req)
      let decoded = try JSONDecoder().decode(Envelope.self, from: data)
      return Result(
        text: decoded.tidied?.isEmpty == false ? decoded.tidied! : original,
        changed: decoded.changed ?? false,
        reason: decoded.reason)
    } catch {
      return Result(text: original, changed: false, reason: "unreachable")
    }
  }

  /// Plain-English for the reasons worth telling somebody about. Everything
  /// else returns nil and stays quiet — "too_short" is not news.
  static func message(for reason: String?) -> String? {
    switch reason {
    case "no_credit": return "The AI account is out of credit, so nothing was changed."
    case "not_configured": return "AI tidy-up isn't set up yet."
    case "unreachable": return "Couldn't reach the AI just now. Your note is unchanged."
    case "reply_too_long": return "The AI wandered off, so your note was left as it was."
    default: return nil
    }
  }
}
