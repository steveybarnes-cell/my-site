import SwiftUI

/// My Project Group Ltd brand system.
enum Brand {
  static let charcoal = Color(hex: 0x2A2E2B)
  static let charcoalDeep = Color(hex: 0x1C201D)
  static let olive = Color(hex: 0x6F8F5A)
  static let oliveDark = Color(hex: 0x5A7748)
  static let lightGreen = Color(hex: 0xE7EFE2)
  static let surface = Color.white
  static let ink = Color(hex: 0x23271F)
  static let inkSoft = Color(hex: 0x5F675A)
  static let hairline = Color(hex: 0xDBE3D5)

  // Status palette
  static let amber = Color(hex: 0xC98A2B)
  static let red = Color(hex: 0xB4483C)
  static let blue = Color(hex: 0x3E6C8C)
  static let paidGreen = Color(hex: 0x4E8A46)
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
      .background(Brand.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .stroke(Brand.hairline, lineWidth: 1)
      )
  }

  /// Light green form section background.
  func mpgFormSection(padding: CGFloat = 16) -> some View {
    self
      .padding(padding)
      .background(Brand.lightGreen, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
  }
}

/// Screen background used app-wide.
struct MPGBackground: View {
  var body: some View {
    Brand.lightGreen.opacity(0.5).ignoresSafeArea()
  }
}
