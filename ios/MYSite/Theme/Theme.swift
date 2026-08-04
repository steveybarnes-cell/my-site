import SwiftUI

/// My Project Group Ltd brand system.
enum Brand {
  // Sampled straight from the MY Site brand sheet rather than eyeballed. The
  // palette moved from a warm olive-grey to a cool near-black with a punchier
  // yellow-green, so anything that reads "warm" here is now deliberate.
  static let charcoal = Color(hex: 0x14171D)
  static let charcoalDeep = Color(hex: 0x0E1116)
  /// Primary action colour — buttons, links, active state. The brand green.
  static let olive = Color(hex: 0x7F9E4B)
  static let oliveDark = Color(hex: 0x66803C)
  /// Same green; kept as its own name because the wordmark is allowed to
  /// diverge from the UI accent later without dragging every button with it.
  static let logoGreen = Color(hex: 0x7F9E4B)
  static let lightGreen = Color(hex: 0xEEF2E4)
  /// Bright completion accent used sparingly for live activity and positive momentum.
  static let lime = Color(hex: 0xB8E34A)
  /// Clear, modern information accent for active work and live updates.
  static let electricBlue = Color(hex: 0x4B7BFF)
  static let surface = Color.white
  // Cooled to match the new background. Warm ink over a cool near-black reads
  // muddy where the two meet.
  static let ink = Color(hex: 0x1A1D23)
  static let inkSoft = Color(hex: 0x5C626C)
  static let hairline = Color(hex: 0xE0E3DC)

  // Status palette
  static let amber = Color(hex: 0xC98A2B)
  static let red = Color(hex: 0xB4483C)
  static let blue = Color(hex: 0x3E6C8C)
  static let paidGreen = Color(hex: 0x4E8A46)

  /// Shared corner radii. Outer surfaces are rounder than the blocks nested
  /// inside them, so cards read as a container rather than a flat stack.
  enum Radius {
    /// Top-level content cards and feed posts.
    static let card: CGFloat = 20
    /// Feature surfaces that sit above the feed, e.g. the pulse header.
    static let feature: CGFloat = 22
    /// Blocks nested inside a card (form sections, tiles, banners).
    static let inner: CGFloat = 14
    /// Small chips and count cells.
    static let chip: CGFloat = 12
  }

  /// Soft, low-contrast elevation. Kept subtle so the olive stays the loudest
  /// thing on screen.
  static let cardShadow = Color(hex: 0x0E1116, alpha: 0.06)
}

extension Color {
  init(hex: UInt, alpha: Double = 1) {
    self.init(
      .sRGB,
      red: Double((hex >> 16) & 0xFF) / 255,
      green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255,
      opacity: alpha
    )
  }
}

extension View {
  /// Standard white content card used across the app.
  func mpgCard(padding: CGFloat = 16) -> some View {
    self
      .padding(padding)
      .background(
        Brand.surface, in: RoundedRectangle(cornerRadius: Brand.Radius.card, style: .continuous)
      )
      .overlay(
        RoundedRectangle(cornerRadius: Brand.Radius.card, style: .continuous)
          .stroke(Brand.hairline.opacity(0.8), lineWidth: 1)
      )
      .shadow(color: Brand.cardShadow, radius: 10, x: 0, y: 4)
  }

  /// Light green form section background. Nested inside `mpgCard`, so it uses
  /// the tighter inner radius.
  func mpgFormSection(padding: CGFloat = 16) -> some View {
    self
      .padding(padding)
      .background(
        Brand.lightGreen, in: RoundedRectangle(cornerRadius: Brand.Radius.inner, style: .continuous))
  }
}

/// Screen background used app-wide. A soft diagonal wash rather than a flat
/// fill, so white cards lift off it, with a trace of the information accent in
/// the far corner to keep it from reading as flat green.
struct MPGBackground: View {
  var body: some View {
    LinearGradient(
      colors: [Brand.lightGreen.opacity(0.78), Color.white, Brand.electricBlue.opacity(0.055)],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
    .ignoresSafeArea()
  }
}
