import Foundation
import Observation

/// A partially-completed daily site record captured on-site. Drafts are saved
/// locally so a tradesman can start a record with no signal, close the app, and
/// resume it later — nothing is lost and nothing is submitted until they choose.
struct RecordDraft: Codable, Identifiable, Hashable {
  var id: UUID
  var allocationId: UUID?
  var siteId: UUID
  var userId: UUID
  var siteName: String
  var startTime: String
  var finishTime: String
  var breakMinutes: Int
  var description: String
  var category: WorkCategory
  var delay: DelayReason
  var delayNote: String
  var instructedBy: String
  var updatedAt: Date

  init(
    id: UUID = UUID(), allocationId: UUID?, siteId: UUID, userId: UUID, siteName: String,
    startTime: String, finishTime: String, breakMinutes: Int, description: String,
    category: WorkCategory, delay: DelayReason, delayNote: String, instructedBy: String,
    updatedAt: Date = Date()
  ) {
    self.id = id
    self.allocationId = allocationId
    self.siteId = siteId
    self.userId = userId
    self.siteName = siteName
    self.startTime = startTime
    self.finishTime = finishTime
    self.breakMinutes = breakMinutes
    self.description = description
    self.category = category
    self.delay = delay
    self.delayNote = delayNote
    self.instructedBy = instructedBy
    self.updatedAt = updatedAt
  }
}

/// Disk-backed store of unfinished daily-record drafts. Survives relaunch and
/// works fully offline (no network). One draft per allocation is kept so
/// repeated edits to the same job collapse to the latest version.
@Observable
final class DraftStore {
  static let shared = DraftStore()

  private let fileURL: URL
  private(set) var drafts: [RecordDraft]

  private init() {
    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    fileURL = docs.appendingPathComponent("mpg-record-drafts.json")
    if let data = try? Data(contentsOf: fileURL),
      let decoded = try? JSONDecoder().decode([RecordDraft].self, from: data)
    {
      drafts = decoded
    } else {
      drafts = []
    }
  }

  /// Drafts belonging to a given user, most recently edited first.
  func drafts(for userId: UUID) -> [RecordDraft] {
    drafts.filter { $0.userId == userId }.sorted { $0.updatedAt > $1.updatedAt }
  }

  /// The saved draft for a specific allocation, if one exists.
  func draft(forAllocation allocationId: UUID?) -> RecordDraft? {
    guard let allocationId else { return nil }
    return drafts.first { $0.allocationId == allocationId }
  }

  /// Inserts or updates a draft. Drafts tied to the same allocation are replaced
  /// so there is only ever one open draft per job.
  func save(_ draft: RecordDraft) {
    var updated = draft
    updated.updatedAt = Date()
    if let allocationId = updated.allocationId,
      let i = drafts.firstIndex(where: { $0.allocationId == allocationId })
    {
      updated.id = drafts[i].id
      drafts[i] = updated
    } else if let i = drafts.firstIndex(where: { $0.id == updated.id }) {
      drafts[i] = updated
    } else {
      drafts.append(updated)
    }
    persist()
  }

  func delete(_ id: UUID) {
    drafts.removeAll { $0.id == id }
    persist()
  }

  private func persist() {
    guard let data = try? JSONEncoder().encode(drafts) else { return }
    try? data.write(to: fileURL, options: .atomic)
  }
}
