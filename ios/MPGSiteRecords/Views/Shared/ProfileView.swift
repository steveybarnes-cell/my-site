import SwiftUI

struct ProfileView: View {
  @Environment(AppStore.self) private var store
  private var me: AppUser? { store.currentUser }
  private var profile: TradesmanProfile? { me.flatMap { store.profile(for: $0.id) } }

  var body: some View {
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
          }
          .padding(16)
        }
      }
      .navigationTitle("Profile")
    }
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
  ProfileView().environment(
    {
      let s = AppStore()
      s.login(as: s.tradesmen().first!)
      return s
    }())
}
