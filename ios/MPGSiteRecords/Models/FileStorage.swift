import Foundation

/// Local-first stand-in for the Google Drive + Google Sheets integration.
///
/// This models the exact behaviour the production backend will perform:
///  1. Build the Drive folder path:
///     `My Project Group - Site Record System / File Type / Site / Week Ending / Tradesman`
///  2. Auto-rename the file: `Date_Site_Tradesman_FileType_TaskID.ext`
///  3. Return a Drive file id + shareable URL.
///  4. Produce a "Photos & Files" sheet row for logging.
///
/// When Google OAuth + a backend (Drive API + Sheets API) are connected, replace
/// `upload(...)` with the real network calls — the folder/name/sheet contract stays identical.
enum FileStorage {

  static let rootFolder = "My Project Group - Site Record System"

  // MARK: - Naming helpers

  private static var fileDateFormatter: DateFormatter {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.locale = Locale(identifier: "en_GB")
    return f
  }

  /// Removes spaces/punctuation so names are Drive-safe (e.g. "All Saints Road" -> "AllSaintsRoad").
  static func slug(_ raw: String) -> String {
    let allowed = CharacterSet.alphanumerics
    let cleaned = raw.unicodeScalars.map { allowed.contains($0) ? Character($0) : " " }
    return String(cleaned)
      .split(separator: " ")
      .map { $0.prefix(1).uppercased() + $0.dropFirst() }
      .joined()
  }

  /// Short task reference for the file name, e.g. "ALLO-0042". Falls back to the record/submission link.
  static func taskRef(allocation: WorkAllocation?, dailyRecordId: UUID?, submissionId: UUID?)
    -> String
  {
    if let a = allocation {
      return "ALLO-" + String(a.id.uuidString.prefix(4)).uppercased()
    }
    if let r = dailyRecordId {
      return "REC-" + String(r.uuidString.prefix(4)).uppercased()
    }
    if let s = submissionId {
      return "SUB-" + String(s.uuidString.prefix(4)).uppercased()
    }
    return "GEN-0000"
  }

  // MARK: - Path + filename

  /// `My Project Group - Site Record System / File Type / Site / Week Ending / Tradesman`
  static func folderPath(type: PhotoType, siteName: String, weekEnding: Date, tradesman: String)
    -> String
  {
    [
      rootFolder,
      type.rawValue,
      siteName,
      "Week Ending " + fileDateFormatter.string(from: weekEnding),
      tradesman,
    ].joined(separator: " / ")
  }

  /// `Date_Site_Tradesman_FileType_TaskID.ext`
  static func fileName(
    date: Date, siteName: String, tradesman: String, type: PhotoType,
    taskRef: String, ext: String
  ) -> String {
    let parts = [
      fileDateFormatter.string(from: date),
      slug(siteName),
      slug(tradesman),
      type.fileToken,
      taskRef,
    ].joined(separator: "_")
    return "\(parts).\(ext)"
  }

  // MARK: - Upload

  struct UploadResult {
    var driveFileId: String
    var driveFolderPath: String
    var driveFileName: String
    var driveURL: String
    var weekEnding: Date
  }

  /// Simulates writing the file into Drive. Replace body with a Drive API call later.
  static func upload(
    type: PhotoType, date: Date, site: Site, tradesman: String, ext: String,
    allocation: WorkAllocation?, dailyRecordId: UUID?, submissionId: UUID?
  ) -> UploadResult {
    let weekEnding = weekEndingSunday(for: date)
    let ref = taskRef(
      allocation: allocation, dailyRecordId: dailyRecordId, submissionId: submissionId)
    let path = folderPath(
      type: type, siteName: site.name, weekEnding: weekEnding, tradesman: tradesman)
    let name = fileName(
      date: date, siteName: site.name, tradesman: tradesman, type: type, taskRef: ref, ext: ext)
    let fileId = "drv_" + UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(20)
    let url = "https://drive.google.com/file/d/\(fileId)/view"
    return UploadResult(
      driveFileId: String(fileId), driveFolderPath: path,
      driveFileName: name, driveURL: url, weekEnding: weekEnding)
  }

  /// Sunday week-ending used across MPG timesheets.
  static func weekEndingSunday(for date: Date) -> Date {
    let cal = Calendar(identifier: .gregorian)
    let weekday = cal.component(.weekday, from: date)  // 1 = Sunday
    let daysToSunday = (8 - weekday) % 7
    let sunday = cal.date(byAdding: .day, value: daysToSunday, to: date) ?? date
    return cal.startOfDay(for: sunday)
  }
}

/// A single row in the "Photos & Files" Google Sheet tab.
struct FileSheetRow: Identifiable {
  var id: UUID
  var fileId: String
  var driveURL: String
  var uploadedBy: String
  var tradesmanName: String
  var site: String
  var date: Date
  var weekEnding: Date?
  var linkedAllocation: String
  var linkedDailyRecord: String
  var linkedSubmission: String
  var fileType: String
  var notes: String
  var timestamp: Date
  var linkedRegister: String?
}
