import SwiftUI

struct ContentView: View {
  @Environment(AppStore.self) private var store

  var body: some View {
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
}

#Preview {
  ContentView().environment(AppStore())
}
