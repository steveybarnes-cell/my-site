import SwiftUI

/// Demo Mode entry: lets anyone explore the app as any role using the built-in
/// sample data, without a Supabase account or live session. Available in all
/// builds. Clearly labelled so it is never confused with a real login.
struct DemoModeView: View {
  @Environment(AppStore.self) private var store
  @Environment(AuthManager.self) private var auth
  @Environment(\.dismiss) private var dismiss

  @State private var selectedRole: UserRole = .tradesman

  private var roleUsers: [AppUser] {
    store.users.filter { $0.role == selectedRole && $0.active }
  }

  var body: some View {
    NavigationStack {
      ZStack {
        MPGBackground()
        ScrollView {
          VStack(spacing: 18) {
            banner

            VStack(alignment: .leading, spacing: 14) {
              SectionHeader(
                title: "Choose a role",
                subtitle: "Explore the app from any team member's view")
              Picker("Role", selection: $selectedRole) {
                ForEach(UserRole.allCases) { Text($0.rawValue).tag($0) }
              }
              .pickerStyle(.segmented)

              VStack(spacing: 8) {
                ForEach(roleUsers) { user in
                  userRow(user)
                }
                if roleUsers.isEmpty {
                  Text("No sample \(selectedRole.rawValue.lowercased()) available.")
                    .font(.caption)
                    .foregroundStyle(Brand.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
              }
            }
            .mpgCard()

            Text("Demo data is local to this device and resets when you sign out.")
              .font(.caption2)
              .foregroundStyle(Brand.inkSoft)
              .multilineTextAlignment(.center)
          }
          .padding(16)
          .frame(maxWidth: 520)
          .frame(maxWidth: .infinity)
        }
      }
      .navigationTitle("Demo Mode")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Close") { dismiss() }
        }
      }
    }
    .__tenxTrackView("DemoModeView")
  }

  private var banner: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: "play.circle.fill")
        .font(.title2)
        .foregroundStyle(Brand.olive)
      VStack(alignment: .leading, spacing: 3) {
        Text("You're about to explore a demo")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(Brand.ink)
        Text("Sample sites, records and invoices. Nothing is sent to the server.")
          .font(.caption)
          .foregroundStyle(Brand.inkSoft)
      }
      Spacer(minLength: 0)
    }
    .padding(14)
    .background(Brand.lightGreen, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  private func userRow(_ user: AppUser) -> some View {
    Button {
      auth.enterDemo(as: user)
      dismiss()
    } label: {
      HStack(spacing: 12) {
        Image(systemName: user.role.icon)
          .foregroundStyle(Brand.olive)
          .frame(width: 34, height: 34)
          .background(Brand.lightGreen, in: Circle())
        VStack(alignment: .leading, spacing: 1) {
          Text(user.name).font(.subheadline.weight(.semibold)).foregroundStyle(Brand.ink)
          Text(user.role.rawValue).font(.caption).foregroundStyle(Brand.inkSoft)
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

private struct DemoModePreview: View {
  @State private var store = AppStore()
  var body: some View {
    DemoModeView()
      .environment(store)
      .environment(AuthManager(store: store))
  }
}

#Preview { DemoModePreview() }
