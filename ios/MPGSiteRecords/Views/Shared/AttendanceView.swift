import CoreLocation
import MapKit
import SwiftUI

/// Admin / Site Manager attendance overview: a live site map showing where each tradesman
/// clocked in and out (with geofence circles), plus a reviewable records list.
struct AttendanceView: View {
  @Environment(AppStore.self) private var store

  @State private var selectedSiteId: UUID?
  @State private var reviewRecord: ClockRecord?
  @State private var position: MapCameraPosition = .automatic

  private var records: [ClockRecord] { store.visibleClockRecords() }

  /// Sites that have at least one clock record the viewer can see.
  private var sites: [Site] {
    let ids = Set(records.map { $0.siteId })
    return store.sites.filter { ids.contains($0.id) }
  }

  private var activeSite: Site? {
    if let id = selectedSiteId { return store.site(id) }
    return sites.first
  }

  private var siteRecords: [ClockRecord] {
    guard let site = activeSite else { return records }
    return records.filter { $0.siteId == site.id }
  }

  private var reviewCount: Int {
    records.filter { $0.requiresManualApproval }.count
  }

  var body: some View {
    NavigationStack {
      ZStack {
        MPGBackground()
        if records.isEmpty {
          EmptyStateView(
            symbol: "location.slash",
            title: "No attendance yet",
            message: "Clock-in and clock-out records will appear here with a live site map once "
              + "tradesmen start clocking in on their allocated sites."
          )
          .mpgCard()
          .padding(16)
        } else {
          ScrollView {
            VStack(spacing: 16) {
              if reviewCount > 0 {
                WarningBanner(
                  message: "\(reviewCount) attendance record(s) need review — clocked in outside "
                    + "the site geofence or with no location.",
                  symbol: "exclamationmark.triangle.fill", tint: Brand.amber)
              }
              siteChips
              mapCard
              recordsSection
            }
            .padding(16)
          }
        }
      }
      .navigationTitle("Attendance")
      .sheet(item: $reviewRecord) { rec in
        AttendanceReviewSheet(record: rec)
      }
      .onAppear {
        if selectedSiteId == nil { selectedSiteId = sites.first?.id }
        recenter()
      }
      .onChange(of: selectedSiteId) { _, _ in recenter() }
    }
    .__tenxTrackView("AttendanceView")
  }

  // MARK: - Site chips

  private var siteChips: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        ForEach(sites) { site in
          let active = site.id == activeSite?.id
          Button {
            selectedSiteId = site.id
          } label: {
            HStack(spacing: 6) {
              Image(systemName: "mappin.circle.fill").font(.caption)
              Text(site.name).font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .foregroundStyle(active ? Color.white : Brand.ink)
            .background(
              active ? Brand.paidGreen : Brand.lightGreen.opacity(0.6),
              in: Capsule())
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 2)
    }
  }

  // MARK: - Map

  private var mapCard: some View {
    VStack(alignment: .leading, spacing: 0) {
      Map(position: $position) {
        if let site = activeSite {
          // Geofence circle
          MapCircle(
            center: CLLocationCoordinate2D(latitude: site.latitude, longitude: site.longitude),
            radius: site.geofenceRadius
          )
          .foregroundStyle(Brand.paidGreen.opacity(0.14))
          .stroke(Brand.paidGreen.opacity(0.7), lineWidth: 2)

          Annotation("Site", coordinate: siteCoord(site)) {
            Image(systemName: "building.2.fill")
              .font(.caption)
              .foregroundStyle(.white)
              .padding(7)
              .background(Brand.ink, in: Circle())
          }
        }

        ForEach(mapFixes, id: \.id) { item in
          Annotation(item.label, coordinate: item.coord) {
            Image(systemName: item.symbol)
              .font(.caption2.weight(.bold))
              .foregroundStyle(.white)
              .padding(6)
              .background(item.color, in: Circle())
              .overlay(Circle().stroke(.white, lineWidth: 1.5))
          }
        }
      }
      .mapStyle(.standard(elevation: .flat))
      .frame(height: 260)
      .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

      HStack(spacing: 16) {
        legendDot(Brand.paidGreen, "On site")
        legendDot(Brand.red, "Outside")
        legendDot(Brand.amber, "No location")
      }
      .font(.caption2)
      .foregroundStyle(Brand.inkSoft)
      .padding(.top, 10)
    }
    .mpgCard()
  }

  private func legendDot(_ color: Color, _ label: String) -> some View {
    HStack(spacing: 5) {
      Circle().fill(color).frame(width: 9, height: 9)
      Text(label)
    }
  }

  private struct MapFix: Identifiable {
    let id: String
    let coord: CLLocationCoordinate2D
    let color: Color
    let symbol: String
    let label: String
  }

  private var mapFixes: [MapFix] {
    var out: [MapFix] = []
    for rec in siteRecords {
      let inFix = rec.clockInFix
      if !inFix.permissionDenied && (inFix.latitude != 0 || inFix.longitude != 0) {
        out.append(
          MapFix(
            id: "\(rec.id)-in",
            coord: CLLocationCoordinate2D(latitude: inFix.latitude, longitude: inFix.longitude),
            color: inFix.insideGeofence ? Brand.paidGreen : Brand.red,
            symbol: "arrow.down",
            label: "\(rec.tradesmanName) in"))
      }
      if let outFix = rec.clockOutFix,
        !outFix.permissionDenied, (outFix.latitude != 0 || outFix.longitude != 0)
      {
        out.append(
          MapFix(
            id: "\(rec.id)-out",
            coord: CLLocationCoordinate2D(latitude: outFix.latitude, longitude: outFix.longitude),
            color: outFix.insideGeofence ? Brand.paidGreen : Brand.red,
            symbol: "arrow.up",
            label: "\(rec.tradesmanName) out"))
      }
    }
    return out
  }

