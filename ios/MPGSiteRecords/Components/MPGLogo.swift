import SwiftUI

/// A clean, unmistakable house mark for My Project Group: a pitched roof
/// over a square body, with a doorway cut in. Drawn as a stroked path so it
/// stays crisp at any size.
struct MPGFrameMark: Shape {
  func path(in rect: CGRect) -> Path {
    let w = rect.width
    let h = rect.height
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
      CGPoint(x: rect.minX + x * w, y: rect.minY + y * h)
    }

    var path = Path()

    // Outer house outline: roof apex + walls + base.
    path.move(to: p(0.08, 0.42))
    path.addLine(to: p(0.50, 0.06))  // up to the ridge
    path.addLine(to: p(0.92, 0.42))  // down the right roof slope
    path.addLine(to: p(0.92, 1.0))  // right wall
    path.addLine(to: p(0.08, 1.0))  // base
    path.addLine(to: p(0.08, 0.42))  // left wall, close

    // Roof eaves: a horizontal line under the roof for a built look.
    path.move(to: p(0.08, 0.42))
    path.addLine(to: p(0.92, 0.42))

    // Doorway.
    path.move(to: p(0.40, 1.0))
    path.addLine(to: p(0.40, 0.66))
    path.addLine(to: p(0.60, 0.66))
    path.addLine(to: p(0.60, 1.0))

    return path
  }
}

/// Faithful vector rendition of the My Project Group wordmark:
/// green "MY", the white double-peak frame, white "PROJECT", green "GROUP"
/// flanked by rules, and an optional "DESIGN & BUILD" tagline.
struct MPGLogo: View {
  /// Overall height of the "MY + frame" top row.
  var height: CGFloat = 72
  /// Text/mark colour for the dark-charcoal versions of the logo.
  var onDark: Bool = true
  /// Show the "DESIGN & BUILD" tagline under GROUP.
  var showTagline: Bool = false

  private var white: Color { onDark ? .white : Brand.ink }

  var body: some View {
    let topSize = height
    VStack(alignment: .center, spacing: topSize * 0.08) {
      // Top row: MY + house frame
      HStack(alignment: .center, spacing: topSize * 0.08) {
        Text("MY")
          .font(.system(size: topSize * 0.92, weight: .heavy, design: .rounded))
          .foregroundStyle(Brand.logoGreen)

        MPGFrameMark()
          .stroke(
            white,
            style: StrokeStyle(
              lineWidth: max(2, topSize * 0.05), lineCap: .round, lineJoin: .round)
          )
          .frame(width: topSize * 1.0, height: topSize * 0.78)
      }

      // PROJECT
      Text("PROJECT")
        .font(.system(size: topSize * 0.5, weight: .bold, design: .rounded))
        .tracking(topSize * 0.03)
        .foregroundStyle(white)

      // GROUP flanked by thin rules, echoing the official lockup.
      HStack(spacing: topSize * 0.12) {
        Rectangle()
          .fill(Brand.logoGreen)
          .frame(height: max(1, topSize * 0.018))
          .frame(maxWidth: .infinity)
        Text("GROUP")
          .font(.system(size: topSize * 0.26, weight: .semibold, design: .rounded))
          .tracking(topSize * 0.09)
          .foregroundStyle(Brand.logoGreen)
          .fixedSize()
        Rectangle()
          .fill(Brand.logoGreen)
          .frame(height: max(1, topSize * 0.018))
          .frame(maxWidth: .infinity)
      }

      if showTagline {
        HStack(spacing: topSize * 0.06) {
          Text("Design")
            .font(.system(size: topSize * 0.34, weight: .semibold, design: .serif))
            .italic()
            .foregroundStyle(Brand.logoGreen)
          Text("& BUILD")
            .font(.system(size: topSize * 0.3, weight: .bold, design: .rounded))
            .tracking(topSize * 0.02)
            .foregroundStyle(white)
        }
        .padding(.top, topSize * 0.02)
      }
    }
    .fixedSize()
  }
}

#Preview {
  ZStack {
    Brand.charcoal.ignoresSafeArea()
    VStack(spacing: 40) {
      MPGLogo(height: 80)
      MPGLogo(height: 60, showTagline: true)
    }
  }
}
