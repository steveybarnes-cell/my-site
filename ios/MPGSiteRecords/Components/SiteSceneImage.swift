import SwiftUI

extension Color {
  /// String-hex convenience (e.g. "#6E5A44") used by the rendered site scenes.
  fileprivate static func scene(_ string: String) -> Color {
    let cleaned = string.hasPrefix("#") ? String(string.dropFirst()) : string
    let value = UInt(cleaned, radix: 16) ?? 0
    return Color(hex: value)
  }
}

/// Renders a believable construction-site "photo" entirely in SwiftUI, so the
/// demo feed shows authentic-looking site imagery without bundling any external
/// photo assets. Each `scene` key maps to a recognisable scene (dig-out,
/// freshly painted hallway, brickwork, screed, etc.).
struct SiteSceneImage: View {
  let scene: SiteScene

  var body: some View {
    GeometryReader { geo in
      let w = geo.size.width
      let h = geo.size.height
      ZStack {
        scene.sky
        sceneContent(w: w, h: h)
        LinearGradient(
          colors: [.black.opacity(0.0), .black.opacity(0.18)],
          startPoint: .center, endPoint: .bottom)
      }
      .overlay(alignment: .bottomLeading) {
        Text(scene.stamp)
          .font(.system(size: 9, weight: .semibold, design: .monospaced))
          .foregroundStyle(.white.opacity(0.9))
          .padding(.horizontal, 6)
          .padding(.vertical, 3)
          .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 4))
          .padding(8)
      }
    }
  }

  @ViewBuilder
  private func sceneContent(w: CGFloat, h: CGFloat) -> some View {
    switch scene {
    case .digOut: DigOutScene(w: w, h: h)
    case .hallwayPaint: HallwayPaintScene(w: w, h: h)
    case .brickwork: BrickworkScene(w: w, h: h)
    case .screed: ScreedScene(w: w, h: h)
    case .scaffold: ScaffoldScene(w: w, h: h)
    case .kitchenFit: KitchenFitScene(w: w, h: h)
    }
  }
}

// MARK: - Scene catalogue

enum SiteScene: String, CaseIterable {
  case digOut
  case hallwayPaint
  case brickwork
  case screed
  case scaffold
  case kitchenFit

  /// Maps legacy seed keys / free text to a scene.
  init(key: String) {
    switch key {
    case "digOut", "photo.fill": self = .digOut
    case "hallwayPaint", "photo": self = .hallwayPaint
    case "brickwork", "photo.stack": self = .brickwork
    case "screed": self = .screed
    case "scaffold": self = .scaffold
    case "kitchenFit": self = .kitchenFit
    default: self = SiteScene.allCases.randomElement() ?? .digOut
    }
  }

  var sky: LinearGradient {
    switch self {
    case .digOut: return Self.grad("#AEB9C4", "#8A98A6")
    case .hallwayPaint, .kitchenFit: return Self.grad("#F2EFE9", "#DAD5CC")
    case .brickwork: return Self.grad("#B7C2CC", "#94A2AE")
    case .screed: return Self.grad("#CDCBC6", "#A8A6A0")
    case .scaffold: return Self.grad("#B9C6D2", "#8FA0AE")
    }
  }

  var stamp: String {
    switch self {
    case .digOut: return "07:52 · CLIFTON"
    case .hallwayPaint: return "16:20 · MARLBOROUGH"
    case .brickwork: return "11:05 · SITE"
    case .screed: return "09:41 · SITE"
    case .scaffold: return "08:15 · SITE"
    case .kitchenFit: return "14:30 · SITE"
    }
  }

  private static func grad(_ a: String, _ b: String) -> LinearGradient {
    LinearGradient(
      colors: [Color.scene(a), Color.scene(b)],
      startPoint: .top, endPoint: .bottom)
  }
}

// MARK: - Individual scenes

