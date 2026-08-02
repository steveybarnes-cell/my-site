import Foundation

// MARK: - Company feed (general posts + group chat)

/// One photo attached to a feed post.
///
/// Two kinds coexist deliberately. Seeded demo posts carry a `sceneKey`, which
/// renders through `SitePhotoImage` exactly as before — no bundled assets, no
/// migration. Photos captured by a real user carry `localFileName` (bytes
/// cached on device, available instantly and offline) and, once the upload
/// lands, `storageObjectPath` plus a signed `remoteURL` into the private
/// `site-evidence` bucket.
struct FeedPhoto: Identifiable, Hashable {

  /// Progress of the bytes towards the Storage bucket.
  enum UploadState: String, Hashable {
    /// A rendered demo scene — there is nothing to upload.
    case standIn
    /// Held on device only: either the upload has not run yet, or the post has
    /// no site tag / no live session to upload under.
    case local
    case uploading
    case uploaded
    case failed
  }

  let id: UUID
  /// Rendered demo scene key ("digOut", "screed"), for seeded posts only.
  var sceneKey: String?
  /// File name of the flattened JPEG in `FeedPhotoStore`'s cache directory.
  var localFileName: String?
  /// Object path inside the `site-evidence` bucket once uploaded.
  var storageObjectPath: String?
  /// Time-limited signed URL for displaying the remote object.
  var remoteURL: String?
  var uploadState: UploadState

  init(
    id: UUID = UUID(),
    sceneKey: String? = nil,
    localFileName: String? = nil,
    storageObjectPath: String? = nil,
    remoteURL: String? = nil,
    uploadState: UploadState = .local
  ) {
    self.id = id
    self.sceneKey = sceneKey
    self.localFileName = localFileName
    self.storageObjectPath = storageObjectPath
    self.remoteURL = remoteURL
    self.uploadState = uploadState
  }

  /// A rendered demo scene stand-in, as used by the seeded feed.
  static func scene(_ key: String) -> FeedPhoto {
    FeedPhoto(sceneKey: key, uploadState: .standIn)
  }

  /// A real photo whose bytes are cached on device under `fileName`.
  static func local(fileName: String) -> FeedPhoto {
    FeedPhoto(localFileName: fileName, uploadState: .local)
  }

  /// True for rendered demo scenes, which have no real bytes behind them.
  var isStandIn: Bool { sceneKey != nil && localFileName == nil }
}

/// A general company-wide post from any staff member. Supports optional photos,
/// likes and comments.
struct FeedPost: Identifiable, Hashable {
  let id: UUID
  var authorId: UUID
  var authorName: String
  var authorRole: UserRole
  var text: String
  /// Photos attached to this post — real captures, or rendered demo scenes.
  var photos: [FeedPhoto]
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
    photos: [FeedPhoto] = [],
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
    self.photos = photos
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
