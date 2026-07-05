import CoreLocation
import SwiftUI

/// Tradesman-facing clock-in / clock-out flow with proportionate, event-based location.
struct ClockInView: View {
  @Environment(AppStore.self) private var store
  @Environment(LocationService.self) private var location

  private var me: AppUser? { store.currentUser }

  /// The site to clock into — inferred from today's allocation.
  private var todaysSite: Site? {
    guard let me else { return nil }
    if let open = store.openClockRecord(for: me.id) { return store.site(open.siteId) }
    let alloc =
      store.todaysAllocations(for: me.id).first { Calendar.current.isDateInToday($0.date) }
      ?? store.todaysAllocations(for: me.id).first
    return alloc.flatMap { store.site($0.siteId) }
  }

  private var openRecord: ClockRecord? { me.flatMap { store.openClockRecord(for: $0.id) } }

  @State private var showNotice = false
  @State private var pendingEvent: ClockEvent?
  @State private var resolving = false

  enum ClockEvent { case clockIn, clockOut }

  var body: some View {
    Group {
      NavigationStack {
        ZStack {
          MPGBackground()
          ScrollView {
            VStack(spacing: 16) {
              if let site = todaysSite {
                statusCard(site)
                actionCard(site)
                historyCard
                privacyCard
              } else {
                EmptyStateView(
                  symbol: "mappin.slash", title: "No site to clock into",
                  message: "You have no allocation today. Clock-in becomes available once you are "
                    + "assigned to a site."
                ).mpgCard()
                privacyCard
              }
            }
            .padding(16)
          }
        }
        .navigationTitle("Attendance")
        .sheet(isPresented: $showNotice) {
          LocationNoticeSheet {
            location.requestPermission()
            showNotice = false
          }
        }
        .sheet(item: $pendingEvent) { event in
          if let site = todaysSite {
            ClockConfirmSheet(event: event, site: site)
          }
        }
      }
    }
    .__tenxTrackView("ClockInView")
  }

  // MARK: - Status card

  private func statusCard(_ site: Site) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        VStack(alignment: .leading, spacing: 3) {
          Text(site.name).font(.headline).foregroundStyle(Brand.ink)
          Text(site.address).font(.caption).foregroundStyle(Brand.inkSoft)
        }
        Spacer()
        if let rec = openRecord {
          StatusChip(text: "Clocked in", color: Brand.paidGreen, filled: true)
        } else {
          StatusChip(text: "Not clocked in", color: Brand.inkSoft)
        }
      }
      Divider().overlay(Brand.hairline)
      if let rec = openRecord {
        InfoRow(label: "Clock-in time", value: Fmt.time(rec.clockInTime), symbol: "clock")
        InfoRow(
          label: "Location", value: rec.clockInFix.insideGeofence ? "On site" : "Outside site",
          symbol: "location")
        InfoRow(
          label: "Distance from site", value: Fmt.metres(rec.clockInFix.distanceFromSite),
          symbol: "ruler")
      } else {
        InfoRow(
          label: "Geofence radius", value: "\(Int(site.geofenceRadius))m", symbol: "circle.dashed")
        InfoRow(
          label: "Shift", value: "\(site.defaultStart)–\(site.defaultFinish)", symbol: "clock")
      }
    }
    .mpgCard()
  }

  // MARK: - Action card

  private func actionCard(_ site: Site) -> some View {
    VStack(spacing: 12) {
      if location.permissionDenied {
        WarningBanner(
          message: "Location permission is off. You can still clock in manually — it will be "
            + "marked for admin review and needs a reason.",
          symbol: "location.slash", tint: Brand.amber)
      }
      if openRecord == nil {
        PrimaryButton(title: "Clock In", symbol: "location.fill", tint: Brand.paidGreen) {
          startEvent(.clockIn)
        }
      } else {
        PrimaryButton(title: "Clock Out", symbol: "location.slash.fill", tint: Brand.red) {
          startEvent(.clockOut)
        }
      }
    }
  }

  private func startEvent(_ event: ClockEvent) {
    if !location.permissionDecided {
      showNotice = true
      // After the notice/permission, the user taps again to proceed.
      return
    }
    pendingEvent = event
  }

  // MARK: - History

  private var historyCard: some View {
    let recent = me.map { store.clockRecords(for: $0.id) } ?? []
    return VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "My Attendance", subtitle: "Only you can see your clock records")
      if recent.isEmpty {
        Text("No clock records yet.").font(.footnote).foregroundStyle(Brand.inkSoft)
      } else {
        ForEach(recent.prefix(6)) { rec in
          ClockRecordRow(record: rec)
        }
      }
    }
    .mpgCard()
  }

  // MARK: - Privacy

  private var privacyCard: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("Your privacy", systemImage: "hand.raised.fill")
        .font(.footnote.weight(.bold)).foregroundStyle(Brand.olive)
      Text(AppStore.locationNotice)
        .font(.caption).foregroundStyle(Brand.inkSoft)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .mpgFormSection()
  }
}

extension ClockInView.ClockEvent: Identifiable {
  var id: Int { self == .clockIn ? 0 : 1 }
}

// MARK: - Location notice sheet

struct LocationNoticeSheet: View {
  let onContinue: () -> Void
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ZStack {
        MPGBackground()
        VStack(spacing: 20) {
          Image(systemName: "location.circle.fill")
            .font(.system(size: 56)).foregroundStyle(Brand.olive)
          Text("Location notice").font(.title2.bold()).foregroundStyle(Brand.ink)
          Text(AppStore.locationNotice)
            .font(.subheadline).foregroundStyle(Brand.inkSoft)
            .multilineTextAlignment(.center)
          VStack(alignment: .leading, spacing: 10) {
            noticePoint(
              "Location is only read when you clock in, clock out, upload photos or "
                + "submit records.")
            noticePoint("It is not tracked continuously and never outside work.")
            noticePoint("Used only to verify you are on the allocated site.")
          }
          .mpgFormSection()
          Spacer()
          PrimaryButton(title: "Continue", symbol: "checkmark") { onContinue() }
          Button("Not now") { dismiss() }
            .font(.subheadline).foregroundStyle(Brand.inkSoft)
        }
        .padding(20)
      }
    }
  }

  private func noticePoint(_ text: String) -> some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: "checkmark.circle.fill").font(.footnote).foregroundStyle(Brand.olive)
      Text(text).font(.caption).foregroundStyle(Brand.ink)
    }
  }
}
