import SwiftUI

/// The house / frame mark from the official My Project Group logo:
/// a wide double-peak outline that reads like two joined roof trusses.
/// Drawn as a stroked path so it stays crisp at any size.
struct MPGFrameMark: Shape {
  func path(in rect: CGRect) -> Path {
    let w = rect.width
    let h = rect.height
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
      CGPoint(x: rect.minX + x * w, y: rect.minY + y * h)
    }

    var path = Path()

    // Left outer wall up to the first apex.
    path.move(to: p(0.0, 1.0))
    path.addLine(to: p(0.0, 0.32))
    path.addLine(to: p(0.25, 0.0))
    path.addLine(to: p(0.5, 0.32))
    path.addLine(to: p(0.5, 1.0))

    // Right peak sharing the centre column.
    path.move(to: p(0.5, 0.32))
    path.addLine(to: p(0.75, 0.0))
    path.addLine(to: p(1.0, 0.32))
    path.addLine(to: p(1.0, 1.0))

    return path
  }
}

/// Faithful vector rendition of the My Project Group wordmark:
/// green "MY", the white double-peak frame, white "PROJECT", green "GROUP".
struct MPGLogo: View {
  /// Overall height of the "MY + frame" top row.
  var height: CGFloat = 72
  /// Text/mark colour for the dark-charcoal versions of the logo.
  var onDark: Bool = true

  private var white: Color { onDark ? .white : Brand.ink }

  var body: some View {
    let topSize = height
    VStack(alignment: .center, spacing: topSize * 0.06) {
      // Top row: MY + house frame
      HStack(alignment: .center, spacing: topSize * 0.06) {
        Text("MY")
          .font(.system(size: topSize * 0.92, weight: .heavy, design: .rounded))
          .foregroundStyle(Brand.logoGreen)

        MPGFrameMark()
          .stroke(
            white,
            style: StrokeStyle(
              lineWidth: max(2, topSize * 0.055), lineCap: .round, lineJoin: .round)
          )
          .frame(width: topSize * 1.05, height: topSize * 0.72)
      }

      // PROJECT
      Text("PROJECT")
        .font(.system(size: topSize * 0.5, weight: .bold, design: .rounded))
        .tracking(topSize * 0.02)
        .foregroundStyle(white)

      // GROUP, right-aligned under PROJECT
      Text("GROUP")
        .font(.system(size: topSize * 0.24, weight: .semibold, design: .rounded))
        .tracking(topSize * 0.06)
        .foregroundStyle(Brand.logoGreen)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.trailing, topSize * 0.08)
    }
    .fixedSize()
  }
}

#Preview {
  ZStack {
    Brand.charcoal.ignoresSafeArea()
    MPGLogo(height: 80)
  }
}