private struct DigOutScene: View {
  let w: CGFloat
  let h: CGFloat
  var body: some View {
    ZStack {
      Path { p in
        p.move(to: CGPoint(x: 0, y: h * 0.45))
        p.addLine(to: CGPoint(x: w, y: h * 0.4))
        p.addLine(to: CGPoint(x: w, y: h))
        p.addLine(to: CGPoint(x: 0, y: h))
        p.closeSubpath()
      }
      .fill(
        LinearGradient(
          colors: [Color.scene("#6E5A44"), Color.scene("#4F4030")],
          startPoint: .top, endPoint: .bottom))
      Path { p in
        p.move(to: CGPoint(x: w * 0.18, y: h * 0.5))
        p.addLine(to: CGPoint(x: w * 0.72, y: h * 0.52))
        p.addLine(to: CGPoint(x: w * 0.6, y: h * 0.95))
        p.addLine(to: CGPoint(x: w * 0.1, y: h * 0.9))
        p.closeSubpath()
      }
      .fill(Color.scene("#33291E"))
      Ellipse()
        .fill(Color.scene("#7A6349"))
        .frame(width: w * 0.4, height: h * 0.18)
        .position(x: w * 0.82, y: h * 0.55)
      WorkerFigure(color: Color.scene("#F4A81D"))
        .frame(width: w * 0.12, height: h * 0.34)
        .position(x: w * 0.3, y: h * 0.45)
    }
  }
}

private struct HallwayPaintScene: View {
  let w: CGFloat
  let h: CGFloat
  var body: some View {
    ZStack {
      Rectangle().fill(Color.scene("#F6F3EC")).frame(height: h)
      Path { p in
        p.move(to: .zero)
        p.addLine(to: CGPoint(x: w * 0.32, y: h * 0.2))
        p.addLine(to: CGPoint(x: w * 0.32, y: h * 0.82))
        p.addLine(to: CGPoint(x: 0, y: h))
        p.closeSubpath()
      }.fill(Color.scene("#E7E2D8"))
      Path { p in
        p.move(to: CGPoint(x: w, y: 0))
        p.addLine(to: CGPoint(x: w * 0.68, y: h * 0.2))
        p.addLine(to: CGPoint(x: w * 0.68, y: h * 0.82))
        p.addLine(to: CGPoint(x: w, y: h))
        p.closeSubpath()
      }.fill(Color.scene("#EDE8DF"))
      Path { p in
        p.move(to: CGPoint(x: w * 0.32, y: h * 0.82))
        p.addLine(to: CGPoint(x: w * 0.68, y: h * 0.82))
        p.addLine(to: CGPoint(x: w, y: h))
        p.addLine(to: CGPoint(x: 0, y: h))
        p.closeSubpath()
      }.fill(Color.scene("#C9BFA9"))
      RoundedRectangle(cornerRadius: 2)
        .fill(Color.scene("#4A4A4A"))
        .frame(width: w * 0.16, height: h * 0.4)
        .position(x: w * 0.5, y: h * 0.5)
      LadderShape()
        .stroke(Color.scene("#C0362C"), lineWidth: 3)
        .frame(width: w * 0.14, height: h * 0.36)
        .position(x: w * 0.24, y: h * 0.62)
    }
  }
}

private struct BrickworkScene: View {
  let w: CGFloat
  let h: CGFloat
  var body: some View {
    ZStack {
      Rectangle().fill(Color.scene("#9AA6B0"))
      let rows = 9
      let cols = 6
      let bw = w / CGFloat(cols)
      let bh = (h * 0.75) / CGFloat(rows)
      ForEach(0..<rows, id: \.self) { r in
        ForEach(0..<cols + 1, id: \.self) { c in
          let offset = r.isMultiple(of: 2) ? 0 : bw / 2
          RoundedRectangle(cornerRadius: 1)
            .fill(Color.scene(r.isMultiple(of: 3) ? "#A6533B" : "#B4614A"))
            .frame(width: bw - 3, height: bh - 3)
            .position(
              x: CGFloat(c) * bw - offset + bw / 2,
              y: h * 0.25 + CGFloat(r) * bh + bh / 2)
        }
      }
    }
    .clipped()
  }
}

private struct ScreedScene: View {
  let w: CGFloat
  let h: CGFloat
  var body: some View {
    ZStack {
      Rectangle().fill(Color.scene("#C4C2BC"))
      Ellipse()
        .fill(Color.white.opacity(0.18))
        .frame(width: w * 0.7, height: h * 0.3)
        .position(x: w * 0.55, y: h * 0.55)
      Rectangle()
        .fill(Color.scene("#DAD6CE"))
        .frame(height: h * 0.35)
        .position(x: w / 2, y: h * 0.17)
      ForEach(0..<5, id: \.self) { i in
        Capsule()
          .fill(Color.black.opacity(0.05))
          .frame(width: w * 0.8, height: 2)
          .position(x: w / 2, y: h * 0.5 + CGFloat(i) * h * 0.09)
      }
    }
    .clipped()
  }
}

