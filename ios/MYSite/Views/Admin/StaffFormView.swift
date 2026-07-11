import SwiftUI

/// Add or edit a team member (tradesman or site manager).
struct StaffFormView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss

  let user: AppUser?

  @State private var name = ""
  @State private var email = ""
  @State private var phone = ""
  @State private var role: UserRole = .tradesman
  @State private var active = true

  private var isEditing: Bool { user != nil }

  var body: some View {
    Group {
      NavigationStack {
        ZStack {
          MPGBackground()
          ScrollView {
            VStack(spacing: 16) {
              details
              PrimaryButton(title: isEditing ? "Save Changes" : "Add Member", symbol: "checkmark") {
                save()
              }
              .disabled(name.isEmpty)
              .opacity(name.isEmpty ? 0.5 : 1)
            }
            .padding(16)
          }
        }
        .navigationTitle(isEditing ? "Edit Member" : "New Member")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        }
        .onAppear(perform: load)
      }
    }
    .__tenxTrackView("StaffFormView")
  }

  private var details: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Member details")
      Field(label: "Full name", text: $name)
      Field(label: "Email", text: $email, keyboard: .emailAddress)
      Field(label: "Phone", text: $phone, keyboard: .phonePad)
      Picker("Role", selection: $role) {
        ForEach(UserRole.allCases.filter { $0 != .admin }) { Text($0.rawValue).tag($0) }
      }
      .pickerStyle(.segmented)
      Toggle(isOn: $active) {
        Text("Active").font(.subheadline).foregroundStyle(Brand.ink)
      }
      .tint(Brand.olive)
    }
    .mpgFormSection()
  }

  private func load() {
    guard let u = user else { return }
    name = u.name
    email = u.email
    phone = u.phone
    role = u.role == .admin ? .tradesman : u.role
    active = u.active
  }

  private func save() {
    let updated = AppUser(
      id: user?.id ?? UUID(),
      name: name.trimmingCharacters(in: .whitespaces),
      email: email.trimmingCharacters(in: .whitespaces),
      role: role,
      phone: phone.trimmingCharacters(in: .whitespaces),
      active: active)
    store.saveUser(updated)
    dismiss()
  }
}

#Preview {
  StaffFormView(user: nil).environment(AppStore())
}
