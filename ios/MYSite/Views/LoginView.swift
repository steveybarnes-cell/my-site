import SwiftUI

struct LoginView: View {
  @Environment(AppStore.self) private var store
  @Environment(AuthManager.self) private var auth
  @State private var email = ""
  @State private var password = ""
  @State private var isSignUp = false
  @State private var selectedRole: UserRole = .tradesman
  @State private var showDemo = false

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
            signInCard
            demoButton
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
      MPGLogo(height: 62)
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
