import SwiftUI

struct ContentView: View {
  @Environment(AppStore.self) private var store

  var body: some View {
    Group {
      Group {
        if store.currentUser == nil {
          LoginView()
        } else {
          switch store.role {
          case .tradesman: TradesmanRootView()
          case .siteManager: SiteManagerRootView()
          case .admin: AdminRootView()
          }
        }
      }
    }
    .__tenxTrackView("ContentView")
  }
}

#Preview {
  ContentView().environment(AppStore())
}
