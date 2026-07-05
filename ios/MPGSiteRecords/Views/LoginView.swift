import SwiftUI

struct LoginView: View {
  @Environment(AppStore.self) private var store
  @State private var email = ""
  @State private var password = ""
  @State private var selectedRole: UserRole = .tradesman

  private var quickUsers: [AppUser] {
    store.users.filter { $0.role == selectedRole && $0.active }
  }

  var body: some View {
    Group {
      ZStack {
        Brand.charcoal.ignoresSafeArea()
        ScrollView {
          VStack(spacing: 24) {
            header
            signInCard
            roleDemoCard
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
      SectionHeader(title: "Secure Login")
      field(icon: "envelope", placeholder: "Email address", text: $email, secure: false)
      field(icon: "lock", placeholder: "Password", text: $password, secure: true)
      PrimaryButton(title: "Log In", symbol: "arrow.right") {
        if let u = quickUsers.first { store.login(as: u) }
      }
      HStack(spacing: 12) {
        secondaryLogin("Magic Link", "wand.and.stars")
        secondaryLogin("Google", "g.circle")
      }
    }
    .padding(18)
    .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
  }

  private func secondaryLogin(_ title: String, _ symbol: String) -> some View {
    Button {
      if let u = quickUsers.first { store.login(as: u) }
    } label: {
      HStack(spacing: 6) {
        Image(systemName: symbol)
        Text(title).fontWeight(.medium)
      }
      .font(.subheadline)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 12)
      .foregroundStyle(Brand.charcoal)
      .background(Brand.lightGreen, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  private var roleDemoCard: some View {
    VStack(alignment: .leading, spacing: 14) {
      SectionHeader(title: "Demo Sign-in", subtitle: "Pick a role to explore the app")
      Picker("Role", selection: $selectedRole) {
        ForEach(UserRole.allCases) { Text($0.rawValue).tag($0) }
      }
      .pickerStyle(.segmented)

      VStack(spacing: 8) {
        ForEach(quickUsers) { u in
          Button {
            store.login(as: u)
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

#Preview {
  LoginView().environment(AppStore())
}
