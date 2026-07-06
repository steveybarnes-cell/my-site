import SwiftUI

struct ContentView: View {
  @Environment(AppStore.self) private var store
  @Environment(AuthManager.self) private var auth

  var body: some View {
    Group {
      switch auth.phase {
      case .restoring:
        ZStack {
          Brand.charcoal.ignoresSafeArea()
          VStack(spacing: 16) {
            MPGLogo(height: 54)
            ProgressView().tint(.white)
          }
        }
      case .signedOut:
        LoginView()
      case .signedIn:
        switch store.role {
        case .tradesman: TradesmanRootView()
        case .siteManager: SiteManagerRootView()
        case .admin: AdminRootView()
        }
      }
    }
    .task { await auth.restore() }
    .__tenxTrackView("ContentView")
  }
}

private struct ContentPreview: View {
  @State private var store = AppStore()
  var body: some View {
    ContentView()
      .environment(store)
      .environment(AuthManager(store: store))
  }
}

#Preview { ContentPreview() }
