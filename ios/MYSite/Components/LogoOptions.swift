import SwiftUI

/// Six candidate brand marks for "MY Site", each drawn as crisp vector paths
/// in the Brand palette. Presented in `LogoGalleryView` so the user can pick
/// one; the winner gets promoted into `MPGLogo`.
///
/// All marks accept an `ink` and `accent` colour so they blend on any surface.
struct LogoOption: Identifiable {
  let id: Int
  let name: String
  let subtitle: String
}

/// Normalised point helper (0...1 space) usable inside ViewBuilder closures.
private func pt(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGPoint {
  CGPoint(x: x * w, y: y * h)
}

// MARK: - Option 1 · Monogram tile "MS"

/// A rounded-square badge with an "MS" monogram — clean, app-icon friendly.
struct LogoMarkMonogram: View {
  var ink: Color = Brand.ink
  var accent: Color = Brand.logoGreen

  var body: some View {
    GeometryReader { geo in
      let s = min(geo.size.width, geo.size.height)
      ZStack {
        RoundedRectangle(cornerRadius: s * 0.24, style: .continuous)
          .fill(accent)
        Text("MS")
          .font(.system(size: s * 0.42, weight: .heavy, design: .rounded))
          .foregroundStyle(.white)
          .kerning(-s * 0.01)
      }
      .frame(width: s, height: s)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }
}

// MARK: - Option 2 · House + checkmark

/// A simple house outline with a checkmark inside — "site signed off".
struct LogoMarkHouseCheck: View {
  var ink: Color = Brand.ink
  var accent: Color = Brand.logoGreen

  var body: some View {
    GeometryReader { geo in
      let w = geo.size.width
      let h = geo.size.height
      let lw = max(2, min(w, h) * 0.09)
      func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { pt(x, y, w, h) }
      return ZStack {
        Path { path in
          path.move(to: p(0.5, 0.08))
          path.addLine(to: p(0.9, 0.42))
          path.addLine(to: p(0.9, 0.92))
          path.addLine(to: p(0.1, 0.92))
          path.addLine(to: p(0.1, 0.42))
          path.closeSubpath()
        }
        .stroke(ink, style: StrokeStyle(lineWidth: lw, lineJoin: .round))
        Path { path in
          path.move(to: p(0.32, 0.66))
          path.addLine(to: p(0.45, 0.79))
          path.addLine(to: p(0.70, 0.52))
        }
        .stroke(accent, style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))
      }
    }
  }
}

// MARK: - Option 3 · Hard hat (clean)

/// A crisp, symmetric builder's hard hat — the trade cue done properly.
struct LogoMarkHardHat: View {
  var ink: Color = Brand.ink
  var accent: Color = Brand.logoGreen

  var body: some View {
    GeometryReader { geo in
      let w = geo.size.width
      let h = geo.size.height
      func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { pt(x, y, w, h) }
      return ZStack {
        // Dome
        Path { path in
          path.move(to: p(0.20, 0.66))
          path.addCurve(to: p(0.80, 0.66), control1: p(0.20, 0.24), control2: p(0.80, 0.24))
          path.closeSubpath()
        }
        .fill(accent)
        // Ridge cap
        Path { path in
          path.addRoundedRect(
            in: CGRect(x: 0.46 * w, y: 0.24 * h, width: 0.08 * w, height: 0.42 * h),
            cornerSize: CGSize(width: 0.03 * w, height: 0.03 * w))
        }
        .fill(ink.opacity(0.85))
        // Brim
        Capsule()
          .fill(ink)
          .frame(width: w * 0.9, height: h * 0.12)
          .position(p(0.5, 0.72))
      }
    }
  }
}

// MARK: - Option 4 · Level / plumb (chevron in circle)

/// A ring with an upward chevron — precision, levelling, "on the up".
struct LogoMarkChevronRing: View {
  var ink: Color = Brand.ink
  var accent: Color = Brand.logoGreen

  var body: some View {
    GeometryReader { geo in
      let w = geo.size.width
      let h = geo.size.height
      let lw = max(2, min(w, h) * 0.1)
      func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { pt(x, y, w, h) }
      return ZStack {
        Circle()
          .stroke(ink, lineWidth: lw)
          .padding(lw / 2)
        Path { path in
          path.move(to: p(0.30, 0.60))
          path.addLine(to: p(0.5, 0.38))
          path.addLine(to: p(0.70, 0.60))
        }
        .stroke(accent, style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))
        Path { path in
          path.move(to: p(0.30, 0.72))
          path.addLine(to: p(0.5, 0.50))
          path.addLine(to: p(0.70, 0.72))
        }
        .stroke(
          accent.opacity(0.5), style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))
      }
    }
  }
}

// MARK: - Option 5 · Brick / block M

/// Stacked blocks forming an implied "M" — building, records, structure.
struct LogoMarkBlocks: View {
  var ink: Color = Brand.ink
  var accent: Color = Brand.logoGreen

  var body: some View {
    GeometryReader { geo in
      let w = geo.size.width
      let h = geo.size.height
      let g = min(w, h) * 0.06
      let cw = (w - g) / 2
      let ch = (h - g) / 2
      let r = min(w, h) * 0.08
      ZStack {
        block(x: 0, y: 0, cw: cw, ch: ch, r: r, color: accent)
        block(x: cw + g, y: 0, cw: cw, ch: ch, r: r, color: ink)
        block(x: 0, y: ch + g, cw: cw, ch: ch, r: r, color: ink.opacity(0.75))
        block(x: cw + g, y: ch + g, cw: cw, ch: ch, r: r, color: accent.opacity(0.8))
      }
    }
  }

  private func block(x: CGFloat, y: CGFloat, cw: CGFloat, ch: CGFloat, r: CGFloat, color: Color)
    -> some View
  {
    RoundedRectangle(cornerRadius: r, style: .continuous)
      .fill(color)
      .frame(width: cw, height: ch)
      .position(x: x + cw / 2, y: y + ch / 2)
  }
}

// MARK: - Option 6 · Roofline wordmark badge

/// A pill badge holding "MS" under a pitched roofline stroke — signage feel.
struct LogoMarkRoofBadge: View {
  var ink: Color = Brand.ink
  var accent: Color = Brand.logoGreen

  var body: some View {
    GeometryReader { geo in
      let w = geo.size.width
      let h = geo.size.height
      let lw = max(2, min(w, h) * 0.08)
      func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { pt(x, y, w, h) }
      return ZStack {
        RoundedRectangle(cornerRadius: min(w, h) * 0.2, style: .continuous)
          .fill(ink)
        Path { path in
          path.move(to: p(0.18, 0.44))
          path.addLine(to: p(0.5, 0.22))
          path.addLine(to: p(0.82, 0.44))
        }
        .stroke(accent, style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))
        Text("MS")
          .font(.system(size: min(w, h) * 0.3, weight: .heavy, design: .rounded))
          .foregroundStyle(.white)
          .position(p(0.5, 0.68))
      }
    }
  }
}
