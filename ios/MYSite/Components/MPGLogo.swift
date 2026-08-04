import SwiftUI

/// The MY Site bracket: an open rounded frame that wraps the wordmark.
///
/// Replaces the earlier gable "^". The bracket runs from a short stub at the
/// bottom-left, up the left side, across the top, and stops partway down the
/// right — deliberately open, so the wordmark sits *in* it rather than under a
/// closed box.
struct MYSiteMark: View {
  /// Colour of the bracket stroke.
  var stroke: Color = Brand.logoGreen
  /// Retained for source compatibility with older call sites.
  var accent: Color = Brand.logoGreen

  var body: some View {
    GeometryReader { geo in
      BracketShape()
        .stroke(
          stroke,
          style: StrokeStyle(
            lineWidth: max(1.5, min(geo.size.width, geo.size.height) * 0.052),
            lineCap: .round,
            lineJoin: .round)
        )
    }
  }
}

/// The open frame. Proportions traced from the brand sheet.
private struct BracketShape: Shape {
  func path(in rect: CGRect) -> Path {
    let w = rect.width
    let h = rect.height
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
      CGPoint(x: rect.minX + x * w, y: rect.minY + y * h)
    }
    // Corner radius as a fraction of the shorter side, so the curve stays
    // circular rather than stretching when the frame isn't square.
    let r: CGFloat = 0.17

    var path = Path()
    // Bottom-left stub, running inward from the left.
    path.move(to: p(0.22, 0.97))
    path.addLine(to: p(0.03 + r, 0.97))
    path.addQuadCurve(to: p(0.03, 0.97 - r), control: p(0.03, 0.97))
    // Up the left side.
    path.addLine(to: p(0.03, 0.03 + r))
    path.addQuadCurve(to: p(0.03 + r, 0.03), control: p(0.03, 0.03))
    // Across the top.
    path.addLine(to: p(0.97 - r, 0.03))
    path.addQuadCurve(to: p(0.97, 0.03 + r), control: p(0.97, 0.03))
    // Short stub down the right, then stop — the frame stays open.
    path.addLine(to: p(0.97, 0.26))
    return path
  }
}

/// "MY Site" logo lockup: the bracket with the wordmark set inside it.
///
/// Kept named `MPGLogo` so existing call sites continue to work.
struct MPGLogo: View {
  /// Overall height of the lockup. Everything scales from this.
  var height: CGFloat = 72
  /// Render for a dark background (white "MY") when true.
  var onDark: Bool = true
  /// Lay the mark and wordmark side-by-side instead of nested.
  var horizontal: Bool = false
  /// Retained for source compatibility with older call sites.
  var showTagline: Bool = false

  private var myColor: Color { onDark ? .white : Brand.ink }
  private var accentColor: Color { onDark ? Brand.logoGreen : Brand.oliveDark }

  var body: some View {
    if horizontal {
      horizontalLockup
    } else {
      nestedLockup
    }
  }

  /// The brand lockup, as artwork.
  ///
  /// This used to be assembled here: a `BracketShape` with SF Rounded text laid
  /// over it, nudged into place by eye. It was close. Close is the problem —
  /// the launch screen shows the real logo, and a hand-built near-copy one
  /// screen later reads as a rendering fault rather than a design.
  ///
  /// `MYSiteLockup` is the brand artwork itself, traced from the master, so
  /// there is nothing left to drift. It is the dark-background lockup: the "MY"
  /// is white. A light-background version needs its own asset rather than a
  /// colour swap here, because inverting a wordmark is a brand decision.
  private var nestedLockup: some View {
    Image("MYSiteLockup")
      .resizable()
      .scaledToFit()
      .frame(height: height)
      .accessibilityLabel("MY Site")
  }

  /// Bracket beside the wordmark, for tight horizontal spaces like nav bars.
  private var horizontalLockup: some View {
    let s = height
    return HStack(spacing: s * 0.22) {
      MYSiteMark(stroke: accentColor)
        .frame(width: s * 0.82, height: s * 0.82)
      VStack(alignment: .leading, spacing: -s * 0.03) {
        Text("MY")
          .font(.system(size: s * 0.46, weight: .heavy, design: .rounded))
          .foregroundStyle(myColor)
        Text("SITE")
          .font(.system(size: s * 0.16, weight: .bold, design: .rounded))
          .kerning(s * 0.10)
          .foregroundStyle(accentColor)
      }
    }
    .fixedSize()
  }
}

#Preview {
  VStack(spacing: 0) {
    ZStack {
      Brand.charcoal.ignoresSafeArea()
      MPGLogo(height: 160)
    }
    ZStack {
      Brand.charcoal.ignoresSafeArea()
      MPGLogo(height: 44, horizontal: true)
    }
  }
}