  private func siteCoord(_ site: Site) -> CLLocationCoordinate2D {
    CLLocationCoordinate2D(latitude: site.latitude, longitude: site.longitude)
  }

  private func recenter() {
    guard let site = activeSite else { return }
    let span = max(site.geofenceRadius * 6, 500)
    position = .region(
      MKCoordinateRegion(
        center: siteCoord(site),
        latitudinalMeters: span, longitudinalMeters: span))
  }

  // MARK: - Records list

  private var recordsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(
        title: "Attendance records",
        subtitle: activeSite.map { "\($0.name) · \(siteRecords.count) record(s)" })
      ForEach(siteRecords) { rec in
        Button {
          reviewRecord = rec
        } label: {
          AttendanceRecordRow(record: rec)
        }
        .buttonStyle(.plain)
      }
    }
  }
}

// MARK: - Record row

struct AttendanceRecordRow: View {
  let record: ClockRecord

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text(record.tradesmanName).font(.subheadline.weight(.semibold)).foregroundStyle(Brand.ink)
          Text("\(record.siteName) · \(Fmt.date(record.date))").font(.caption2)
            .foregroundStyle(Brand.inkSoft)
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
      HStack(spacing: 14) {
        Label(Fmt.metres(record.clockInFix.distanceFromSite), systemImage: "ruler")
        if record.requiresManualApproval {
          Label("Needs review", systemImage: "exclamationmark.circle")
            .foregroundStyle(Brand.amber)
        } else if record.adminApproved == true {
          Label("Approved", systemImage: "checkmark.seal.fill").foregroundStyle(Brand.paidGreen)
        } else if record.adminApproved == false {
          Label("Rejected", systemImage: "xmark.seal.fill").foregroundStyle(Brand.red)
        }
      }
      .font(.caption2).foregroundStyle(Brand.inkSoft)
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      Brand.lightGreen.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
  }
}

// MARK: - Review sheet

struct AttendanceReviewSheet: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  let record: ClockRecord

  private var live: ClockRecord {
    store.clockRecords.first { $0.id == record.id } ?? record
  }

  var body: some View {
    NavigationStack {
      ZStack {
        MPGBackground()
        ScrollView {
          VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
              HStack {
                Text(live.tradesmanName).font(.headline).foregroundStyle(Brand.ink)
                Spacer()
                StatusChip(text: live.overallStatus.short, color: live.overallStatus.color)
              }
              Divider().overlay(Brand.hairline)
              InfoRow(label: "Site", value: live.siteName, symbol: "building.2")
              InfoRow(label: "Date", value: Fmt.date(live.date), symbol: "calendar")
              InfoRow(label: "Clock-in", value: Fmt.time(live.clockInTime), symbol: "arrow.down.to.line")
              InfoRow(
                label: "Clock-out", value: live.clockOutTime.map(Fmt.time) ?? "Still open",
                symbol: "arrow.up.to.line")
              InfoRow(label: "Time on site", value: live.timeOnSiteString, symbol: "hourglass")
              InfoRow(
                label: "Distance (in)", value: Fmt.metres(live.clockInFix.distanceFromSite),
                symbol: "ruler")
              if let outFix = live.clockOutFix {
                InfoRow(
                  label: "Distance (out)", value: Fmt.metres(outFix.distanceFromSite),
                  symbol: "ruler")
              }
              if live.claimedHours > 0 {
                InfoRow(
                  label: "Claimed hours", value: Fmt.hours(live.claimedHours), symbol: "doc.text")
              }
              if let diff = live.hoursDifference {
                InfoRow(
                  label: "Hours difference",
                  value: (diff >= 0 ? "+" : "") + Fmt.hours(diff), symbol: "arrow.left.arrow.right")
              }
            }
            .mpgCard()

            if !live.reasonNote.isEmpty {
              VStack(alignment: .leading, spacing: 6) {
                SectionHeader(title: "Reason / note")
                Text(live.reasonNote).font(.footnote).foregroundStyle(Brand.inkSoft)
                  .frame(maxWidth: .infinity, alignment: .leading)
              }
              .mpgCard()
            }

            if live.overallStatus.needsReview {
              VStack(spacing: 10) {
                if let approved = live.adminApproved {
                  StatusChip(
                    text: approved ? "Approved" : "Rejected",
                    color: approved ? Brand.paidGreen : Brand.red, filled: true)
                }
                PrimaryButton(title: "Approve attendance", symbol: "checkmark.seal.fill", tint: Brand.paidGreen) {
                  store.setClockApproval(live.id, approved: true)
                  dismiss()
                }
                PrimaryButton(title: "Reject attendance", symbol: "xmark.seal.fill", tint: Brand.red) {
                  store.setClockApproval(live.id, approved: false)
                  dismiss()
                }
              }
            }
          }
          .padding(16)
        }
      }
      .navigationTitle("Review Attendance")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") { dismiss() }
        }
      }
    }
  }
}
