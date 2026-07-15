import SwiftUI

/// Teammate picker that places a **real** phone call through the system dialer
/// using each team member's stored number. There is no simulated in-app VoIP
/// screen — tapping a teammate hands off to iOS to dial `tel:` directly.
struct StartCallView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  @Environment(\.openURL) private var openURL

  @State private var unavailableName: String?

  private var teammates: [AppUser] {
    store.users.filter { $0.active && $0.id != store.currentUser?.id }
      .sorted { $0.name < $1.name }
  }

  var body: some View {
    NavigationStack {
      ZStack {
        MPGBackground()
        ScrollView {
          VStack(spacing: 10) {
            Text("Tap a teammate to call them on their mobile.")
              .font(.footnote)
              .foregroundStyle(Brand.inkSoft)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.bottom, 4)

            if let unavailableName {
              HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.circle.fill").foregroundStyle(Brand.red)
                Text("No phone number on file for \(unavailableName).")
                  .font(.caption).foregroundStyle(Brand.ink)
                Spacer(minLength: 0)
              }
              .padding(10)
              .background(Brand.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            }

            ForEach(teammates) { u in
              Button {
                dial(u)
              } label: {
                HStack(spacing: 12) {
                  ZStack {
                    Circle().fill(Brand.lightGreen)
                    Image(systemName: u.role.icon).foregroundStyle(Brand.oliveDark)
                  }
                  .frame(width: 42, height: 42)
                  VStack(alignment: .leading, spacing: 1) {
                    Text(u.name).font(.subheadline.weight(.semibold)).foregroundStyle(Brand.ink)
                    Text(u.phone.isEmpty ? u.role.rawValue : u.phone)
                      .font(.caption).foregroundStyle(Brand.inkSoft)
                  }
                  Spacer()
                  Image(systemName: "phone.circle.fill")
                    .font(.title3)
                    .foregroundStyle(u.phone.isEmpty ? Brand.inkSoft : Brand.olive)
                }
                .mpgCard(padding: 12)
              }
              .buttonStyle(.plain)
            }
          }
          .padding(16)
        }
      }
      .navigationTitle("Call a Teammate")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
      }
    }
    .__tenxTrackView("StartCallView")
  }

  private func dial(_ user: AppUser) {
    let digits = user.phone.filter { $0.isNumber || $0 == "+" }
    guard !digits.isEmpty, let url = URL(string: "tel://\(digits)") else {
      unavailableName = user.name
      return
    }
    dismiss()
    openURL(url)
  }
}

#Preview {
  StartCallView()
    .environment(
      {
        let s = AppStore()
        s.login(as: s.users.first!)
        return s
      }()
    )
}
