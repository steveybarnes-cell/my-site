import SwiftUI

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
  }

  let id: UUID
  var kind: Kind
  var colorHex: String
  var lineWidth: CGFloat
  /// Normalised points (0...1). Freehand uses the full path; shapes use two.
  var points: [CGPoint]

  init(
    id: UUID = UUID(),
    kind: Kind,
    colorHex: String,
    lineWidth: CGFloat = 4,
    points: [CGPoint] = []
  ) {
    self.id = id
    self.kind = kind
    self.colorHex = colorHex
    self.lineWidth = lineWidth
    self.points = points
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

/// Identifies which photo a markup layer belongs to: a specific image index
/// within a specific feed post.
struct PhotoMarkupKey: Hashable {
  let postId: UUID
  let photoIndex: Int
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
    }
    return path
  }
}

/// Read-only renderer that draws a markup layer on top of a photo.
struct PhotoMarkupOverlay: View {
  let markup: PhotoMarkup

  var body: some View {
    GeometryReader { geo in
      ZStack {
        ForEach(markup.annotations) { ann in
          if ann.kind == .highlight {
            // Highlight boxes get a translucent fill plus a bold outline.
            ann.path(in: geo.size)
              .fill(ann.color.opacity(0.22))
            ann.path(in: geo.size)
              .stroke(ann.color, lineWidth: ann.lineWidth)
          } else {
            ann.path(in: geo.size)
              .stroke(
                ann.color,
                style: StrokeStyle(
                  lineWidth: ann.lineWidth, lineCap: .round, lineJoin: .round)
              )
              .shadow(color: .black.opacity(0.25), radius: 1, y: 0.5)
          }
        }
      }
    }
    .allowsHitTesting(false)
  }
}
