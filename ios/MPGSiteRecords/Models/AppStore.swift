import Observation
import SwiftUI

@Observable
final class AppStore {
  // Session
  var currentUser: AppUser?

  // Data
  var users: [AppUser] = []
  var profiles: [TradesmanProfile] = []
  var sites: [Site] = []
  var allocations: [WorkAllocation] = []
  var dailyRecords: [DailyRecord] = []
  var materials: [MaterialItem] = []
  var photos: [SitePhoto] = []
  var submissions: [WeeklySubmission] = []
  var comments: [QueryComment] = []
  var notifications: [AppNotification] = []

  init() { seed() }

  // MARK: - Auth (mock)

  func login(as user: AppUser) { currentUser = user }
  func logout() { currentUser = nil }

  var role: UserRole { currentUser?.role ?? .tradesman }

  // MARK: - Convenience lookups

  func user(_ id: UUID) -> AppUser? { users.first { $0.id == id } }
  func site(_ id: UUID) -> Site? { sites.first { $0.id == id } }
  func profile(for userId: UUID) -> TradesmanProfile? { profiles.first { $0.userId == userId } }

  func tradesmen() -> [AppUser] { users.filter { $0.role == .tradesman } }
  func siteManagers() -> [AppUser] { users.filter { $0.role == .siteManager } }

  // Privacy-aware queries
  func allocations(for userId: UUID) -> [WorkAllocation] {
    allocations.filter { $0.tradesmanId == userId }.sorted { $0.date < $1.date }
  }

  func todaysAllocations(for userId: UUID) -> [WorkAllocation] {
    let cal = Calendar.current
    return allocations(for: userId).filter {
      cal.isDateInToday($0.date) || cal.isDateInTomorrow($0.date)
    }
  }

  func records(for userId: UUID) -> [DailyRecord] {
    dailyRecords.filter { $0.userId == userId }.sorted { $0.date > $1.date }
  }

  func materials(for userId: UUID) -> [MaterialItem] {
    materials.filter { $0.userId == userId }.sorted { $0.date > $1.date }
  }

  func submissions(for userId: UUID) -> [WeeklySubmission] {
    submissions.filter { $0.userId == userId }.sorted { $0.weekEnding > $1.weekEnding }
  }

  func notifications(for userId: UUID) -> [AppNotification] {
    notifications.filter { $0.userId == userId }.sorted { $0.timestamp > $1.timestamp }
  }

  func comments(for submissionId: UUID) -> [QueryComment] {
    comments.filter { $0.submissionId == submissionId }.sorted { $0.timestamp < $1.timestamp }
  }

  func sitesManaged(by managerId: UUID) -> [Site] {
    sites.filter { $0.siteManagerId == managerId }
  }

  var unreadCount: Int {
    guard let u = currentUser else { return 0 }
    return notifications.filter { $0.userId == u.id && !$0.read }.count
  }

  // MARK: - Mutations

  func markAllNotificationsRead() {
    guard let u = currentUser else { return }
    for i in notifications.indices where notifications[i].userId == u.id {
      notifications[i].read = true
    }
  }

  func updateAllocationStatus(_ id: UUID, to status: AllocationStatus) {
    guard let i = allocations.firstIndex(where: { $0.id == id }) else { return }
    allocations[i].status = status
  }

  func setSubmissionStatus(_ id: UUID, to status: SubmissionStatus, by name: String? = nil) {
    guard let i = submissions.firstIndex(where: { $0.id == id }) else { return }
    submissions[i].status = status
    if status == .paid { submissions[i].paidDate = Date() }
    if let name { submissions[i].approvedBy = name }
    let sub = submissions[i]
    notify(
      sub.userId, type: "Invoice",
      message: "Your invoice \(sub.invoiceNumber) is now \(status.rawValue).", symbol: "doc.text")
  }

  func addRecord(_ r: DailyRecord) { dailyRecords.append(r) }
  func addMaterial(_ m: MaterialItem) { materials.append(m) }
  func addPhoto(_ p: SitePhoto) { photos.append(p) }

  func addQuery(submissionId: UUID, toUserId: UUID, message: String, fromAdmin: Bool) {
    let name = currentUser?.name ?? "Office"
    comments.append(
      QueryComment(
        id: UUID(), submissionId: submissionId, fromName: name,
        toUserId: toUserId, message: message, timestamp: Date(), fromAdmin: fromAdmin))
  }

  func notify(_ userId: UUID, type: String, message: String, symbol: String) {
    notifications.append(
      AppNotification(
        id: UUID(), userId: userId, type: type,
        message: message, read: false, timestamp: Date(), symbol: symbol))
  }

  // Dashboard rollups
  func missingReceiptMaterials() -> [MaterialItem] { materials.filter { !$0.receiptUploaded } }

  func lateSubmissions() -> [WeeklySubmission] {
    submissions.filter { sub in
      guard let submitted = sub.submittedAt else { return false }
      return submitted > deadline(for: sub.weekEnding)
    }
  }

  /// Monday 13:00 after the given week ending.
  func deadline(for weekEnding: Date) -> Date {
    let cal = Calendar.current
    let monday = cal.date(byAdding: .day, value: 2, to: weekEnding) ?? weekEnding
    return cal.date(bySettingHour: 13, minute: 0, second: 0, of: monday) ?? monday
  }

  func labourCostBySite() -> [(Site, Double)] {
    sites.map { site in
      let cost = dailyRecords.filter { $0.siteId == site.id }.reduce(0.0) { acc, r in
        let rate = profile(for: r.userId)?.hourlyRate ?? 0
        return acc + r.totalHours * rate
      }
      return (site, cost)
    }
  }

  func materialsCostBySite() -> [(Site, Double)] {
    sites.map { site in
      let cost = materials.filter { $0.siteId == site.id }.reduce(0.0) { $0 + $1.total }
      return (site, cost)
    }
  }

  func variationRecords() -> [DailyRecord] {
    dailyRecords.filter { $0.category == .variation }.sorted { $0.date > $1.date }
  }
}
