import SwiftUI

/// Per-user notification preferences. Lets each recipient choose which event
/// alerts they receive, plus a master switch. Preferences are stored on-device.
struct NotificationSettingsView: View {
  @Environment(AppStore.self) private var store
  private let prefs = NotificationPreferencesStore.shared

  @State private var muted = false
  @State private var enabled: [String: Bool] = [:]

  private var me: AppUser? { store.currentUser }

  /// Categories relevant to the current role (keeps the list focused).
  private var categories: [NotifyCategory] {
    switch store.role {
    case .admin:
      return [
        .pendingReview, .invoiceSubmitted, .recordSubmitted, .attendance, .fileUploaded,
        .invoicePaid, .invoiceQueried,
      ]
    case .siteManager:
      return [.invoiceSubmitted, .recordSubmitted, .attendance, .fileUploaded]
    case .tradesman:
      return [.workAllocated, .invoiceQueried, .invoicePaid]
    }
  }

  var body: some View {
    ZStack {
      MPGBackground()
      ScrollView {
        VStack(spacing: 16) {
          masterCard
          if !muted { categoriesCard }
          infoCard
        }
        .padding(16)
      }
    }
    .navigationTitle("Notifications")
    .navigationBarTitleDisplayMode(.inline)
    .onAppear(perform: load)
    .__tenxTrackView("NotificationSettingsView")
  }

  private func load() {
    guard let id = me?.id else { return }
    muted = prefs.isMuted(id)
    var map: [String: Bool] = [:]
    for c in categories { map[c.rawValue] = prefs.isEnabled(c, for: id) }
    enabled = map
  }

  private var masterCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      Toggle(isOn: masterBinding) {
        Label("Allow notifications", systemImage: "bell.badge.fill")
          .font(.subheadline.weight(.semibold)).foregroundStyle(Brand.ink)
      }
      .tint(Brand.olive)
      Text("Turn off to silence every alert on this device.")
        .font(.caption).foregroundStyle(Brand.inkSoft)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .mpgCard()
  }

  private var categoriesCard: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("ALERT ME ABOUT")
        .font(.caption2.weight(.bold)).foregroundStyle(Brand.inkSoft)
        .padding(.bottom, 6)
      ForEach(categories) { c in
        Toggle(isOn: binding(for: c)) {
          HStack(spacing: 12) {
            Image(systemName: c.symbol)
              .font(.subheadline).foregroundStyle(Brand.olive)
              .frame(width: 34, height: 34)
              .background(Brand.lightGreen, in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 2) {
              Text(c.title).font(.subheadline.weight(.semibold)).foregroundStyle(Brand.ink)
              Text(c.detail).font(.caption).foregroundStyle(Brand.inkSoft)
            }
          }
        }
        .tint(Brand.olive)
        .padding(.vertical, 6)
        if c != categories.last { Divider().overlay(Brand.hairline) }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .mpgCard()
  }

  private var infoCard: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: "info.circle.fill").foregroundStyle(Brand.olive)
      Text(
        "Alerts appear in your Alerts tab and as a banner on this device. Delivery when the app "
          + "is closed is added once company push is enabled."
      )
      .font(.caption).foregroundStyle(Brand.inkSoft)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .mpgCard(padding: 12)
  }

  private var masterBinding: Binding<Bool> {
    Binding(
      get: { !muted },
      set: { on in
        muted = !on
        if let id = me?.id { prefs.setMuted(!on, for: id) }
        if on { LocalNotificationService.requestAuthorization() }
      })
  }

  private func binding(for c: NotifyCategory) -> Binding<Bool> {
    Binding(
      get: { enabled[c.rawValue] ?? true },
      set: { on in
        enabled[c.rawValue] = on
        if let id = me?.id { prefs.setEnabled(on, category: c, for: id) }
        if on { LocalNotificationService.requestAuthorization() }
      })
  }
}

#Preview {
  NavigationStack {
    NotificationSettingsView().environment(
      {
        let s = AppStore()
        s.login(as: s.tradesmen().first!)
        return s
      }())
  }
}
