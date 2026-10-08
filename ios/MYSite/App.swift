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
  @Environment(AuthManager.self) private var auth
  @Environment(AppStore.self) private var store
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    @Bindable var auth = auth
    ContentView()
      .onAppear { LocalNotificationService.requestAuthorization() }
      // Anything captured offline goes as soon as the app is back in front.
      .onChange(of: scenePhase) { _, phase in
        if phase == .active { Task { await store.drainSyncQueue() } }
      }
      // Password-reset emails come back in on the app's URL scheme.
      .onOpenURL { url in
        Task { await auth.handleIncoming(url) }
      }
      .fullScreenCover(isPresented: $auth.pendingPasswordReset) {
        SetNewPasswordView()
      }
  }
}
