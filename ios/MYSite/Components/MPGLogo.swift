import SwiftUI

/// The "MY Site" brand mark: a builder's hard hat sitting on a pitched
/// roofline. Drawn entirely as vector paths in the app's own Brand colours so
/// it reads as part of the interface — never a pasted-on photo.
struct MYSiteMark: View {
  /// Colour of the roofline stroke.
  var stroke: Color = Brand.ink
  /// Fill colour of the hard hat.
  var accent: Color = Brand.logoGreen

  var body: some View {
    GeometryReader { geo in
      let w = geo.size.width
      let h = geo.size.height
      let lw = max(2, h * 0.13)
      ZStack {
        RooflineShape()
          .stroke(
            stroke.opacity(0.85),
            style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))
        HardHatShape()
          .fill(stroke)
      }
      .frame(width: w, height: h)
    }
  }
}

/// A house gable: an open "^" roofline rising from the lower-left to a peak
/// then down to the lower-right — the roofline the hard hat rests on, matching
/// the app icon.
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

/// A builder's hard hat: rounded dome with a front peak and a wide brim,
/// tilted slightly to the right like the brand sheet mark.
private struct HardHatShape: Shape {
  func path(in rect: CGRect) -> Path {
    let w = rect.width
    let h = rect.height
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
      CGPoint(x: rect.minX + x * w, y: rect.minY + y * h)
    }
    var path = Path()

    // Rounded dome across the top.
    path.move(to: p(0.30, 0.50))
    path.addCurve(
      to: p(0.86, 0.34),
      control1: p(0.34, 0.10),
      control2: p(0.78, 0.06))
    // Right side down into the brim.
    path.addLine(to: p(0.90, 0.40))
    // Right brim tip.
    path.addQuadCurve(to: p(0.99, 0.50), control: p(0.99, 0.42))
    path.addQuadCurve(to: p(0.90, 0.58), control: p(0.99, 0.58))
    // Under-brim back across to the left.
    path.addLine(to: p(0.30, 0.66))
    // Left brim tip.
    path.addQuadCurve(to: p(0.20, 0.58), control: p(0.19, 0.66))
    path.addQuadCurve(to: p(0.30, 0.50), control: p(0.21, 0.51))
    path.closeSubpath()
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
