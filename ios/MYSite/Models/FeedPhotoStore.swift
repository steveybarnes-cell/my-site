import UIKit

/// On-device store for real feed photo bytes.
///
/// A site photo has to be visible the instant it is posted, stay visible with
/// no signal, and survive until its upload to the `site-evidence` bucket
/// succeeds. So bytes are written to Application Support (not Caches, which iOS
/// is free to purge) and the Storage upload is treated as a background mirror
/// of the local copy rather than the source of truth.
enum FeedPhotoStore {

  // MARK: - Location

  /// Directory holding the flattened feed JPEGs.
  static let directory: URL = {
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    let dir = base.appendingPathComponent("FeedPhotos", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
  }()

  static func url(for fileName: String) -> URL {
    directory.appendingPathComponent(fileName)
  }

  // MARK: - Decoded image cache

  /// Decoding a multi-megapixel JPEG on every cell reuse makes the feed stutter,
  /// so decoded images are held in an NSCache that iOS can evict under pressure.
  private static let cache: NSCache<NSString, UIImage> = {
    let c = NSCache<NSString, UIImage>()
    c.countLimit = 60
    return c
  }()

  // MARK: - Read / write

  /// Writes JPEG bytes and returns the generated file name, or nil on failure.
  @discardableResult
  static func save(_ data: Data, id: UUID = UUID()) -> String? {
    let fileName = "\(id.uuidString.lowercased()).jpg"
    do {
      try data.write(to: url(for: fileName), options: .atomic)
      return fileName
    } catch {
      return nil
    }
  }

  static func data(for fileName: String) -> Data? {
    try? Data(contentsOf: url(for: fileName))
  }

  static func image(for fileName: String) -> UIImage? {
    if let hit = cache.object(forKey: fileName as NSString) { return hit }
    guard let data = data(for: fileName), let image = UIImage(data: data) else { return nil }
    cache.setObject(image, forKey: fileName as NSString)
    return image
  }

  static func delete(_ fileName: String) {
    cache.removeObject(forKey: fileName as NSString)
    try? FileManager.default.removeItem(at: url(for: fileName))
  }

  // MARK: - Preparation

  /// Longest edge for a stored feed photo. Full-resolution captures are 12MP+,
  /// which is wasted detail for a 300pt feed card and slow to push over a site
  /// 4G connection — this keeps them legible when zoomed but sane to upload.
  static let maxDimension: CGFloat = 2048

  /// JPEG quality for stored/uploaded feed photos.
  static let compressionQuality: CGFloat = 0.8

  /// Normalises an image for storage: corrects orientation, caps the longest
  /// edge at `maxDimension`, and re-encodes as JPEG.
  static func prepare(_ image: UIImage) -> Data? {
    resized(image).jpegData(compressionQuality: compressionQuality)
  }

  /// Returns `image` scaled so its longest edge is at most `maxDimension`,
  /// with any EXIF orientation baked into the pixels.
  static func resized(_ image: UIImage) -> UIImage {
    let longest = max(image.size.width, image.size.height)
    let scale = longest > maxDimension ? maxDimension / longest : 1
    let target = CGSize(
      width: (image.size.width * scale).rounded(),
      height: (image.size.height * scale).rounded())

    let format = UIGraphicsImageRendererFormat.default()
    // Render at 1x: `target` is already in pixels, and the stored file should
    // not vary with the capturing device's screen scale.
    format.scale = 1
    format.opaque = true
    return UIGraphicsImageRenderer(size: target, format: format).image { _ in
      image.draw(in: CGRect(origin: .zero, size: target))
    }
  }
}
