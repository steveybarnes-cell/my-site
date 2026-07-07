import Foundation

/// The write verb a queued operation replays against PostgREST.
enum SyncMethod: String, Codable {
  case upsert
  case patch
}

/// A single Supabase write that could not be delivered immediately (e.g. the
/// device was offline). It carries everything needed to replay the request
/// later with a fresh access token, so nothing the user captured is lost.
struct SyncOperation: Codable, Identifiable {
  let id: UUID
  let table: String
  let method: SyncMethod
  let query: String
  /// JSON-encoded request body (row for upsert, partial columns for patch).
  let bodyData: Data
  let label: String
  let createdAt: Date

  init(
    id: UUID = UUID(), table: String, method: SyncMethod = .upsert, query: String = "",
    bodyData: Data, label: String, createdAt: Date = Date()
  ) {
    self.id = id
    self.table = table
    self.method = method
    self.query = query
    self.bodyData = bodyData
    self.label = label
    self.createdAt = createdAt
  }
}

/// A disk-backed FIFO queue of pending Supabase writes.
///
/// Failed writes are appended and persisted to Documents so they survive an
/// app relaunch. `drain(token:)` replays them in order and stops at the first
/// failure so ordering is preserved for the next attempt.
final class SyncQueue {
  static let shared = SyncQueue()

  private let fileURL: URL
  private(set) var operations: [SyncOperation]

  private init() {
    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    fileURL = docs.appendingPathComponent("mpg-sync-queue.json")
    if let data = try? Data(contentsOf: fileURL),
      let decoded = try? JSONDecoder().decode([SyncOperation].self, from: data)
    {
      operations = decoded
    } else {
      operations = []
    }
  }

  var count: Int { operations.count }
  var isEmpty: Bool { operations.isEmpty }

  /// Coalesces by (table + body identity is hard) — we instead de-dupe by the
  /// same row id if the body encodes an `id`. Simpler: replace an existing
  /// queued op that targets the same table + primary id, so repeated edits to
  /// one record while offline collapse to the latest version.
  func enqueue(_ op: SyncOperation) {
    if op.method == .upsert, let newId = rowId(in: op.bodyData) {
      operations.removeAll { $0.method == .upsert && $0.table == op.table && rowId(in: $0.bodyData) == newId }
    }
    operations.append(op)
    save()
  }

  func remove(_ id: UUID) {
    operations.removeAll { $0.id == id }
    save()
  }

  func clear() {
    operations.removeAll()
    save()
  }

  /// Replays queued operations in order. Returns the number successfully
  /// delivered. Stops at the first failure to preserve ordering.
  func drain(token: String) async -> Int {
    var delivered = 0
    let snapshot = operations
    for op in snapshot {
      do {
        try await SupabaseClient.shared.execute(op, accessToken: token)
        remove(op.id)
        delivered += 1
      } catch {
        break
      }
    }
    return delivered
  }

  private func rowId(in body: Data) -> String? {
    guard let obj = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
      return nil
    }
    return obj["id"] as? String
  }

  private func save() {
    guard let data = try? JSONEncoder().encode(operations) else { return }
    try? data.write(to: fileURL, options: .atomic)
  }
}

extension SupabaseClient {
  /// Replays a queued operation against the correct PostgREST verb.
  func execute(_ op: SyncOperation, accessToken: String) async throws {
    switch op.method {
    case .upsert:
      try await upsert(table: op.table, body: op.bodyData, accessToken: accessToken)
    case .patch:
      try await patch(table: op.table, query: op.query, body: op.bodyData, accessToken: accessToken)
    }
  }
}
