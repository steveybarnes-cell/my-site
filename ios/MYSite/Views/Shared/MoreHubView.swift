import SwiftUI

/// A single navigable destination shown in the More hub.
struct MoreHubItem: Identifiable {
  let id = UUID()
  let title: String
  let subtitle: String
  let symbol: String
  var tint: Color = Brand.olive
  var badge: Int = 0
  let destination: AnyView

  init<Destination: View>(
    title: String,
    subtitle: String,
    symbol: String,
    tint: Color = Brand.olive,
    badge: Int = 0,
    @ViewBuilder destination: () -> Destination
  ) {
    self.title = title
    self.subtitle = subtitle
    self.symbol = symbol
    self.tint = tint
    self.badge = badge
    self.destination = AnyView(destination())
  }
}

/// Reusable secondary-navigation hub. Keeps the main tab bar to five items by
/// collecting less-frequent areas here in one predictable, scannable place.
struct MoreHubView: View {
  let roleTitle: String
  let roleSymbol: String
  let items: [MoreHubItem]

  var body: some View {
    Group {
      NavigationStack {
        ZStack {
          MPGBackground()
          ScrollView {
            VStack(spacing: 14) {
              header
              VStack(spacing: 10) {
                ForEach(items) { item in
                  NavigationLink {
                    item.destination
                  } label: {
                    MoreHubRow(item: item)
                  }
                  .buttonStyle(.plain)
                }
              }
            }
            .padding(16)
          }
        }
        .navigationTitle("More")
      }
    }
    .__tenxTrackView("MoreHubView")
  }

  private var header: some View {
    HStack(spacing: 14) {
      Image(systemName: roleSymbol)
        .font(.title2)
        .foregroundStyle(.white)
        .frame(width: 46, height: 46)
        .background(Brand.olive, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
      VStack(alignment: .leading, spacing: 3) {
        MPGLogo(height: 34)
        Text(roleTitle)
          .font(.subheadline)
          .foregroundStyle(.white.opacity(0.75))
      }
      Spacer()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(18)
    .background(Brand.charcoal, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
  }
}

private struct MoreHubRow: View {
  let item: MoreHubItem

  var body: some View {
    HStack(spacing: 14) {
      Image(systemName: item.symbol)
        .font(.headline)
        .foregroundStyle(item.tint)
        .frame(width: 42, height: 42)
        .background(
          item.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
      VStack(alignment: .leading, spacing: 2) {
        Text(item.title)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(Brand.ink)
        Text(item.subtitle)
          .font(.caption)
          .foregroundStyle(Brand.inkSoft)
          .lineLimit(1)
      }
      Spacer(minLength: 8)
      if item.badge > 0 {
        Text("\(item.badge)")
          .font(.caption2.weight(.bold))
          .foregroundStyle(.white)
          .padding(.horizontal, 7)
          .padding(.vertical, 3)
          .background(Brand.red, in: Capsule())
      }
      Image(systemName: "chevron.right")
        .font(.caption.weight(.semibold))
        .foregroundStyle(Brand.inkSoft)
    }
    .mpgCard(padding: 12)
  }
}
