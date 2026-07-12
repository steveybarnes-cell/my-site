import SwiftUI

/// Temporary chooser screen showing all candidate marks on both light and dark
/// surfaces. Pick one and I'll wire it into the real `MPGLogo`.
struct LogoGalleryView: View {
  private let options: [LogoOption] = [
    .init(id: 1, name: "1 · Monogram tile", subtitle: "Rounded badge, “MS” — icon-ready"),
    .init(id: 2, name: "2 · House + check", subtitle: "Site signed off"),
    .init(id: 3, name: "3 · Hard hat", subtitle: "Clean trade cue"),
    .init(id: 4, name: "4 · Chevron ring", subtitle: "Precision / on the up"),
    .init(id: 5, name: "5 · Blocks", subtitle: "Structure & records"),
    .init(id: 6, name: "6 · Roof badge", subtitle: "Signage feel"),
  ]

  var body: some View {
    Group {
      NavigationStack {
        ScrollView {
          VStack(spacing: 18) {
            Text("Pick a logo — tell me the number")
              .font(.headline)
              .foregroundStyle(Brand.ink)
              .padding(.top, 8)

            ForEach(options) { option in
              VStack(spacing: 14) {
                HStack {
                  VStack(alignment: .leading, spacing: 2) {
                    Text(option.name).font(.subheadline.weight(.bold))
                    Text(option.subtitle).font(.caption).foregroundStyle(Brand.inkSoft)
                  }
                  Spacer()
                }
                HStack(spacing: 14) {
                  surface(dark: false) { mark(option.id, onDark: false) }
                  surface(dark: true) { mark(option.id, onDark: true) }
                }
              }
              .mpgCard()
            }
          }
          .padding(16)
        }
        .background(Brand.lightGreen.opacity(0.5).ignoresSafeArea())
        .navigationTitle("Logo options")
        .navigationBarTitleDisplayMode(.inline)
      }
    }
    .__tenxTrackView("LogoGalleryView")
  }

  @ViewBuilder
  private func mark(_ id: Int, onDark: Bool) -> some View {
    let ink = onDark ? Color.white : Brand.ink
    let accent = onDark ? Brand.logoGreen : Brand.oliveDark
    switch id {
    case 1: LogoMarkMonogram(ink: ink, accent: accent)
    case 2: LogoMarkHouseCheck(ink: ink, accent: accent)
    case 3: LogoMarkHardHat(ink: ink, accent: accent)
    case 4: LogoMarkChevronRing(ink: ink, accent: accent)
    case 5: LogoMarkBlocks(ink: ink, accent: accent)
    default: LogoMarkRoofBadge(ink: ink, accent: accent)
    }
  }

  @ViewBuilder
  private func surface<Content: View>(dark: Bool, @ViewBuilder content: () -> Content) -> some View
  {
    RoundedRectangle(cornerRadius: 14, style: .continuous)
      .fill(dark ? Brand.charcoal : Brand.surface)
      .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Brand.hairline, lineWidth: 1)
      )
      .frame(height: 110)
      .overlay { content().frame(width: 64, height: 64) }
  }
}

#Preview { LogoGalleryView() }
