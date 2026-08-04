import SwiftUI

struct ContentView: View {
  @Environment(AppStore.self) private var store
  @Environment(AuthManager.self) private var auth

  var body: some View {
    Group {
      switch auth.phase {
      case .restoring:
        loadingScreen
      case .signedOut:
        LoginView()
      case .signedIn:
        // Deliberately reads `currentUser?.role` rather than `store.role`.
        // `store.role` falls back to `.tradesman` when nobody is signed in,
        // so routing on it would hand the tradesman app to a user with no
        // session. `adopt(_:)` always populates `currentUser` before setting
        // `phase = .signedIn`, so in practice this branch is always taken —
        // the fallback exists purely to fail closed if that ever changes.
        if store.isLiveBackend && store.currentCompanyId == nil {
          // Signed in, but the account belongs to no company. Every row in the
          // database is company-scoped, so the normal app would render as a set
          // of empty lists with nothing explaining why. Guarded on
          // `isLiveBackend` so Demo Mode — which has no company by design —
          // isn't dragged in here.
          CompanySetupView()
        } else if let role = store.currentUser?.role {
          switch role {
          case .tradesman: TradesmanRootView()
          case .siteManager: SiteManagerRootView()
          case .admin: AdminRootView()
          }
        } else {
          loadingScreen
        }
      }
    }
    .task { await auth.restore() }
    .__tenxTrackView("ContentView")
  }

  private var loadingScreen: some View {
    ZStack {
      Brand.charcoal.ignoresSafeArea()
      VStack(spacing: 16) {
        MPGLogo(height: 108)
        ProgressView().tint(.white)
      }
    }
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
