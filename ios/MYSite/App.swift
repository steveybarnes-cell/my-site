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
      ContentView()
        .environment(store)
        .environment(auth)
        .environment(location)
        .environment(call)
        .tint(Brand.olive)
        .overlay { CallOverlay() }
    }
  }
}
