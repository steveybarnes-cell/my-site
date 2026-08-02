import Foundation
import Observation

/// Owns the real Supabase auth session and turns it into an `AppUser` for the app.
///
/// Responsibilities:
///   • Restore + refresh a persisted session on launch.
///   • Email/password sign-in and sign-up.
///   • Google OAuth sign-in.
///   • Fetch the signed-in user's `profiles` row (role, name, phone) via PostgREST.
///   • Sign out and clear the Keychain.
///
/// On a successful sign-in it sets `store.currentUser`, which drives role-based routing.
@MainActor
@Observable
final class AuthManager {
  enum Phase: Equatable {
    case restoring
    case signedOut
    case signedIn
  }

  private struct ProfileRow: Decodable {
    let id: String
    let name: String?
    let email: String?
    let role: String?
    let phone: String?
    let active: Bool?
    let company_id: String?
  }

  private static let sessionKey = "supabase_session"

  var phase: Phase = .restoring
  var isWorking = false
  var errorMessage: String?

  private(set) var session: SupabaseSession?
  private let store: AppStore

  init(store: AppStore) {
    self.store = store
  }

  var isConfigured: Bool { SupabaseConfig.isConfigured }

  // MARK: - Launch

  /// Restore a stored session (refreshing if needed) and hydrate the current user.
  func restore() async {
    guard isConfigured, let stored = loadStoredSession() else {
      phase = .signedOut
      return
    }
    do {
      // Hard cap the whole restore so a hanging network call can never leave the
      // app stuck on the launch "restoring" spinner — being stuck there long
      // enough to get backgrounded triggers the iOS 0x8BADF00D watchdog kill.
      try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask { @MainActor in
          let valid =
            stored.isExpired
            ? try await SupabaseClient.shared.refresh(refreshToken: stored.refreshToken)
            : stored
          try await self.adopt(valid)
        }
        group.addTask {
          try await Task.sleep(for: .seconds(12))
          throw SupabaseError.invalidResponse
        }
        // Take whichever finishes first, then cancel the loser.
        try await group.next()
        group.cancelAll()
      }
    } catch {
      // Network hung or refresh failed. Resolve to signed-out so launch never
      // stalls; the user can sign in again and a fresh session is created then.
      clearSession()
      phase = .signedOut
    }
  }

  // MARK: - Sign in

  func signInWithEmail(email: String, password: String) async {
    await run {
      let s = try await SupabaseClient.shared.signIn(
        email: email.trimmingCharacters(in: .whitespaces), password: password)
      try await self.adopt(s)
    }
  }

  func signUpWithEmail(email: String, password: String) async {
    await run {
      let s = try await SupabaseClient.shared.signUp(
        email: email.trimmingCharacters(in: .whitespaces), password: password)
      try await self.adopt(s)
    }
  }

  func signInWithGoogle() async {
    await run {
      let flow = OAuthFlow()
      let s = try await flow.signInWithGoogle()
      try await self.adopt(s)
    }
  }

  // MARK: - Role refresh

  /// Re-reads the signed-in user's profile and applies any role change in place.
  ///
  /// Called after redeeming an invite code or having a request approved. Because
  /// `ContentView` routes on `store.currentUser?.role`, updating the user here
  /// swaps the whole interface — tab bar included — with no sign-out required.
  /// Returns the role now in effect, or nil if there's no live session.
  @discardableResult
  func refreshRole() async -> UserRole? {
    guard let session else { return nil }
    do {
      let user = try await fetchAppUser(for: session)
      await store.startLiveSession(user: user, token: session.accessToken)
      return user.role
    } catch {
      errorMessage = error.localizedDescription
      return nil
    }
  }

  // MARK: - Sign out

  func signOut() async {
    if let token = session?.accessToken {
      await SupabaseClient.shared.signOut(accessToken: token)
    }
    clearSession()
    store.logout()
    phase = .signedOut
  }

  // MARK: - Delete account

  /// Permanently delete the signed-in user's account (Apple Guideline 5.1.1),
  /// then clear the local session and sign out. Returns true on success.
  func deleteAccount() async -> Bool {
    guard let token = session?.accessToken else {
      // No live session (e.g. demo mode) — just sign out locally.
      clearSession()
      store.logout()
      phase = .signedOut
      return true
    }
    isWorking = true
    errorMessage = nil
    defer { isWorking = false }
    do {
      try await AccountService.deleteAccount(token: token)
      clearSession()
      store.logout()
      phase = .signedOut
      return true
    } catch let e as SupabaseError {
      errorMessage = e.errorDescription
      return false
    } catch {
      errorMessage = error.localizedDescription
      return false
    }
  }

  // MARK: - Demo (development-only)

  /// Clearly-labelled local demo login. Does not touch Supabase.
  func demoLogin(as user: AppUser) {
    store.login(as: user)
    phase = .signedIn
  }

  /// Enter Demo Mode as a sample user. Available in all builds (sample data only).
  func enterDemo(as user: AppUser) {
    store.startDemo(as: user)
    phase = .signedIn
  }

  // MARK: - Internals

  private func run(_ work: @escaping () async throws -> Void) async {
    isWorking = true
    errorMessage = nil
    defer { isWorking = false }
    do {
      try await work()
    } catch let e as SupabaseError {
      if e == .oauthCancelled { return }
      errorMessage = e.errorDescription
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  /// Persist the session and load the matching profile into `store.currentUser`,
  /// then switch the store into live Supabase mode and load real data.
  private func adopt(_ session: SupabaseSession) async throws {
    self.session = session
    storeSession(session)
    let user = try await fetchAppUser(for: session)
    await store.startLiveSession(user: user, token: session.accessToken)
    phase = .signedIn
  }

  /// Fetch the profile row for the signed-in user. Falls back to a Tradesman
  /// placeholder if the row hasn't been created yet (trigger latency).
  private func fetchAppUser(for session: SupabaseSession) async throws -> AppUser {
    let query = "id=eq.\(session.userId)&select=id,name,email,role,phone,active,company_id"
    let data = try await SupabaseClient.shared.get(
      table: "profiles", query: query, accessToken: session.accessToken)
    let rows = (try? JSONDecoder().decode([ProfileRow].self, from: data)) ?? []

    let uuid = UUID(uuidString: session.userId) ?? UUID()
    store.currentCompanyId = rows.first?.company_id.flatMap { UUID(uuidString: $0) }
    guard let row = rows.first else {
      return AppUser(
        id: uuid,
        name: session.email?.components(separatedBy: "@").first ?? "New User",
        email: session.email ?? "",
        role: .tradesman,
        phone: "",
        active: true)
    }
    let displayName: String
    if let n = row.name, !n.isEmpty {
      displayName = n
    } else {
      displayName = row.email ?? session.email ?? "User"
    }
    let resolvedRole = UserRole(rawValue: row.role ?? "Tradesman") ?? .tradesman
    return AppUser(
      id: uuid,
      name: displayName,
      email: row.email ?? session.email ?? "",
      role: resolvedRole,
      phone: row.phone ?? "",
      active: row.active ?? true)
  }

  // MARK: - Keychain persistence

  private func storeSession(_ session: SupabaseSession) {
    guard let data = try? JSONEncoder().encode(session) else { return }
    Keychain.set(data, for: Self.sessionKey)
  }

  private func loadStoredSession() -> SupabaseSession? {
    guard let data = Keychain.data(for: Self.sessionKey) else { return nil }
    return try? JSONDecoder().decode(SupabaseSession.self, from: data)
  }

  private func clearSession() {
    session = nil
    Keychain.remove(Self.sessionKey)
  }
}
