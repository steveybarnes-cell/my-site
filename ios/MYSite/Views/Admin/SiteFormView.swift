import CoreLocation
import MapKit
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
      SectionHeader(
        title: "Site zone",
        subtitle: "Clock-ins inside this circle count as on site")

      // Was two text boxes asking for latitude and longitude. Nobody types
      // 51.4630 standing in a muddy car park, so in practice they stayed empty
      // and every clock-in fell back to "no location set".
      SiteZonePicker(
        latitude: $latitude,
        longitude: $longitude,
        radius: $radius,
        searchHint: address)

      Text(
        "Tap the map to place the pin, or drag it. Radius sets how far from the pin still counts — "
          + "150 m suits most sites; widen it for scattered plots."
      )
      .font(.caption2).foregroundStyle(Brand.inkSoft)
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

// =====================================================================
// MARK: - Site zone picker
// =====================================================================



/// Places a site's pin and sets how far around it still counts as "on site".
///
/// The zone is what makes clock-in verification mean anything: `LocationFix`
/// measures the distance from this pin and marks anything beyond the radius as
/// "Outside Site — Review Required". Before this the coordinates had to be
/// typed as decimals, which meant in practice they weren't, and every clock-in
/// came back unverifiable.
///
/// Radius is a slider rather than a pinch. Pinch is how you zoom a map, and
/// overloading it would mean every attempt to look closer at the site also
/// resized the zone — the two gestures fight, and the map wins.
struct SiteZonePicker: View {
  @Binding var latitude: String
  @Binding var longitude: String
  @Binding var radius: Double

  /// The site's address, used as the first search if there's no pin yet.
  var searchHint: String = ""

  @State private var camera: MapCameraPosition = .automatic
  @State private var query = ""
  @State private var searching = false
  @State private var searchError: String?
  @State private var located = false

  private var coordinate: CLLocationCoordinate2D? {
    guard let lat = Double(latitude), let lon = Double(longitude),
      lat != 0 || lon != 0,
      CLLocationCoordinate2DIsValid(CLLocationCoordinate2D(latitude: lat, longitude: lon))
    else { return nil }
    return CLLocationCoordinate2D(latitude: lat, longitude: lon)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      searchBar
      map
      radiusControl
      readout
    }
    .task {
      guard !located else { return }
      located = true
      if let c = coordinate {
        camera = .region(region(around: c))
      } else if !searchHint.isEmpty {
        // Most sites are created from an address before anyone visits, so
        // seeding the map from it saves the common case entirely.
        await search(searchHint, silent: true)
      }
    }
  }

  private var searchBar: some View {
    HStack(spacing: 8) {
      Image(systemName: "magnifyingglass").foregroundStyle(Brand.olive)
      TextField("Search address or postcode", text: $query)
        .font(.subheadline)
        .autocorrectionDisabled()
        .submitLabel(.search)
        .onSubmit { Task { await search(query) } }
      if searching { ProgressView().controlSize(.small) }
    }
    .padding(.vertical, 10).padding(.horizontal, 12)
    .background(.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .stroke(Brand.hairline, lineWidth: 1))
  }

  private var map: some View {
    MapReader { proxy in
      Map(position: $camera) {
        if let c = coordinate {
          MapCircle(center: c, radius: radius)
            .foregroundStyle(Brand.olive.opacity(0.18))
            .stroke(Brand.olive, lineWidth: 2)

          Annotation("Site", coordinate: c) {
            Image(systemName: "mappin.circle.fill")
              .font(.system(size: 30))
              .foregroundStyle(Brand.olive, .white)
              .shadow(radius: 2)
              // Dragging the pin converts back through the same proxy the tap
              // uses, so both gestures agree on where the finger actually is.
              .gesture(
                DragGesture(coordinateSpace: .named("zoneMap"))
                  .onChanged { value in
                    if let moved = proxy.convert(value.location, from: .named("zoneMap")) {
                      set(moved)
                    }
                  }
              )
          }
        }
      }
      .mapStyle(.hybrid(elevation: .flat))
      .coordinateSpace(.named("zoneMap"))
      .frame(height: 240)
      .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      .onTapGesture { point in
        if let tapped = proxy.convert(point, from: .local) { set(tapped) }
      }
      .overlay(alignment: .topTrailing) {
        if coordinate == nil {
          Text("Tap to place the site pin")
            .font(.caption2.weight(.semibold))
            .padding(.vertical, 5).padding(.horizontal, 9)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(8)
        }
      }
    }
  }

  private var radiusControl: some View {
    VStack(spacing: 4) {
      HStack {
        Text("Zone radius").font(.subheadline).foregroundStyle(Brand.ink)
        Spacer()
        Text("\(Int(radius)) m").font(.subheadline.weight(.semibold))
          .foregroundStyle(Brand.olive)
      }
      Slider(value: $radius, in: 50...1000, step: 10)
        .tint(Brand.olive)
        .disabled(coordinate == nil)
    }
  }

  @ViewBuilder private var readout: some View {
    if let c = coordinate {
      HStack(spacing: 10) {
        Label(
          String(format: "%.5f, %.5f", c.latitude, c.longitude),
          systemImage: "location.fill"
        )
        .font(.caption2).foregroundStyle(Brand.inkSoft)
        Spacer()
        Button("Clear pin") {
          latitude = ""
          longitude = ""
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(Brand.red)
      }
    } else if let searchError {
      Label(searchError, systemImage: "exclamationmark.circle")
        .font(.caption2).foregroundStyle(Brand.red)
    } else {
      Label("No zone set — clock-ins here can't be verified", systemImage: "exclamationmark.triangle")
        .font(.caption2).foregroundStyle(Brand.amber)
    }
  }

  private func set(_ c: CLLocationCoordinate2D) {
    latitude = String(c.latitude)
    longitude = String(c.longitude)
  }

  /// Frames the circle with a bit of room around it, so the whole zone is
  /// visible rather than filling the frame edge to edge.
  private func region(around c: CLLocationCoordinate2D) -> MKCoordinateRegion {
    MKCoordinateRegion(center: c, latitudinalMeters: radius * 6, longitudinalMeters: radius * 6)
  }

  private func search(_ text: String, silent: Bool = false) async {
    let term = text.trimmingCharacters(in: .whitespaces)
    guard !term.isEmpty else { return }
    searching = true
    searchError = nil
    defer { searching = false }

    let request = MKLocalSearch.Request()
    request.naturalLanguageQuery = term
    // Biased to the UK — a bare postcode or street name is otherwise as likely
    // to match somewhere in the US.
    request.region = MKCoordinateRegion(
      center: CLLocationCoordinate2D(latitude: 54.0, longitude: -2.5),
      latitudinalMeters: 1_200_000, longitudinalMeters: 1_200_000)

    do {
      let response = try await MKLocalSearch(request: request).start()
      guard let first = response.mapItems.first else {
        if !silent { searchError = "Nothing found for that." }
        return
      }
      let c = first.placemark.coordinate
      set(c)
      camera = .region(region(around: c))
    } catch {
      // Seeding from the address is best-effort; failing quietly there is
      // correct, because the map still works by tapping.
      if !silent { searchError = "Couldn't search for that address." }
    }
  }
}
