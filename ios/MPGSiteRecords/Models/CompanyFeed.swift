import Foundation

// MARK: - Company feed (general posts + group chat)

/// A general company-wide post from any staff member. Supports optional photos
/// (SF Symbol stand-ins, matching the rest of the app), likes and comments.
struct FeedPost: Identifiable, Hashable {
  let id: UUID
  var authorId: UUID
  var authorName: String
  var authorRole: UserRole
  var text: String
  /// SF Symbol stand-ins for attached photos (same convention as SitePhoto).
  var photoSymbols: [String]
  /// Optional site this post relates to.
  var siteId: UUID?
  var timestamp: Date
  var likedBy: Set<UUID>
  var comments: [FeedComment]

  init(
    id: UUID = UUID(),
    authorId: UUID,
    authorName: String,
    authorRole: UserRole,
    text: String,
    photoSymbols: [String] = [],
    siteId: UUID? = nil,
    timestamp: Date = .now,
    likedBy: Set<UUID> = [],
    comments: [FeedComment] = []
  ) {
    self.id = id
    self.authorId = authorId
    self.authorName = authorName
    self.authorRole = authorRole
    self.text = text
    self.photoSymbols = photoSymbols
    self.siteId = siteId
    self.timestamp = timestamp
    self.likedBy = likedBy
    self.comments = comments
  }
}

struct FeedComment: Identifiable, Hashable {
  let id: UUID
  var authorId: UUID
  var authorName: String
  var text: String
  var timestamp: Date

  init(
    id: UUID = UUID(),
    authorId: UUID,
    authorName: String,
    text: String,
    timestamp: Date = .now
  ) {
    self.id = id
    self.authorId = authorId
    self.authorName = authorName
    self.text = text
    self.timestamp = timestamp
  }
}
