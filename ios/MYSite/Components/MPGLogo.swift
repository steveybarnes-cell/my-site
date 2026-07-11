import SwiftUI

/// The "MY Site" brand mark: a builder's hard hat sitting on a pitched
/// roofline. Drawn as vector paths so it stays crisp at any size and needs
/// no bundled image asset. Matches the company brand sheet.
struct MYSiteMark: View {
  /// Colour of the hard hat + roofline.
  var stroke: Color = .black

  var body: some View {
    GeometryReader { geo in
      let w = geo.size.width
      let h = geo.size.height
      let lw = max(2, h * 0.14)
      ZStack {
        // Pitched roofline: an apex peak spanning under the hat.
        RooflineShape()
          .stroke(stroke, style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))
        // Hard hat, tilted slightly, resting on the roof apex.
        HardHatShape()
          .fill(stroke)
      }
      .frame(width: w, height: h)
    }
  }
}

/// A pitched roof: rises from the lower-left up to an apex, then a short
/// slope down to the right — the roofline the hard hat rests on.
private struct RooflineShape: Shape {
  func path(in rect: CGRect) -> Path {
    let w = rect.width
    let h = rect.height
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
      CGPoint(x: rect.minX + x * w, y: rect.minY + y * h)
    }
    var path = Path()
    path.move(to: p(0.02, 0.94))
    path.addLine(to: p(0.40, 0.42))
    path.addLine(to: p(0.60, 0.60))
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

    // Dome (rounded top).
    path.move(to: p(0.42, 0.44))
    path.addCurve(
      to: p(0.86, 0.30),
      control1: p(0.44, 0.10),
      control2: p(0.82, 0.04))
    // Down the right side into the brim.
    path.addLine(to: p(0.90, 0.34))
    // Right brim tip.
    path.addQuadCurve(to: p(0.98, 0.40), control: p(0.97, 0.36))
    path.addQuadCurve(to: p(0.90, 0.46), control: p(0.98, 0.46))
    // Under-brim back across to the left.
    path.addLine(to: p(0.40, 0.56))
    // Left brim tip.
    path.addQuadCurve(to: p(0.32, 0.52), control: p(0.31, 0.57))
    path.addQuadCurve(to: p(0.42, 0.44), control: p(0.34, 0.46))
    path.closeSubpath()
    return path
  }
}

/// "MY Site" stacked logo lockup: hard-hat-on-roofline mark on top, a heavy
/// green "MY", then wide-tracked "SITE" underneath — matching the brand sheet.
/// Kept named `MPGLogo` so existing call sites continue to work.
struct MPGLogo: View {
  /// Cap height of the large "MY" wordmark. Everything scales from this.
  var height: CGFloat = 72
  /// Render for a dark background (light mark + light "SITE") when true.
  var onDark: Bool = true
  /// Retained for source compatibility with older call sites.
  var showTagline: Bool = false

  private var inkColor: Color { onDark ? .white : Brand.ink }

  var body: some View {
    let s = height
    VStack(spacing: s * 0.06) {
      MYSiteMark(stroke: inkColor)
        .frame(width: s * 1.5, height: s * 0.72)

      Text("MY")
        .font(.system(size: s, weight: .heavy, design: .rounded))
        .foregroundStyle(Brand.logoGreen)
        .kerning(-s * 0.02)

      Text("SITE")
        .font(.system(size: s * 0.34, weight: .bold, design: .rounded))
        .kerning(s * 0.22)
        .foregroundStyle(inkColor)
        .padding(.top, -s * 0.04)
    }
    .fixedSize()
  }
}

#Preview {
  VStack(spacing: 0) {
    ZStack {
      Brand.charcoal.ignoresSafeArea()
      MPGLogo(height: 72)
    }
    ZStack {
      Color.white.ignoresSafeArea()
      MPGLogo(height: 72, onDark: false)
    }
  }
}
