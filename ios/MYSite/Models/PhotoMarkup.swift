import SwiftUI
import UIKit

// MARK: - Photo markup model

/// A single annotation drawn on top of a photo to flag an area for attention.
/// All coordinates are normalised (0...1) relative to the photo's frame so a
/// markup scales correctly to any display size (thumbnail, full screen, export).
struct PhotoAnnotation: Identifiable, Hashable {
  enum Kind: String, Hashable {
    case pen  // freehand stroke through `points`
    case arrow  // straight arrow from points.first -> points.last
    case highlight  // rectangle bounded by points.first / points.last
    case circle  // ellipse bounded by points.first / points.last
    case text  // typed label anchored at points.first
  }

  let id: UUID
  var kind: Kind
  var colorHex: String
  var lineWidth: CGFloat
  /// Normalised points (0...1). Freehand uses the full path; shapes use two.
  var points: [CGPoint]
  /// Label content for `.text` annotations. Ignored by every other kind.
  var text: String
  /// Font size for `.text`, as a fraction of the photo's height, so a label
  /// keeps its proportions from thumbnail to full screen to exported JPEG.
  var fontScale: CGFloat

  init(
    id: UUID = UUID(),
    kind: Kind,
    colorHex: String,
    lineWidth: CGFloat = 4,
    points: [CGPoint] = [],
    text: String = "",
    fontScale: CGFloat = 0.055
  ) {
    self.id = id
    self.kind = kind
    self.colorHex = colorHex
    self.lineWidth = lineWidth
    self.points = points
    self.text = text
    self.fontScale = fontScale
  }

  var color: Color { Color.markup(colorHex) }
}

extension Color {
  /// Builds a colour from a "#RRGGBB" string used by markup annotations.
  static func markup(_ string: String) -> Color {
    let cleaned = string.hasPrefix("#") ? String(string.dropFirst()) : string
    let value = UInt64(cleaned, radix: 16) ?? 0
    return Color(
      .sRGB,
      red: Double((value >> 16) & 0xFF) / 255,
      green: Double((value >> 8) & 0xFF) / 255,
      blue: Double(value & 0xFF) / 255,
      opacity: 1)
  }
}

/// The full markup layer for one photo (a set of annotations).
struct PhotoMarkup: Hashable {
  var annotations: [PhotoAnnotation] = []
  var isEmpty: Bool { annotations.isEmpty }
}

// MARK: - Markup palette

enum MarkupPalette {
  /// Attention-first colours: bold, high-contrast, readable on site photos.
  static let colors: [String] = [
    "#FF3B30",  // red — defects / attention
    "#FF9500",  // orange — warning
    "#FFCC00",  // yellow — highlight
    "#34C759",  // green — approved / done
    "#0A84FF",  // blue — note
    "#FFFFFF",  // white — outline on dark areas
  ]

  static let defaultColor = colors[0]
}

// MARK: - Geometry helpers

extension PhotoAnnotation {
  /// Builds the SwiftUI path for this annotation within a pixel-sized rect.
  func path(in size: CGSize) -> Path {
    func denorm(_ p: CGPoint) -> CGPoint {
      CGPoint(x: p.x * size.width, y: p.y * size.height)
    }
    var path = Path()
    switch kind {
    case .pen:
      guard let first = points.first else { return path }
      path.move(to: denorm(first))
      for p in points.dropFirst() { path.addLine(to: denorm(p)) }
    case .arrow:
      guard let a = points.first, let b = points.last, points.count >= 2 else { return path }
      let start = denorm(a)
      let end = denorm(b)
      path.move(to: start)
      path.addLine(to: end)
      // Arrow head
      let angle = atan2(end.y - start.y, end.x - start.x)
      let headLen = max(12, lineWidth * 3.2)
      let spread = CGFloat.pi / 7
      let left = CGPoint(
        x: end.x - headLen * cos(angle - spread),
        y: end.y - headLen * sin(angle - spread))
      let right = CGPoint(
        x: end.x - headLen * cos(angle + spread),
        y: end.y - headLen * sin(angle + spread))
      path.move(to: end)
      path.addLine(to: left)
      path.move(to: end)
      path.addLine(to: right)
    case .highlight:
      guard let a = points.first, let b = points.last, points.count >= 2 else { return path }
      let start = denorm(a)
      let end = denorm(b)
      let rect = CGRect(
        x: min(start.x, end.x), y: min(start.y, end.y),
        width: abs(end.x - start.x), height: abs(end.y - start.y))
      path.addRoundedRect(in: rect, cornerSize: CGSize(width: 6, height: 6))
    case .circle:
      guard let a = points.first, let b = points.last, points.count >= 2 else { return path }
      let start = denorm(a)
      let end = denorm(b)
      let rect = CGRect(
        x: min(start.x, end.x), y: min(start.y, end.y),
        width: abs(end.x - start.x), height: abs(end.y - start.y))
      path.addEllipse(in: rect)
    case .text:
      // Text is drawn as glyphs, not a stroked path — see `PhotoMarkupOverlay`
      // and `PhotoMarkupRenderer`, which both special-case this kind.
      break
    }
    return path
  }

  /// Reference height that `lineWidth` is authored against. Stroke widths are
  /// scaled from this so a pen line keeps the same visual weight whether it is
  /// drawn in the editor, shown in a 300pt feed card, or burned into a
  /// 3024px JPEG.
  static let referenceHeight: CGFloat = 300

