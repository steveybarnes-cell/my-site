import SwiftUI

/// Add or edit a job/site.
struct SiteFormView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss

  let site: Site?

  @State private var name = ""
  @State private var address = ""
  @State private var client = ""
  @State private var siteManagerId: UUID?
  @State private var status: SiteStatus = .active
  @State private var notes = ""
  @State private var whatsappLink = ""
  @State private var defaultStart = "08:00"
  @State private var defaultFinish = "16:30"
  @State private var latitude = ""
  @State private var longitude = ""
  @State private var radius: Double = 150

  private var isEditing: Bool { site != nil }

  var body: some View {
      Group {
              NavigationStack {
          ZStack {
            MPGBackground()
            ScrollView {
              VStack(spacing: 16) {
                details
                managerSection
                timesSection
                geofenceSection
                PrimaryButton(title: isEditing ? "Save Changes" : "Add Site", symbol: "checkmark") {
                  save()
                }
                .disabled(name.isEmpty || address.isEmpty)
                .opacity(name.isEmpty || address.isEmpty ? 0.5 : 1)
              }
              .padding(16)
            }
          }
          .navigationTitle(isEditing ? "Edit Site" : "New Site")
          .navigationBarTitleDisplayMode(.inline)
          .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
          }
          .onAppear(perform: load)
              }
      }
      .__tenxTrackView("SiteFormView")
  }

  private var details: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Site details")
      Field(label: "Site / job name", text: $name)
      Field(label: "Address", text: $address)
      Field(label: "Client", text: $client)
      Picker("Status", selection: $status) {
        ForEach(SiteStatus.allCases) { Text($0.rawValue).tag($0) }
      }
      .pickerStyle(.menu).tint(Brand.olive).frame(maxWidth: .infinity, alignment: .leading)
    }
    .mpgFormSection()
  }

  private var managerSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Site manager")
      Picker("Site manager", selection: $siteManagerId) {
        Text("Unassigned").tag(UUID?.none)
        ForEach(store.siteManagers()) { sm in
          Text(sm.name).tag(UUID?.some(sm.id))
        }
      }
      .pickerStyle(.menu).tint(Brand.olive).frame(maxWidth: .infinity, alignment: .leading)
      Field(label: "WhatsApp group link", text: $whatsappLink)
      Field(label: "Notes", text: $notes)
    }
    .mpgFormSection()
  }

  private var timesSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Default hours")
      Field(label: "Default start (HH:mm)", text: $defaultStart)
      Field(label: "Default finish (HH:mm)", text: $defaultFinish)
    }
    .mpgFormSection()
  }

  private var geofenceSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Geofence (clock-in verification)")
      Field(label: "Latitude", text: $latitude, keyboard: .numbersAndPunctuation)
      Field(label: "Longitude", text: $longitude, keyboard: .numbersAndPunctuation)
      Stepper(value: $radius, in: 50...1000, step: 25) {
        HStack {
          Text("Radius").foregroundStyle(Brand.ink)
          Spacer()
          Text("\(Int(radius)) m").foregroundStyle(Brand.inkSoft)
        }
        .font(.subheadline)
      }
    }
    .mpgFormSection()
  }

  private func load() {
    guard let s = site else { return }
    name = s.name
    address = s.address
    client = s.client
    siteManagerId = s.siteManagerId
    status = s.status
    notes = s.notes
    whatsappLink = s.whatsappLink
    defaultStart = s.defaultStart
    defaultFinish = s.defaultFinish
    latitude = s.latitude == 0 ? "" : String(s.latitude)
    longitude = s.longitude == 0 ? "" : String(s.longitude)
    radius = s.geofenceRadius
  }

  private func save() {
    let updated = Site(
      id: site?.id ?? UUID(),
      name: name.trimmingCharacters(in: .whitespaces),
      address: address.trimmingCharacters(in: .whitespaces),
      client: client.trimmingCharacters(in: .whitespaces),
      siteManagerId: siteManagerId,
      status: status,
      notes: notes,
      whatsappLink: whatsappLink,
      defaultStart: defaultStart,
      defaultFinish: defaultFinish,
      latitude: Double(latitude) ?? 0,
      longitude: Double(longitude) ?? 0,
      geofenceRadius: radius)
    store.saveSite(updated)
    dismiss()
  }
}

/// Reusable labelled text field used across the admin forms.
struct Field: View {
  let label: String
  @Binding var text: String
  var keyboard: UIKeyboardType = .default

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(label).font(.caption).foregroundStyle(Brand.inkSoft)
      TextField("", text: $text)
        .font(.subheadline).padding(10)
        .keyboardType(keyboard)
        .background(.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
  }
}

#Preview {
  SiteFormView(site: nil).environment(AppStore())
}
