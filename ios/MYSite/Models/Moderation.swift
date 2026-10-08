import Foundation
import Observation

// MARK: - Moderating the company feed
//
// The feed is the one place in this app where a person writes something that
// another person reads. Everything else is a record of work. That makes it
// user-generated content, and App Store Guideline 1.2 asks four things of any
// app that carries it: a way to report offensive material, a timely response to
// those reports, a way to block an abusive user, and a way to reach the people
// who make the app.
//
// This file covers the first three. The fourth is the support email on the
// App Store listing.
//
// Two deliberate decisions:
//
//   A block is personal and local. It hides that person from *your* feed, on
//   *your* phone. It does not remove them from the company, tell them anything,
//   or affect what anyone else sees — because on a building site the man you
//   have fallen out with is still the man you are working beside tomorrow, and
//   an app that broadcast a falling-out would make things worse, not better.
//
//   A report is not local. It goes to the administrators as a notification,
//   which is the same route every other office-level event in this app already
//   takes, so it lands on the screen the office already looks at. A report that
//   only wrote to the phone that made it would be a button that does nothing,
//   and a button that does nothing is worse than no button — it tells a person
//   something has been done about a thing that upset them when it has not.

/// One thing one person flagged about something another person posted.
///
/// The text is snapshotted at the moment of the report rather than looked up
/// later, because the post may be edited or deleted by then and the office
/// still needs to know what was actually said.
struct ContentReport: Codable, Identifiable, Hashable {

  enum Kind: String, Codable, Hashable {
    case post
    case comment
  }

  /// Deliberately short and site-flavoured. A long list of legalistic
  /// categories gets one of two answers — the first one, or nothing.
  enum Reason: String, Codable, CaseIterable, Identifiable, Hashable {
    case offensive = "Offensive or abusive"
    case notWork = "Nothing to do with work"
    case unsafe = "Shows something unsafe"
    case wrong = "Wrong or misleading"

    var id: String { rawValue }
  }

  let id: UUID
  var kind: Kind
  /// The post or comment being reported.
  var targetId: UUID
  /// The post it lives in — the same as `targetId` when reporting a post.
  var postId: UUID
  var authorId: UUID
  var authorName: String
  /// What it said when it was reported.
  var snapshot: String
  var reason: Reason
  var reporterId: UUID
  var reporterName: String
  var timestamp: Date

  init(
    id: UUID = UUID(),
    kind: Kind,
    targetId: UUID,
    postId: UUID,
    authorId: UUID,
    authorName: String,
    snapshot: String,
    reason: Reason,
    reporterId: UUID,
    reporterName: String,
    timestamp: Date = Date()
  ) {
    self.id = id
    self.kind = kind
    self.targetId = targetId
    self.postId = postId
    self.authorId = authorId
    self.authorName = authorName
    self.snapshot = snapshot
    self.reason = reason
    self.reporterId = reporterId
    self.reporterName = reporterName
    self.timestamp = timestamp
  }

  /// One line, as the office will read it in their notifications.
  var officeSummary: String {
    let what = kind == .post ? "a post" : "a comment"
    let trimmed = snapshot.trimmingCharacters(in: .whitespacesAndNewlines)
    let quoted = trimmed.count > 90 ? String(trimmed.prefix(90)) + "…" : trimmed
    let body = quoted.isEmpty ? "" : " — “\(quoted)”"
    return "\(reporterName) reported \(what) by \(authorName): \(reason.rawValue)\(body)"
  }
}

/// Where blocks and reports live between launches.
///
/// `UserDefaults` rather than a table, because a block is a preference held by
/// one person on one device and has no business being visible to the company.
/// Reports are kept here too, but only as the reporter's own receipt — the copy
/// that matters is the notification already on its way to the office.
@Observable
final class ModerationStore {

  static let shared = ModerationStore()

  private static let reportsKey = "mysite.moderation.reports.v1"
  private static let blocksKey = "mysite.moderation.blocks.v1"

  /// Reports raised from this device.
  private(set) var reports: [ContentReport] = []

  /// Who each person has blocked, keyed by the blocker's id.
  ///
  /// Keyed by the blocker rather than held as one flat set because a phone can
  /// be signed into by more than one person over its life, and inheriting the
  /// last man's blocked list would silently hide posts from someone who never
  /// blocked anybody.
  private(set) var blocks: [String: Set<UUID>] = [:]

  /// Names of blocked people, so the unblock list can say who they are without
  /// depending on them still being in the roster.
  private(set) var blockedNames: [String: String] = [:]

  private init() {
    let defaults = UserDefaults.standard
    if let data = defaults.data(forKey: Self.reportsKey),
      let decoded = try? JSONDecoder().decode([ContentReport].self, from: data) {
      reports = decoded
    }
    if let data = defaults.data(forKey: Self.blocksKey),
      let decoded = try? JSONDecoder().decode([String: Set<UUID>].self, from: data) {
      blocks = decoded
    }
    if let names = defaults.dictionary(forKey: Self.blocksKey + ".names") as? [String: String] {
      blockedNames = names
    }
  }

  // MARK: Blocking

  func blockedIds(for viewer: UUID) -> Set<UUID> {
    blocks[viewer.uuidString] ?? []
  }

  func isBlocked(_ authorId: UUID, by viewer: UUID) -> Bool {
    blockedIds(for: viewer).contains(authorId)
  }

  func block(_ authorId: UUID, named name: String, by viewer: UUID) {
    var set = blockedIds(for: viewer)
    set.insert(authorId)
    blocks[viewer.uuidString] = set
    blockedNames[authorId.uuidString] = name
    persistBlocks()
  }

