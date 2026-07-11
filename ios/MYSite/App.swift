import SwiftUI

@main
struct MPGSiteRecordsApp: App {
  @State private var store: AppStore
  @State private var auth: AuthManager
  @State private var location = LocationService()
  @State private var call = CallService()

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
        .environment(call)
        .tint(Brand.olive)
    }
  }
}

/// Hosts the app content and the cross-tab call overlay together, so the overlay
/// is guaranteed to be a descendant of the `.environment(call)` injection above.
private struct RootContainer: View {
  var body: some View {
    ZStack {
      ContentView()
      CallOverlay()
    }
  }
}
