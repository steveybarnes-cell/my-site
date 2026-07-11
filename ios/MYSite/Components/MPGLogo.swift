import SwiftUI

/// The "MY Site" brand mark: a builder's hard hat resting on a pitched
/// roofline slash. Drawn as stroked/filled paths so it stays crisp at any
/// size and needs no bundled image asset.
struct MYSiteMark: View {
  /// Colour of the hard hat + roofline.
  var stroke: Color = .black
  var body: some View {
    GeometryReader { geo in
      let w = geo.size.width
      let h = geo.size.height
      let lw = max(2, h * 0.09)
      ZStack {
        // Pitched roofline: a slash rising to the right, sitting under the hat.
        RooflineShape()
          .stroke(stroke, style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))
        // Hard hat.
        HardHatShape()
          .fill(stroke)
      }
      .frame(width: w, height: h)
    }
  }
}

/// A single pitched roof edge (diagonal), rising left→right with a short
/// eave return at the top, echoing the brand sheet's roof slash.
private struct RooflineShape: Shape {
  func path(in rect: CGRect) -> Path {
    let w = rect.width
    let h = rect.height
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
      CGPoint(x: rect.minX + x * w, y: rect.minY + y * h)
    }
    var path = Path()
    // Long roof slope from lower-left up to the apex under the hat.
    path.move(to: p(0.04, 0.92))
    path.addLine(to: p(0.62, 0.30))
    // Short right-hand eave kick.
    path.addLine(to: p(0.78, 0.44))
    return path
  }
}

/// A builder's hard hat: rounded dome, front peak, and a wide brim.
private struct HardHatShape: Shape {
  func path(in rect: CGRect) -> Path {
    let w = rect.width
    let h = rect.height
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
      CGPoint(x: rect.minX + x * w, y: rect.minY + y * h)
    }
    var path = Path()

    // Dome
    path.move(to: p(0.44, 0.34))
    path.addCurve(to: p(0.86, 0.34), control1: p(0.46, 0.06), control2: p(0.84, 0.06))
    // Right brim
    path.addLine(to: p(0.96, 0.36))
    path.addQuadCurve(to: p(0.90, 0.42), control: p(0.96, 0.42))
    path.addLine(to: p(0.40, 0.42))
    path.addQuadCurve(to: p(0.34, 0.36), control: p(0.34, 0.42))
    // Left brim back up to dome start
    path.addLine(to: p(0.44, 0.34))
    path.closeSubpath()
    return path
  }
}

/// "MY Site" logo lockup: green "MY", hard-hat-on-roofline mark, then "Site".
/// Kept named `MPGLogo` so existing call sites continue to work.
struct MPGLogo: View {
  /// Overall height of the wordmark row.
  var height: CGFloat = 72
  /// Render for a dark background (light text) when true.
  var onDark: Bool = true
  /// Unused now, retained for source compatibility with older call sites.
  var showTagline: Bool = false

  private var siteColor: Color { onDark ? .white : Brand.ink }
  private var markColor: Color { onDark ? .white : Brand.ink }

  var body: some View {
    let s = height
    HStack(alignment: .firstTextBaseline, spacing: s * 0.16) {
      Text("MY")
        .font(.system(size: s * 0.92, weight: .heavy, design: .rounded))
        .foregroundStyle(Brand.logoGreen)
        .overlay(alignment: .top) {
          // Hard-hat + roofline mark sitting above/across the "MY".
          MYSiteMark(stroke: markColor)
            .frame(width: s * 1.15, height: s * 0.66)
            .offset(x: s * 0.18, y: -s * 0.46)
        }

      Text("Site")
        .font(.system(size: s * 0.82, weight: .semibold, design: .rounded))
        .foregroundStyle(siteColor)
    }
    .padding(.top, s * 0.42)
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
