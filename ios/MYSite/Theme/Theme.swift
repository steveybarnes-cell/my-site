import SwiftUI

/// My Project Group Ltd brand system.
enum Brand {
  static let charcoal = Color(hex: 0x2A2E2B)
  static let charcoalDeep = Color(hex: 0x1C201D)
  static let olive = Color(hex: 0x6F8F5A)
  static let oliveDark = Color(hex: 0x5A7748)
  /// Muted sage/olive green used in the official MY PROJECT GROUP wordmark.
  static let logoGreen = Color(hex: 0x7D9B62)
  static let lightGreen = Color(hex: 0xE7EFE2)
  /// Bright completion accent used sparingly for live activity and positive momentum.
  static let lime = Color(hex: 0xB8E34A)
  /// Clear, modern information accent for active work and live updates.
  static let electricBlue = Color(hex: 0x4B7BFF)
  static let surface = Color.white
  static let ink = Color(hex: 0x23271F)
  static let inkSoft = Color(hex: 0x5F675A)
  static let hairline = Color(hex: 0xDBE3D5)

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
  static let cardShadow = Color(hex: 0x1C201D, alpha: 0.05)
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
