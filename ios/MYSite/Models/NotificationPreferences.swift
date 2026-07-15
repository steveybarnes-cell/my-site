import Foundation
import Observation
import UserNotifications

/// The distinct kinds of event that can raise a notification. Each maps to a
/// per-user preference toggle and to the free-text `type` shown on the row.
enum NotifyCategory: String, CaseIterable, Codable, Identifiable {
  case workAllocated
  case invoiceSubmitted
  case invoiceQueried
  case invoicePaid
  case recordSubmitted
  case attendance
  case fileUploaded
  case pendingReview

  var id: String { rawValue }

  /// The `type` label surfaced on the notification row / banner title.
  var displayType: String {
    switch self {
    case .workAllocated: return "Allocation"
    case .invoiceSubmitted: return "Invoice submitted"
    case .invoiceQueried: return "Invoice queried"
    case .invoicePaid: return "Payment"
    case .recordSubmitted: return "Site record"
    case .attendance: return "Attendance"
    case .fileUploaded: return "File"
    case .pendingReview: return "Pending reviews"
    }
  }

  var title: String {
    switch self {
    case .workAllocated: return "New work allocated"
    case .invoiceSubmitted: return "Invoice / timesheet submitted"
    case .invoiceQueried: return "Invoice queried"
    case .invoicePaid: return "Payment made"
    case .recordSubmitted: return "Daily site record submitted"
    case .attendance: return "Attendance needs review"
    case .fileUploaded: return "File / receipt uploaded"
    case .pendingReview: return "Items waiting for your approval"
    }
  }

  var detail: String {
    switch self {
    case .workAllocated: return "You are assigned a job."
    case .invoiceSubmitted: return "A subcontractor submits pay for approval."
    case .invoiceQueried: return "An invoice you own is queried or held."
    case .invoicePaid: return "An invoice is approved or paid."
    case .recordSubmitted: return "A daily site record is submitted."
    case .attendance: return "A clock-in/out is outside the site."
    case .fileUploaded: return "Register evidence is uploaded."
    case .pendingReview: return "A reminder of invoices and records awaiting sign-off."
    }
  }

  var symbol: String {
    switch self {
    case .workAllocated: return "hammer.fill"
    case .invoiceSubmitted: return "paperplane.fill"
    case .invoiceQueried: return "questionmark.circle.fill"
    case .invoicePaid: return "sterlingsign.circle.fill"
    case .recordSubmitted: return "list.clipboard.fill"
    case .attendance: return "location.slash"
    case .fileUploaded: return "paperclip"
    case .pendingReview: return "tray.full.fill"
    }
  }
}

/// Disk-backed per-user notification preferences. Each user can turn individual
/// event categories on or off, plus a master switch. Fully local and
/// relaunch-safe. Defaults to everything on.
@Observable
final class NotificationPreferencesStore {
  static let shared = NotificationPreferencesStore()

  /// userId -> disabled category raw values.
  private var disabledByUser: [String: Set<String>]
  /// userId -> master switch off.
  private var mutedUsers: Set<String>

  private let fileURL: URL

  private struct Persisted: Codable {
    var disabledByUser: [String: [String]]
    var mutedUsers: [String]
  }

  private init() {
    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    fileURL = docs.appendingPathComponent("mpg-notification-prefs.json")
    if let data = try? Data(contentsOf: fileURL),
      let decoded = try? JSONDecoder().decode(Persisted.self, from: data)
    {
      disabledByUser = decoded.disabledByUser.mapValues { Set($0) }
      mutedUsers = Set(decoded.mutedUsers)
    } else {
      disabledByUser = [:]
      mutedUsers = []
    }
  }

  private func persist() {
    let snapshot = Persisted(
      disabledByUser: disabledByUser.mapValues { Array($0) },
      mutedUsers: Array(mutedUsers))
    if let data = try? JSONEncoder().encode(snapshot) {
      try? data.write(to: fileURL, options: .atomic)
    }
  }

  func isMuted(_ userId: UUID) -> Bool { mutedUsers.contains(userId.uuidString) }

  func setMuted(_ muted: Bool, for userId: UUID) {
    if muted { mutedUsers.insert(userId.uuidString) } else { mutedUsers.remove(userId.uuidString) }
    persist()
  }

  func isEnabled(_ category: NotifyCategory, for userId: UUID) -> Bool {
    guard !isMuted(userId) else { return false }
    return !(disabledByUser[userId.uuidString]?.contains(category.rawValue) ?? false)
  }

  func setEnabled(_ enabled: Bool, category: NotifyCategory, for userId: UUID) {
    var set = disabledByUser[userId.uuidString] ?? []
    if enabled { set.remove(category.rawValue) } else { set.insert(category.rawValue) }
    disabledByUser[userId.uuidString] = set
    persist()
  }
}

/// Thin wrapper over `UNUserNotificationCenter` for local (on-device) delivery.
/// This is the working notification path today; remote APNS delivery can be
/// layered on later against a server + push certificates.
enum LocalNotificationService {
  /// Ask the user for permission to show alerts. Safe to call more than once.
  static func requestAuthorization() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) {
      granted, _ in
      TenXPreviewSupport.log("local-notifications authorization granted=\(granted)")
    }
  }

  /// Fire an immediate local notification. No-op if the user hasn't authorised.
  static func fire(title: String, body: String, categorySymbol: String) {
    let center = UNUserNotificationCenter.current()
    center.getNotificationSettings { settings in
      guard
        settings.authorizationStatus == .authorized
          || settings.authorizationStatus == .provisional
      else { return }
      let content = UNMutableNotificationContent()
      content.title = title
      content.body = body
      content.sound = .default
      let request = UNNotificationRequest(
        identifier: UUID().uuidString, content: content, trigger: nil)
      center.add(request)
    }
  }
}