  /// Stroke width in points for this annotation drawn at `size`.
  func strokeWidth(in size: CGSize) -> CGFloat {
    lineWidth * max(0.25, size.height / Self.referenceHeight)
  }

  /// Font size in points for a `.text` annotation drawn at `size`.
  func fontSize(in size: CGSize) -> CGFloat {
    max(11, fontScale * size.height)
  }

  /// Top-leading anchor in pixels for a `.text` annotation drawn at `size`.
  func textAnchor(in size: CGSize) -> CGPoint {
    let p = points.first ?? CGPoint(x: 0.5, y: 0.5)
    return CGPoint(x: p.x * size.width, y: p.y * size.height)
  }
}

/// Read-only renderer that draws a markup layer on top of a photo.
struct PhotoMarkupOverlay: View {
  let markup: PhotoMarkup

  var body: some View {
    GeometryReader { geo in
      ZStack(alignment: .topLeading) {
        // Fill the coordinate space so `.topLeading` offsets are measured from
        // the photo's own origin rather than the collapsed content bounds.
        Color.clear

        ForEach(markup.annotations) { ann in
          switch ann.kind {
          case .highlight:
            // Highlight boxes get a translucent fill plus a bold outline.
            ZStack {
              ann.path(in: geo.size).fill(ann.color.opacity(0.22))
              ann.path(in: geo.size)
                .stroke(ann.color, lineWidth: ann.strokeWidth(in: geo.size))
            }
          case .text:
            MarkupTextLabel(annotation: ann, size: geo.size)
          case .pen, .arrow, .circle:
            ann.path(in: geo.size)
              .stroke(
                ann.color,
                style: StrokeStyle(
                  lineWidth: ann.strokeWidth(in: geo.size), lineCap: .round, lineJoin: .round)
              )
              .shadow(color: .black.opacity(0.25), radius: 1, y: 0.5)
          }
        }
      }
    }
    .allowsHitTesting(false)
  }
}

/// Draws one `.text` annotation anchored at its normalised point. Site photos
/// are busy and high-contrast, so the label sits on a dark plate to stay
/// readable over bright render, dark soil or mid-grey blockwork alike.
struct MarkupTextLabel: View {
  let annotation: PhotoAnnotation
  let size: CGSize

  var body: some View {
    let anchor = annotation.textAnchor(in: size)
    let fontSize = annotation.fontSize(in: size)
    Text(annotation.text)
      .font(.system(size: fontSize, weight: .bold))
      .foregroundStyle(annotation.color)
      .padding(.horizontal, fontSize * 0.32)
      .padding(.vertical, fontSize * 0.16)
      .background(
        RoundedRectangle(cornerRadius: fontSize * 0.25, style: .continuous)
          .fill(.black.opacity(0.45))
      )
      .fixedSize()
      .offset(x: anchor.x, y: anchor.y)
  }
}

// MARK: - Flattening

/// Burns a markup layer into the photo itself, producing a single JPEG.
///
/// Feed photos are site evidence: once posted, the annotation has to travel
/// with the image wherever it ends up (Storage bucket, a signed URL pasted into
/// an email, a printed variation claim), so markup is flattened at post time
/// rather than kept as a separate overlay. Geometry comes from the same
/// `path(in:)` used on screen, so the export matches the editor exactly.
enum PhotoMarkupRenderer {

  /// Returns `image` with `markup` drawn over it at the image's native size.
  static func flatten(image: UIImage, markup: PhotoMarkup) -> UIImage {
    guard !markup.isEmpty else { return image }

    let size = image.size
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = image.scale
    format.opaque = true

    return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
      image.draw(in: CGRect(origin: .zero, size: size))
      let cg = ctx.cgContext

      for ann in markup.annotations {
        let uiColor = UIColor(ann.color)

        if ann.kind == .text {
          draw(text: ann, color: uiColor, in: size)
          continue
        }

        let scaled = ann.strokeWidth(in: size)
        let path = ann.path(in: size).cgPath

        if ann.kind == .highlight {
          cg.addPath(path)
          cg.setFillColor(uiColor.withAlphaComponent(0.22).cgColor)
          cg.fillPath()
        }

        cg.addPath(path)
        cg.setStrokeColor(uiColor.cgColor)
        cg.setLineWidth(scaled)
        cg.setLineCap(.round)
        cg.setLineJoin(.round)
        cg.strokePath()
      }
    }
  }

  private static func draw(text ann: PhotoAnnotation, color: UIColor, in size: CGSize) {
    guard !ann.text.isEmpty else { return }
    let fontSize = ann.fontSize(in: size)
    let font = UIFont.systemFont(ofSize: fontSize, weight: .bold)
    let attrs: [NSAttributedString.Key: Any] = [
      .font: font,
      .foregroundColor: color,
    ]
    let string = NSAttributedString(string: ann.text, attributes: attrs)
    let textSize = string.size()
    let anchor = ann.textAnchor(in: size)
    let padX = fontSize * 0.32
    let padY = fontSize * 0.16

    // Same dark plate as `MarkupTextLabel` so screen and export agree.
    let plate = CGRect(
      x: anchor.x, y: anchor.y,
      width: textSize.width + padX * 2, height: textSize.height + padY * 2)
    let plated = UIBezierPath(roundedRect: plate, cornerRadius: fontSize * 0.25)
    UIColor.black.withAlphaComponent(0.45).setFill()
    plated.fill()

    string.draw(at: CGPoint(x: anchor.x + padX, y: anchor.y + padY))
  }
}
