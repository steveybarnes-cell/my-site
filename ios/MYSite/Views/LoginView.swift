import SwiftUI

struct LoginView: View {
  @Environment(AppStore.self) private var store
  @Environment(AuthManager.self) private var auth
  @State private var email = ""
  @State private var password = ""
  @State private var isSignUp = false
  @State private var selectedRole: UserRole = .tradesman
  @State private var showDemo = false
  @State private var showForgotPassword = false

  private var quickUsers: [AppUser] {
    store.users.filter { $0.role == selectedRole && $0.active }
  }

  private var canSubmit: Bool {
    !email.trimmingCharacters(in: .whitespaces).isEmpty
      && password.count >= 6 && !auth.isWorking
  }

  var body: some View {
    Group {
      ZStack {
        Brand.charcoal.ignoresSafeArea()
        ScrollView {
          VStack(spacing: 24) {
            header
            aiReceiptBanner
            signInCard
            demoButton
              .sheet(isPresented: $showForgotPassword) {
                ForgotPasswordSheet(initialEmail: email)
              }
            // Demo sign-in lets you run and demonstrate the app (including as
            // Admin) without a real Supabase account. Compiled into DEBUG builds
            // only — it is never present in the App Store / Release build.
            #if DEBUG
              roleDemoCard
            #endif
            Text("MPG-FRM-001 Rev 5.0 · My Project Group Ltd")
              .font(.caption2)
              .foregroundStyle(.white.opacity(0.4))
              .padding(.top, 4)
          }
          .padding(20)
          .frame(maxWidth: 520)
          .frame(maxWidth: .infinity)
        }
      }
    }
    .__tenxTrackView("LoginView")
    .sheet(isPresented: $showDemo) {
      DemoModeView()
    }
  }

