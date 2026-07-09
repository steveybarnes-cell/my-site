import SwiftUI

struct ProfileView: View {
  @Environment(AppStore.self) private var store
  @Environment(AuthManager.self) private var auth
  @State private var showDeleteConfirm = false
  @State private var showDeleteError = false
  private var me: AppUser? { store.currentUser }
  private var profile: TradesmanProfile? { me.flatMap { store.profile(for: $0.id) } }

  var body: some View {
    Group {
      NavigationStack {
        ZStack {
          MPGBackground()
          ScrollView {
            VStack(spacing: 16) {
              header
              if let p = profile {
                if p.bankChangePending {
                  WarningBanner(
                    message: "A bank detail change is pending office verification for security.",
                    symbol: "lock.shield.fill", tint: Brand.amber)
                }
                tradeCard(p)
                complianceCard(p)
                paymentCard(p)
              }
              contactCard
              PrimaryButton(
                title: "Log Out", symbol: "rectangle.portrait.and.arrow.right", tint: Brand.charcoal
              ) {
                store.logout()
              }
              deleteAccountSection
            }
            .padding(16)
          }
        }
        .navigationTitle("Profile")
        .alert("Delete your account?", isPresented: $showDeleteConfirm) {
          Button("Cancel", role: .cancel) {}
          Button("Delete", role: .destructive) {
            Task {
              let ok = await auth.deleteAccount()
              if !ok { showDeleteError = true }
            }
          }
        } message: {
          Text(
            "This permanently deletes your MPG Site Records account and your personal data. This cannot be undone."
          )
        }
        .alert("Couldn't delete account", isPresented: $showDeleteError) {
          Button("OK", role: .cancel) {}
        } message: {
          Text(auth.errorMessage ?? "Something went wrong. Please try again or contact support.")
        }
      }
    }
    .__tenxTrackView("ProfileView")
  }

  private var header: some View {
    VStack(spacing: 10) {
      ZStack {
        Circle().fill(Brand.olive).frame(width: 72, height: 72)
        Text(initials).font(.title2.bold()).foregroundStyle(.white)
      }
      Text(me?.name ?? "").font(.title3.bold()).foregroundStyle(.white)
      Text(me?.role.rawValue ?? "").font(.subheadline).foregroundStyle(.white.opacity(0.75))
    }
    .frame(maxWidth: .infinity)
    .padding(22)
    .background(Brand.charcoal, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
  }

  private var initials: String {
    (me?.name.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined())
      ?? "?"
  }

  private func tradeCard(_ p: TradesmanProfile) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Trade & business")
      InfoRow(label: "Company", value: p.company, symbol: "building.2")
      InfoRow(label: "Main trade", value: p.mainTrade, symbol: "hammer")
      InfoRow(label: "Address", value: p.address, symbol: "mappin")
      InfoRow(label: "Vehicle", value: p.vehicleReg, symbol: "car")
      if !p.notes.isEmpty { InfoRow(label: "Notes", value: p.notes, symbol: "note.text") }
    }
    .mpgCard()
  }

  private func complianceCard(_ p: TradesmanProfile) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Compliance")
      InfoRow(label: "UTR", value: p.utr, symbol: "number")
      InfoRow(label: "NI number", value: p.niNumber, symbol: "person.text.rectangle")
      InfoRow(label: "CIS status", value: p.cisStatus, symbol: "checkmark.shield")
      InfoRow(
        label: "VAT registered", value: p.vatRegistered ? "Yes — \(p.vatNumber)" : "No",
        symbol: "percent")
    }
    .mpgCard()
  }

  private func paymentCard(_ p: TradesmanProfile) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Payment details")
      InfoRow(label: "Account name", value: p.bankName, symbol: "person.crop.circle")
      InfoRow(label: "Sort code", value: p.sortCode, symbol: "creditcard")
      InfoRow(label: "Account", value: p.accountNumber, symbol: "banknote")
      InfoRow(label: "Hourly rate", value: Fmt.gbp(p.hourlyRate), symbol: "clock")
      InfoRow(label: "Day rate", value: Fmt.gbp(p.dayRate), symbol: "sun.max")
    }
    .mpgCard()
  }

  private var deleteAccountSection: some View {
    VStack(spacing: 8) {
      Button {
        showDeleteConfirm = true
      } label: {
        HStack(spacing: 8) {
          if auth.isWorking {
            ProgressView().tint(Brand.rust)
          } else {
            Image(systemName: "trash")
          }
          Text("Delete my account")
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Brand.rust)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(Brand.rust.opacity(0.5), lineWidth: 1)
        )
      }
      .disabled(auth.isWorking)
      Text("Permanently removes your account and personal data.")
        .font(.caption)
        .foregroundStyle(.white.opacity(0.6))
    }
    .padding(.top, 4)
  }

  private var contactCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Contact")
      InfoRow(label: "Email", value: me?.email ?? "", symbol: "envelope")
      InfoRow(label: "Phone", value: me?.phone ?? "", symbol: "phone")
    }
    .mpgCard()
  }
}

#Preview {
  let s = AppStore()
  s.login(as: s.tradesmen().first!)
  return ProfileView()
    .environment(s)
    .environment(AuthManager(store: s))
}