private struct ScaffoldScene: View {
  let w: CGFloat
  let h: CGFloat
  var body: some View {
    ZStack {
      Rectangle().fill(Color.scene("#C7BEA8")).frame(height: h).position(x: w / 2, y: h / 2)
      ForEach(0..<3, id: \.self) { r in
        ForEach(0..<3, id: \.self) { c in
          Rectangle()
            .fill(Color.scene("#5C6B78"))
            .frame(width: w * 0.16, height: h * 0.16)
            .position(x: w * (0.24 + Double(c) * 0.26), y: h * (0.24 + Double(r) * 0.26))
        }
      }
      ForEach(0..<4, id: \.self) { c in
        Rectangle().fill(Color.scene("#8A8F96"))
          .frame(width: 3, height: h)
          .position(x: w * (0.15 + Double(c) * 0.24), y: h / 2)
      }
      ForEach(0..<4, id: \.self) { r in
        Rectangle().fill(Color.scene("#8A8F96"))
          .frame(width: w, height: 3)
          .position(x: w / 2, y: h * (0.2 + Double(r) * 0.25))
      }
    }
    .clipped()
  }
}

private struct KitchenFitScene: View {
  let w: CGFloat
  let h: CGFloat
  var body: some View {
    ZStack {
      Rectangle().fill(Color.scene("#EDE9E2"))
      Rectangle().fill(Color.scene("#B9A98C"))
        .frame(height: h * 0.28).position(x: w / 2, y: h * 0.86)
      RoundedRectangle(cornerRadius: 3)
        .fill(Color.scene("#4C5560"))
        .frame(width: w * 0.8, height: h * 0.28)
        .position(x: w / 2, y: h * 0.62)
      RoundedRectangle(cornerRadius: 2)
        .fill(Color.scene("#2E3338"))
        .frame(width: w * 0.86, height: h * 0.06)
        .position(x: w / 2, y: h * 0.46)
      ForEach(0..<3, id: \.self) { c in
        RoundedRectangle(cornerRadius: 3)
          .fill(Color.scene("#E4E0D8"))
          .stroke(Color.black.opacity(0.08))
          .frame(width: w * 0.22, height: h * 0.18)
          .position(x: w * (0.24 + Double(c) * 0.26), y: h * 0.28)
      }
    }
    .clipped()
  }
}

// MARK: - Shared figures

private struct WorkerFigure: View {
  let color: Color
  var body: some View {
    GeometryReader { g in
      let w = g.size.width
      let h = g.size.height
      ZStack {
        RoundedRectangle(cornerRadius: w * 0.2)
          .fill(color)
          .frame(width: w, height: h * 0.55)
          .position(x: w / 2, y: h * 0.55)
        Circle().fill(Color.scene("#E8B98B"))
          .frame(width: w * 0.55, height: w * 0.55)
          .position(x: w / 2, y: h * 0.2)
        Path { p in
          p.addArc(
            center: CGPoint(x: w / 2, y: h * 0.2), radius: w * 0.32,
            startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
        }.fill(Color.scene("#F4C21D"))
      }
    }
  }
}

private struct LadderShape: Shape {
  func path(in rect: CGRect) -> Path {
    var p = Path()
    p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
    p.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
    p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
    for i in 1...3 {
      let y = rect.minY + rect.height * (CGFloat(i) / 4)
      let inset = rect.width * (CGFloat(i) / 8)
      p.move(to: CGPoint(x: rect.minX + inset, y: y))
      p.addLine(to: CGPoint(x: rect.maxX - inset, y: y))
    }
    return p
  }
}

#Preview {
  ScrollView {
    VStack(spacing: 16) {
      ForEach(SiteScene.allCases, id: \.self) { s in
        SiteSceneImage(scene: s)
          .frame(height: 220)
          .clipShape(RoundedRectangle(cornerRadius: 14))
      }
    }
    .padding()
  }
}