  private var aiReceiptBanner: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 10) {
        Image(systemName: "doc.text.viewfinder")
          .font(.title3)
          .foregroundStyle(.white)
          .frame(width: 40, height: 40)
          .background(Brand.olive, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        VStack(alignment: .leading, spacing: 2) {
          Text("AI receipt scanning")
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
          Text("Snap a receipt on site — no typing.")
            .font(.caption)
            .foregroundStyle(.white.opacity(0.7))
        }
        Spacer(minLength: 0)
      }

      HStack(spacing: 8) {
        Image(systemName: "sparkles").font(.caption2).foregroundStyle(Brand.olive)
        Text("Photograph").font(.caption2.weight(.medium)).foregroundStyle(.white.opacity(0.85))
        Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.white.opacity(0.4))
        Text("AI reads it").font(.caption2.weight(.medium)).foregroundStyle(.white.opacity(0.85))
        Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.white.opacity(0.4))
        Text("Hubdoc / Xero").font(.caption2.weight(.bold)).foregroundStyle(Brand.olive)
      }

      Text(
        "Receipts are scanned and uploaded to Hubdoc and Xero automatically — no more lost paperwork or manual data entry."
      )
      .font(.caption2)
      .foregroundStyle(.white.opacity(0.6))
      .fixedSize(horizontal: false, vertical: true)
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      Brand.charcoalDeep, in: RoundedRectangle(cornerRadius: 18, style: .continuous)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .stroke(Brand.olive.opacity(0.35), lineWidth: 1)
    )
  }

  private var demoButton: some View {
    Button {
      showDemo = true
    } label: {
      HStack(spacing: 8) {
        Image(systemName: "play.circle.fill")
        Text("Explore in Demo Mode").fontWeight(.semibold)
      }
      .font(.subheadline)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 13)
      .foregroundStyle(.white)
      .background(
        Brand.olive.opacity(0.9), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  private var header: some View {
    VStack(spacing: 18) {
      MPGLogo(height: 120)
        .padding(.top, 6)
      Text("Site Record & Invoice")
        .font(.title3.bold())
        .foregroundStyle(.white)
      Text("One standard system for every job.")
        .font(.subheadline)
        .foregroundStyle(.white.opacity(0.65))
    }
    .padding(.top, 30)
  }

  private var signInCard: some View {
    VStack(alignment: .leading, spacing: 14) {
      SectionHeader(title: isSignUp ? "Create Account" : "Secure Login")

      if !auth.isConfigured {
        #if DEBUG
          infoBanner(
            "Not connected to Supabase yet. Use Demo Sign-in below to explore the app.",
            symbol: "exclamationmark.triangle.fill")
        #else
          infoBanner(
            "Can't reach the server right now. Check your connection and try again.",
            symbol: "exclamationmark.triangle.fill")
        #endif
      }

      field(icon: "envelope", placeholder: "Email address", text: $email, secure: false)
      field(icon: "lock", placeholder: "Password", text: $password, secure: true)

      if !isSignUp {
        Button {
          auth.errorMessage = nil
          showForgotPassword = true
        } label: {
          Text("Forgotten your password?")
            .font(.caption.weight(.medium))
            .foregroundStyle(Brand.olive)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .trailing)
      }

      if let message = auth.errorMessage {
        infoBanner(message, symbol: "exclamationmark.circle.fill", tint: .red)
      }

      PrimaryButton(
        title: auth.isWorking ? "Please wait…" : (isSignUp ? "Create Account" : "Log In"),
        symbol: auth.isWorking ? "hourglass" : "arrow.right"
      ) {
        Task {
          if isSignUp {
            await auth.signUpWithEmail(email: email, password: password)
          } else {
            await auth.signInWithEmail(email: email, password: password)
          }
        }
      }
      .disabled(!canSubmit)
      .opacity(canSubmit ? 1 : 0.6)

      Button {
        withAnimation { isSignUp.toggle() }
        auth.errorMessage = nil
      } label: {
        Text(isSignUp ? "Already have an account? Log in" : "New here? Create an account")
          .font(.caption.weight(.medium))
          .foregroundStyle(Brand.olive)
      }
      .buttonStyle(.plain)
      .frame(maxWidth: .infinity)

      HStack(spacing: 8) {
        Rectangle().fill(Brand.hairline).frame(height: 1)
        Text("or").font(.caption).foregroundStyle(Brand.inkSoft)
        Rectangle().fill(Brand.hairline).frame(height: 1)
      }

      googleButton
    }
    .padding(18)
    .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
  }

  private var googleButton: some View {
    Button {
      Task { await auth.signInWithGoogle() }
    } label: {
      HStack(spacing: 8) {
        Image(systemName: "g.circle.fill")
        Text("Continue with Google").fontWeight(.semibold)
      }
      .font(.subheadline)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 13)
      .foregroundStyle(Brand.charcoal)
      .background(Brand.lightGreen, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    .buttonStyle(.plain)
    .disabled(auth.isWorking || !auth.isConfigured)
    .opacity(auth.isConfigured ? 1 : 0.5)
  }

  private var roleDemoCard: some View {
    VStack(alignment: .leading, spacing: 14) {
      SectionHeader(title: "Demo Sign-in", subtitle: "Development only · explore any role")
      Picker("Role", selection: $selectedRole) {
        ForEach(UserRole.allCases) { Text($0.rawValue).tag($0) }
      }
      .pickerStyle(.segmented)

      VStack(spacing: 8) {
        ForEach(quickUsers) { u in
          Button {
            auth.demoLogin(as: u)
          } label: {
            HStack(spacing: 12) {
              Image(systemName: u.role.icon)
                .foregroundStyle(Brand.olive)
                .frame(width: 30, height: 30)
                .background(Brand.lightGreen, in: Circle())
              VStack(alignment: .leading, spacing: 1) {
                Text(u.name).font(.subheadline.weight(.semibold)).foregroundStyle(Brand.ink)
                Text(u.email).font(.caption).foregroundStyle(Brand.inkSoft)
              }
              Spacer()
              Image(systemName: "chevron.right").font(.caption).foregroundStyle(Brand.inkSoft)
            }
            .padding(12)
            .background(Brand.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.hairline, lineWidth: 1))
          }
          .buttonStyle(.plain)
        }
      }
    }
    .padding(18)
    .background(Brand.lightGreen, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
  }

  private func infoBanner(_ text: String, symbol: String, tint: Color = Brand.olive) -> some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: symbol).foregroundStyle(tint)
      Text(text).font(.caption).foregroundStyle(Brand.ink)
      Spacer(minLength: 0)
    }
    .padding(10)
    .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
  }

  private func field(icon: String, placeholder: String, text: Binding<String>, secure: Bool)
    -> some View
  {
    HStack(spacing: 10) {
      Image(systemName: icon).foregroundStyle(Brand.inkSoft).frame(width: 20)
      Group {
        if secure {
          SecureField(placeholder, text: text)
        } else {
          TextField(placeholder, text: text).keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        }
      }
      .font(.subheadline)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 13)
    .background(
      Brand.lightGreen.opacity(0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
  }
}

private struct LoginPreview: View {
  @State private var store = AppStore()
  var body: some View {
    LoginView()
      .environment(store)
      .environment(AuthManager(store: store))
  }
}

#Preview { LoginPreview() }

// =====================================================================
// MARK: - Company setup
// =====================================================================

/// Shown after signing up, to an account that doesn't belong to a company yet.
///
/// Before this screen existed, that account saw the normal app with every list
/// empty and nothing explaining why — every row in the database is scoped to a
/// company, and they had none. There was no way forward from inside the app at
/// all; someone had to run SQL.
///
/// Two ways out, depending on whether the firm is already here:
///   • First person from a firm — create the company, become its admin.
///   • Everyone after them — an invite code from that admin.
struct CompanySetupView: View {
  @Environment(AppStore.self) private var store
  @Environment(AuthManager.self) private var auth

  private enum Route: String, CaseIterable, Identifiable {
    case create = "Set up my firm"
    case join = "I have an invite code"
    var id: String { rawValue }
  }

  @State private var route: Route = .create
  @State private var companyName = ""
  @State private var hubdocEmail = ""
  @State private var inviteCode = ""
  @State private var working = false
  @State private var errorMessage: String?

  private var canCreate: Bool {
    companyName.trimmingCharacters(in: .whitespaces).count >= 2 && !working
  }
  private var canJoin: Bool {
    inviteCode.trimmingCharacters(in: .whitespaces).count >= 4 && !working
  }

  var body: some View {
    NavigationStack {
      ZStack {
        MPGBackground()
        ScrollView {
          VStack(spacing: 18) {
            header
            Picker("Route", selection: $route) {
              ForEach(Route.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            switch route {
            case .create: createCard
            case .join: joinCard
            }

            if let errorMessage {
              Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                .font(.caption).foregroundStyle(Brand.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .mpgCard(padding: 12)
            }

            Button("Sign out") { Task { await auth.signOut() } }
              .font(.footnote)
              .foregroundStyle(Brand.inkSoft)
          }
          .padding(16)
        }
      }
      .navigationTitle("Almost there")
      .navigationBarTitleDisplayMode(.inline)
    }
    .__tenxTrackView("CompanySetupView")
  }

  private var header: some View {
    VStack(spacing: 8) {
      MPGLogo(height: 92).padding(.top, 8)
      Text("Your account isn't linked to a firm yet")
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Brand.ink)
      Text(
        "Sites, jobs and costs all belong to a firm, so there's nothing to show until this is sorted."
      )
      .font(.caption)
      .foregroundStyle(Brand.inkSoft)
      .multilineTextAlignment(.center)
    }
  }

  private var createCard: some View {
    VStack(alignment: .leading, spacing: 14) {
      SectionHeader(
        title: "Set up your firm",
        subtitle: "You'll be its admin — everyone else joins by invite")

      field("Company name", text: $companyName, symbol: "building.2")

      SectionHeader(
        title: "Hubdoc address",
        subtitle: "Optional — receipts are emailed here automatically")

      field(
        "yourfirm-abc123@hubdoc.com", text: $hubdocEmail, symbol: "tray.and.arrow.up",
        email: true)

      // Asked here rather than left to a settings screen because a firm that
      // never sets one has receipts going quietly nowhere, and the moment
      // someone is setting up their firm is the moment they know the answer.
      Text(
        "Find it in Hubdoc under Upload Document, or Organization settings. "
          + "You can add it later in Profile → Integrations."
      )
      .font(.caption2).foregroundStyle(Brand.inkSoft)

      PrimaryButton(
        title: working ? "Setting up…" : "Create firm",
        symbol: working ? "hourglass" : "checkmark"
      ) {
        Task { await create() }
      }
      .disabled(!canCreate)
      .opacity(canCreate ? 1 : 0.6)
    }
    .mpgCard()
  }

  private var joinCard: some View {
    VStack(alignment: .leading, spacing: 14) {
      SectionHeader(
        title: "Join your firm",
        subtitle: "Ask your admin for a code — it's single-use")

      field("MPG-K7P4-N2WX", text: $inviteCode, symbol: "key.fill")

      PrimaryButton(
        title: working ? "Joining…" : "Join",
        symbol: working ? "hourglass" : "arrow.right"
      ) {
        Task { await join() }
      }
      .disabled(!canJoin)
      .opacity(canJoin ? 1 : 0.6)

      Text("No code? An admin can also add you from Manage → Team once you've signed up.")
        .font(.caption2).foregroundStyle(Brand.inkSoft)
    }
    .mpgCard()
  }

  private func field(
    _ placeholder: String, text: Binding<String>, symbol: String, email: Bool = false
  ) -> some View {
    HStack(spacing: 10) {
      Image(systemName: symbol).foregroundStyle(Brand.olive).frame(width: 20)
      TextField(placeholder, text: text)
        .font(.subheadline)
        .autocorrectionDisabled()
        .keyboardType(email ? .emailAddress : .default)
        .textInputAutocapitalization(email ? .never : .words)
    }
    .padding(.vertical, 12).padding(.horizontal, 14)
    .background(
      RoundedRectangle(cornerRadius: Brand.Radius.inner, style: .continuous)
        .fill(Brand.lightGreen.opacity(0.5))
    )
    .overlay(
      RoundedRectangle(cornerRadius: Brand.Radius.inner, style: .continuous)
        .stroke(Brand.hairline, lineWidth: 1)
    )
  }

  private func create() async {
    guard let token = store.currentBackendToken else {
      errorMessage = "Your session has expired. Sign in again."
      return
    }
    working = true
    errorMessage = nil
    defer { working = false }
    do {
      try await OnboardingService.createCompany(
        name: companyName.trimmingCharacters(in: .whitespaces),
        hubdocEmail: hubdocEmail,
        token: token)
      // Re-reads the profile, which is what puts the new company id and the
      // Admin role into the store and lets ContentView route onward.
      _ = await auth.refreshRole()
    } catch {
      errorMessage = (error as? SupabaseError)?.errorDescription ?? error.localizedDescription
    }
  }

  private func join() async {
    guard let token = store.currentBackendToken else {
      errorMessage = "Your session has expired. Sign in again."
      return
    }
    working = true
    errorMessage = nil
    defer { working = false }
    do {
      _ = try await RoleService.redeemInvite(
        code: inviteCode.trimmingCharacters(in: .whitespaces), token: token)
      _ = await auth.refreshRole()
    } catch {
      errorMessage = (error as? SupabaseError)?.errorDescription ?? error.localizedDescription
    }
  }
}
