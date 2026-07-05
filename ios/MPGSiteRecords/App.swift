import SwiftUI

@main
struct MPGSiteRecordsApp: App {
  @State private var store = AppStore()
  @State private var location = LocationService()

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(store)
        .environment(location)
        .tint(Brand.olive)
    }
  }
}