  func unblock(_ authorId: UUID, by viewer: UUID) {
    var set = blockedIds(for: viewer)
    set.remove(authorId)
    if set.isEmpty {
      blocks.removeValue(forKey: viewer.uuidString)
    } else {
      blocks[viewer.uuidString] = set
    }
    persistBlocks()
  }

  func name(for authorId: UUID) -> String {
    blockedNames[authorId.uuidString] ?? "Someone"
  }

  // MARK: Reporting

  func record(_ report: ContentReport) {
    reports.append(report)
    if let data = try? JSONEncoder().encode(reports) {
      UserDefaults.standard.set(data, forKey: Self.reportsKey)
    }
  }

  /// Whether this person has already flagged this exact thing — so the menu can
  /// stop offering to report it twice.
  func hasReported(_ targetId: UUID, by reporter: UUID) -> Bool {
    reports.contains { $0.targetId == targetId && $0.reporterId == reporter }
  }

  // MARK: Persistence

  private func persistBlocks() {
    let defaults = UserDefaults.standard
    if let data = try? JSONEncoder().encode(blocks) {
      defaults.set(data, forKey: Self.blocksKey)
    }
    defaults.set(blockedNames, forKey: Self.blocksKey + ".names")
  }
}

// MARK: - The store's side of it

/// Somebody the signed-in person has hidden, ready for a list.
struct BlockedPerson: Identifiable, Hashable {
  let id: UUID
  let name: String
}

extension AppStore {

  private var moderation: ModerationStore { ModerationStore.shared }

  /// Whether the signed-in person has blocked this author.
  func isBlocked(_ authorId: UUID) -> Bool {
    guard let me = currentUser else { return false }
    return moderation.isBlocked(authorId, by: me.id)
  }

  /// Everyone the signed-in person has blocked, for the unblock list.
  ///
  /// A named struct rather than a tuple: `ForEach` needs an `id:` key path and
  /// Swift has no key paths into tuple elements, so `[(id:, name:)]` compiles
  /// everywhere except the one line that has to use it.
  var blockedPeople: [BlockedPerson] {
    guard let me = currentUser else { return [] }
    return moderation.blockedIds(for: me.id)
      .map { BlockedPerson(id: $0, name: user($0)?.name ?? moderation.name(for: $0)) }
      .sorted { $0.name < $1.name }
  }

  func blockAuthor(_ authorId: UUID, named name: String) {
    guard let me = currentUser, authorId != me.id else { return }
    moderation.block(authorId, named: name, by: me.id)
    confirm("\(name) is hidden from your feed")
  }

  func unblockAuthor(_ authorId: UUID) {
    guard let me = currentUser else { return }
    let name = user(authorId)?.name ?? moderation.name(for: authorId)
    moderation.unblock(authorId, by: me.id)
    confirm("\(name) is back in your feed")
  }

  func hasReported(_ targetId: UUID) -> Bool {
    guard let me = currentUser else { return false }
    return moderation.hasReported(targetId, by: me.id)
  }

  // MARK: Reporting

  func reportPost(_ post: FeedPost, reason: ContentReport.Reason) {
    guard let me = currentUser else { return }
    let text = post.text.isEmpty && !post.photos.isEmpty ? "(photo)" : post.text
    submit(
      ContentReport(
        kind: .post, targetId: post.id, postId: post.id,
        authorId: post.authorId, authorName: post.authorName,
        snapshot: text, reason: reason,
        reporterId: me.id, reporterName: me.name))
  }

  func reportComment(_ comment: FeedComment, in post: FeedPost, reason: ContentReport.Reason) {
    guard let me = currentUser else { return }
    submit(
      ContentReport(
        kind: .comment, targetId: comment.id, postId: post.id,
        authorId: comment.authorId, authorName: comment.authorName,
        snapshot: comment.text, reason: reason,
        reporterId: me.id, reporterName: me.name))
  }

  /// Keeps the reporter's receipt and puts it in front of the office.
  ///
  /// Administrators only. A report is about a colleague, and routing it to
  /// every site manager as well would turn one person's complaint into
  /// gossip before anyone had looked at it.
  private func submit(_ report: ContentReport) {
    moderation.record(report)
    for admin in users.filter({ $0.role == .admin && $0.active }) {
      notify(
        admin.id, type: "Reported content",
        message: report.officeSummary, symbol: "flag.fill")
    }
    confirm("Reported — the office has been told")
  }

  // MARK: The feed, with blocks applied

  /// The feed as the signed-in person should see it: nothing from anyone they
  /// have blocked, and no comments from them either.
  ///
  /// Comments are stripped as well as posts because a block that hid a man's
  /// posts and left his replies underneath everyone else's would be a block in
  /// name only.
  func moderatedFeed(siteId: UUID?, needsActionOnly: Bool) -> [FeedPost] {
    let base = needsActionOnly ? needsActionFeed(siteId: siteId) : feed(siteId: siteId)
    guard let me = currentUser else { return base }
    let hidden = moderation.blockedIds(for: me.id)
    guard !hidden.isEmpty else { return base }
    return base.compactMap { post in
      if hidden.contains(post.authorId) { return nil }
      var visible = post
      visible.comments = post.comments.filter { !hidden.contains($0.authorId) }
      return visible
    }
  }

  /// The comments on one post, with blocked authors removed.
  func moderatedComments(of post: FeedPost) -> [FeedComment] {
    guard let me = currentUser else { return post.comments }
    let hidden = moderation.blockedIds(for: me.id)
    guard !hidden.isEmpty else { return post.comments }
    return post.comments.filter { !hidden.contains($0.authorId) }
  }
}
