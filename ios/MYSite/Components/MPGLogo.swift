import SwiftUI

/// The "MY Site" brand mark: a clean pitched house gable, drawn entirely as a
/// vector path in the app's own Brand colours so it reads as part of the
/// interface — never a pasted-on photo.
struct MYSiteMark: View {
  /// Colour of the roofline stroke.
  var stroke: Color = Brand.ink
  /// Retained for source compatibility with older call sites.
  var accent: Color = Brand.logoGreen

  var body: some View {
    GeometryReader { geo in
      let w = geo.size.width
      let h = geo.size.height
      let lw = max(2, h * 0.13)
      RooflineShape()
        .stroke(
          stroke.opacity(0.85),
          style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round)
        )
        .frame(width: w, height: h)
    }
  }
}

/// A house gable: an open "^" roofline rising from the lower-left to a peak
/// then down to the lower-right, matching the app icon.
private struct RooflineShape: Shape {
  func path(in rect: CGRect) -> Path {
    let w = rect.width
    let h = rect.height
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
      CGPoint(x: rect.minX + x * w, y: rect.minY + y * h)
    }
    var path = Path()
    // Left eave up to the peak.
    path.move(to: p(0.04, 0.92))
    path.addLine(to: p(0.46, 0.30))
    // Peak down to the right eave.
    path.addLine(to: p(0.88, 0.92))
    return path
  }
}

/// "MY Site" logo lockup rendered purely with vector shapes and text tinted
/// from the `Brand` palette, so it blends into whatever surface it sits on.
/// Kept named `MPGLogo` so existing call sites continue to work.
struct MPGLogo: View {
  /// Cap height of the large "MY" wordmark. Everything scales from this.
  var height: CGFloat = 72
  /// Render for a dark background (light ink) when true.
  var onDark: Bool = true
  /// Lay the mark and wordmark side-by-side instead of stacked.
  var horizontal: Bool = false
  /// Retained for source compatibility with older call sites.
  var showTagline: Bool = false

  private var inkColor: Color { onDark ? .white : Brand.ink }
  private var accentColor: Color { onDark ? Brand.logoGreen : Brand.oliveDark }

  var body: some View {
    if horizontal {
      horizontalLockup
    } else {
      stackedLockup
    }
  }

  private var wordmark: some View {
    let s = height
    return VStack(alignment: .leading, spacing: -s * 0.02) {
      Text("MY")
        .font(.system(size: s, weight: .heavy, design: .rounded))
        .foregroundStyle(accentColor)
        .kerning(-s * 0.02)
      Text("SITE")
        .font(.system(size: s * 0.32, weight: .bold, design: .rounded))
        .kerning(s * 0.22)
        .foregroundStyle(inkColor.opacity(0.9))
    }
  }

  private var stackedLockup: some View {
    let s = height
    return VStack(spacing: s * 0.08) {
      MYSiteMark(stroke: inkColor, accent: accentColor)
        .frame(width: s * 1.45, height: s * 0.68)
      wordmark
        .multilineTextAlignment(.center)
    }
    .fixedSize()
  }

  private var horizontalLockup: some View {
    let s = height
    return HStack(spacing: s * 0.28) {
      MYSiteMark(stroke: inkColor, accent: accentColor)
        .frame(width: s * 1.2, height: s * 0.62)
      wordmark
    }
    .fixedSize()
  }
}

#Preview {
  VStack(spacing: 0) {
    ZStack {
      Brand.charcoal.ignoresSafeArea()
      MPGLogo(height: 64)
    }
    ZStack {
      Brand.lightGreen.opacity(0.5).ignoresSafeArea()
      MPGLogo(height: 56, onDark: false, horizontal: true)
    }
  }
}
