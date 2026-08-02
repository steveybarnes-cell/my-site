import Foundation

/// Turns a free-spoken transcript ("started at half seven, finished about four,
/// second-fix plastering on the east wall, waiting on the sparky") into the
/// structured fields of a Daily Site Record. Fully local and deterministic so it
/// works offline with no API cost; the tradesman always reviews the result
/// before saving.
enum DailyRecordParser {

  struct Result {
    var startTime: String?
    var finishTime: String?
    var breakMinutes: Int?
    var category: WorkCategory?
    var delay: DelayReason?
    var delayNote: String?
    /// Cleaned description with recognised meta phrases kept as-is.
    var description: String
  }

  static func parse(_ raw: String) -> Result {
    let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    let lower = text.lowercased()

    let times = extractTimes(from: lower)
    return Result(
      startTime: times.start,
      finishTime: times.finish,
      breakMinutes: extractBreak(from: lower),
      category: extractCategory(from: lower),
      delay: extractDelay(from: lower).reason,
      delayNote: extractDelay(from: lower).note,
      description: cleanedDescription(text))
  }

  // MARK: - Times

  private static func extractTimes(from lower: String) -> (start: String?, finish: String?) {
    // Find all HH:MM-style or spoken times in order; first = start, last = finish.
    var found: [(index: Int, time: String)] = []

    // Digital "8:00", "16.30", "8am", "4 pm"
    let digital = #"(\d{1,2})[:.\s]?(\d{2})?\s*(am|pm)?"#
    if let re = try? NSRegularExpression(pattern: digital) {
      let ns = lower as NSString
      re.enumerateMatches(in: lower, range: NSRange(location: 0, length: ns.length)) { m, _, _ in
        guard let m else { return }
        let hourStr = ns.substring(with: m.range(at: 1))
        guard var hour = Int(hourStr), hour <= 24 else { return }
        var minute = 0
        if m.range(at: 2).location != NSNotFound {
          minute = Int(ns.substring(with: m.range(at: 2))) ?? 0
        }
        let ampm =
          m.range(at: 3).location != NSNotFound ? ns.substring(with: m.range(at: 3)) : ""
        // Skip bare numbers that are clearly not times unless an am/pm anchors them.
        if m.range(at: 2).location == NSNotFound && ampm.isEmpty { return }
        if ampm == "pm" && hour < 12 { hour += 12 }
        if ampm == "am" && hour == 12 { hour = 0 }
        guard minute < 60, hour <= 24 else { return }
        found.append((m.range.location, String(format: "%02d:%02d", hour, minute)))
      }
    }

    found.sort { $0.index < $1.index }
    guard let first = found.first else { return (nil, nil) }
    let start = first.time
    let finish = found.count > 1 ? found.last?.time : nil
    return (start, finish)
  }

  private static func extractBreak(from lower: String) -> Int? {
    if lower.contains("no break") || lower.contains("no lunch") { return 0 }
    // "half hour break", "30 minute lunch", "45 min break", "1 hour break"
    if let re = try? NSRegularExpression(
      pattern: #"(\d{1,3})\s*(min|minute|minutes)\s*(break|lunch|dinner)"#)
    {
      let ns = lower as NSString
      if let m = re.firstMatch(in: lower, range: NSRange(location: 0, length: ns.length)),
        let v = Int(ns.substring(with: m.range(at: 1)))
      {
        return min(180, v)
      }
    }
    if lower.contains("half hour") && (lower.contains("break") || lower.contains("lunch")) {
      return 30
    }
    if lower.contains("hour")
      && (lower.contains("lunch break") || lower.contains("hour break")
        || lower.contains("hour lunch"))
    {
      return 60
    }
    return nil
  }

  // MARK: - Category

  private static func extractCategory(from lower: String) -> WorkCategory? {
    if lower.contains("variation") || lower.contains("extra work")
      || lower.contains("additional work") || lower.contains("day work")
      || lower.contains("dayworks")
    {
      return .variation
    }
    if lower.contains("snag") { return .snagging }
    if lower.contains("call out") || lower.contains("callout") || lower.contains("emergency") {
      return .callOut
    }
    if lower.contains("remedial") || lower.contains("put right") || lower.contains("rework") {
      return .remedial
    }
    return nil
  }

  // MARK: - Delay

  private static func extractDelay(from lower: String) -> (reason: DelayReason?, note: String?) {
    let hasDelayWord =
      lower.contains("delay") || lower.contains("held up") || lower.contains("waiting")
      || lower.contains("stopped") || lower.contains("couldn't")

    if lower.contains("weather") || lower.contains("rain") || lower.contains("snow")
      || lower.contains("frost") || lower.contains("wind")
    {
      return (.weather, "Weather affected work on site.")
    }
    if lower.contains("waiting for material") || lower.contains("no materials")
      || lower.contains("materials didn") || lower.contains("materials not")
    {
      return (.materials, "Waiting on materials.")
    }
    if lower.contains("waiting for the client") || lower.contains("waiting on the client")
      || lower.contains("client hasn") || lower.contains("client not")
    {
      return (.client, "Waiting on the client.")
    }
    if lower.contains("drawing") { return (.drawings, "Waiting on drawings.") }
    if lower.contains("spark") || lower.contains("electrician") || lower.contains("plumber")
      || lower.contains("other trade") || lower.contains("another trade")
      || lower.contains("chippy") || lower.contains("brickie")
    {
      return (.otherTrade, "Waiting on another trade.")
    }
    // A delay was clearly reported but no specific cause matched above. This
    // must be recorded as `.other` rather than Optional.none — returning nil
    // would drop the delay entirely and keep it out of the delay register.
    if hasDelayWord {
      return (DelayReason.other, "Delay reported — cause not specified.")
    }
    return (nil, nil)
  }

  // MARK: - Description

  private static func cleanedDescription(_ text: String) -> String {
    guard !text.isEmpty else { return "" }
    var s = text
    // Capitalise the first letter for a tidy record.
    s = s.prefix(1).uppercased() + s.dropFirst()
    if let last = s.last, ![".", "!", "?"].contains(last) { s += "." }
    return s
  }
}
