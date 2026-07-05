import SwiftUI

@main
struct MPGSiteRecordsApp: App {
  @State private var store = AppStore()

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(store)
        .tint(Brand.olive)
    }
  }
}
