import CoreLocation
import SwiftUI

/// Confirmation sheet shown when clocking in or out — resolves a single GPS fix, shows the
/// geofence result, and requires a reason note if the tradesman is outside the site.
struct ClockConfirmSheet: View {
  let event: ClockInView.ClockEvent
  let site: Site

  @Environment(AppStore.self) private var store
  @Environment(LocationService.self) private var location
  @Environment(\.dismiss) private var dismiss

  @State private var resolving = true
  @State private var fix: LocationFix?
  @State private var reason = ""
  @State private var addPhoto = false
  @State private var photoNote = ""

  private var isOut: Bool { event == .clockOut }
  private var title: String { isOut ? "Clock Out" : "Clock In" }

  private var needsReview: Bool {
    guard let fix else { return false }
    return fix.permissionDenied || !fix.insideGeofence
  }

  private var canSubmit: Bool {
    guard let _ = fix else { return false }
    if needsReview { return !reason.trimmingCharacters(in: .whitespaces).isEmpty }
    return true
  }

  var body: some View {
      Group {
              NavigationStack {
          ZStack {
            MPGBackground()
            ScrollView {
              VStack(spacing: 16) {
                siteHeader
                if resolving {
                  resolvingCard
                } else if let fix {
                  resultCard(fix)
                  if needsReview { reviewCard(fix) }
                  photoCard
                }
              }
              .padding(16)
            }
          }
          .navigationTitle(title)
          .toolbar {
            ToolbarItem(placement: .cancellationAction) {
              Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
              Button(title) { submit() }
                .fontWeight(.semibold)
                .disabled(!canSubmit)
            }
          }
          .onAppear(perform: resolve)
              }
      }
      .__tenxTrackView("ClockConfirmSheet")
  }

  private var siteHeader: some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(site.name).font(.headline).foregroundStyle(Brand.ink)
      Text(site.address).font(.caption).foregroundStyle(Brand.inkSoft)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .mpgCard()
  }

  private var resolvingCard: some View {
    VStack(spacing: 12) {
      ProgressView()
      Text("Checking your location…").font(.subheadline).foregroundStyle(Brand.inkSoft)
    }
    .frame(maxWidth: .infinity)
    .padding(28)
    .mpgCard()
  }

  private func resultCard(_ fix: LocationFix) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Image(systemName: fix.permissionDenied
          ? "location.slash.fill" : (fix.insideGeofence ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"))
          .font(.title2)
          .foregroundStyle(store.statusFor(fix).color)
        Text(store.statusFor(fix).rawValue)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(store.statusFor(fix).color)
      }
      Divider().overlay(Brand.hairline)
      if fix.permissionDenied {
        Text("Location permission is off — this entry will be recorded as a manual clock-in and "
          + "sent for admin review.")
          .font(.caption).foregroundStyle(Brand.inkSoft)
      } else {
        InfoRow(label: "Distance from site", value: Fmt.metres(fix.distanceFromSite), symbol: "ruler")
        InfoRow(label: "Geofence radius", value: "\(Int(site.geofenceRadius))m", symbol: "circle.dashed")
        InfoRow(
          label: "GPS accuracy",
          value: fix.accuracy < 0 ? "—" : "±\(Int(fix.accuracy))m", symbol: "scope")
        InfoRow(label: "Time", value: Fmt.time(Date()), symbol: "clock")
      }
    }
    .mpgCard()
  }

  private func reviewCard(_ fix: LocationFix) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      WarningBanner(
        message: fix.permissionDenied
          ? "Location Permission Denied — Admin Review Required. Please add a reason."
          : "You appear to be outside the allocated site. This entry will require admin approval.",
        symbol: "exclamationmark.triangle.fill", tint: Brand.red)
      Text("Reason (required)").font(.footnote.weight(.semibold)).foregroundStyle(Brand.ink)
      TextField("e.g. parked in overflow car park across the road", text: $reason, axis: .vertical)
        .lineLimit(2...4)
        .padding(10)
        .background(Brand.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Brand.hairline, lineWidth: 1))
    }
    .mpgCard()
  }

  private var photoCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      Toggle(isOn: $addPhoto) {
        Label("Add a \(isOut ? "clock-out" : "clock-in") photo", systemImage: "camera")
          .font(.subheadline).foregroundStyle(Brand.ink)
      }
      .tint(Brand.olive)
      if addPhoto {
        TextField("Photo description", text: $photoNote)
          .padding(10)
          .background(Brand.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
          .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Brand.hairline, lineWidth: 1))
        Text("Saved to Drive under Clock In Evidence / \(site.name).")
          .font(.caption2).foregroundStyle(Brand.inkSoft)
      }
    }
    .mpgCard()
  }

  // MARK: - Actions

  private func resolve() {
    resolving = true
    location.requestOneShot { coord, accuracy in
      let f = LocationFix.compute(coord: location.permissionDenied ? nil : coord,
        accuracy: accuracy, site: site)
      self.fix = f
      self.resolving = false
    }
  }

  private func submit() {
    guard let fix else { return }
    let photoDesc: String? = addPhoto ? photoNote : nil
    if isOut {
      if let open = store.openClockRecord(for: store.currentUser?.id ?? UUID()) {
        store.clockOut(
          recordId: open.id, site: site, fix: fix, reasonNote: reason, photoDescription: photoDesc)
      }
    } else {
      store.clockIn(
        site: site, fix: fix, device: location.deviceName, reasonNote: reason,
        photoDescription: photoDesc)
    }
    dismiss()
  }
}

// MARK: - Clock record row

struct ClockRecordRow: View {
  let record: ClockRecord
  var showName: Bool = false

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          if showName {
            Text(record.tradesmanName).font(.subheadline.weight(.semibold)).foregroundStyle(Brand.ink)
          }
          Text(record.siteName).font(showName ? .caption : .subheadline.weight(.medium))
            .foregroundStyle(showName ? Brand.inkSoft : Brand.ink)
          Text(Fmt.date(record.date)).font(.caption2).foregroundStyle(Brand.inkSoft)
        }
        Spacer()
        StatusChip(text: record.overallStatus.short, color: record.overallStatus.color)
      }
      HStack(spacing: 14) {
        Label(Fmt.time(record.clockInTime), systemImage: "arrow.down.to.line")
        Label(record.clockOutTime.map(Fmt.time) ?? "Open", systemImage: "arrow.up.to.line")
        Label(record.timeOnSiteString, systemImage: "hourglass")
      }
      .font(.caption).foregroundStyle(Brand.inkSoft)
      if !record.reasonNote.isEmpty {
        Text(record.reasonNote).font(.caption2).foregroundStyle(Brand.inkSoft)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .padding(12)
    .background(Brand.lightGreen.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
  }
}
