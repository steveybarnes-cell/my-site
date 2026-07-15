import SwiftUI

@main
struct MPGSiteRecordsApp: App {
  @State private var store: AppStore
  @State private var auth: AuthManager
  @State private var location = LocationService()

  init() {
    let store = AppStore()
    _store = State(initialValue: store)
    _auth = State(initialValue: AuthManager(store: store))
  }

  var body: some Scene {
    WindowGroup {
      RootContainer()
        .environment(store)
        .environment(auth)
        .environment(location)
        .tint(Brand.olive)
    }
  }
}

private struct RootContainer: View {
  var body: some View {
    ContentView()
      .onAppear { LocalNotificationService.requestAuthorization() }
  }
}
