import CoreLocation
import Foundation

// MARK: - Clock record status

enum ClockStatus: String, Codable, CaseIterable, Identifiable {
  case valid = "Valid"
  case outsideSite = "Outside Site - Review Required"
  case permissionDenied = "Location Permission Denied - Admin Review Required"
  case requiresApproval = "Requires Approval"
  var id: String { rawValue }

  var short: String {
    switch self {
    case .valid: return "Valid"
    case .outsideSite: return "Outside Site"
    case .permissionDenied: return "No Location"
    case .requiresApproval: return "Review"
    }
  }

  var needsReview: Bool { self != .valid }
}

// MARK: - A single GPS location fix captured at a clock event

struct LocationFix: Hashable, Codable {
  var latitude: Double
  var longitude: Double
  var accuracy: Double  // horizontal accuracy in metres, -1 if unknown
  var distanceFromSite: Double  // metres from the site centre
  var insideGeofence: Bool
  var permissionDenied: Bool = false

  static func compute(coord: CLLocationCoordinate2D?, accuracy: Double, site: Site) -> LocationFix {
    guard let coord else {
      return LocationFix(
        latitude: 0, longitude: 0, accuracy: -1, distanceFromSite: -1,
        insideGeofence: false, permissionDenied: true)
    }
    let siteLoc = CLLocation(latitude: site.latitude, longitude: site.longitude)
    let here = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
    let distance = here.distance(from: siteLoc)
    let inside = distance <= site.geofenceRadius
    return LocationFix(
      latitude: coord.latitude, longitude: coord.longitude, accuracy: accuracy,
      distanceFromSite: distance, insideGeofence: inside, permissionDenied: false)
  }
}

// MARK: - Clock record

/// One attendance record: a clock-in, optionally closed with a clock-out.
/// Location is only ever captured at the clock event itself — never continuously.
struct ClockRecord: Identifiable, Hashable {
  let id: UUID
  var userId: UUID
  var tradesmanName: String
  var siteId: UUID
  var siteName: String
  var date: Date
  var device: String

  // Clock in
  var clockInTime: Date
  var clockInFix: LocationFix
  var clockInStatus: ClockStatus
  var clockInPhotoId: UUID? = nil

  // Clock out (nil until clocked out)
  var clockOutTime: Date? = nil
  var clockOutFix: LocationFix? = nil
  var clockOutStatus: ClockStatus? = nil
  var clockOutPhotoId: UUID? = nil

  // Review workflow
  var reasonNote: String = ""
  var adminApproved: Bool? = nil  // nil = pending, true/false = decided
  var claimedHours: Double = 0  // from the daily record, for comparison
  var createdAt: Date = Date()

  // MARK: Derived

  var isOpen: Bool { clockOutTime == nil }

  /// Attendance time on site in hours (GPS-measured), nil until clocked out.
  var timeOnSite: Double? {
    guard let out = clockOutTime else { return nil }
    return out.timeIntervalSince(clockInTime) / 3600
  }

  var timeOnSiteString: String {
    guard let hrs = timeOnSite else { return "—" }
    let h = Int(hrs)
    let m = Int((hrs - Double(h)) * 60)
    return "\(h)h \(m)m"
  }

  /// Difference between claimed invoice hours and GPS attendance time.
  var hoursDifference: Double? {
    guard let onSite = timeOnSite, claimedHours > 0 else { return nil }
    return claimedHours - onSite
  }

  /// Worst status across in + out — drives the row badge.
  var overallStatus: ClockStatus {
    let statuses = [clockInStatus, clockOutStatus].compactMap { $0 }
    if statuses.contains(.permissionDenied) { return .permissionDenied }
    if statuses.contains(.outsideSite) { return .outsideSite }
    if statuses.contains(.requiresApproval) { return .requiresApproval }
    return .valid
  }

  var requiresManualApproval: Bool {
    overallStatus.needsReview && adminApproved == nil
  }
}

// MARK: - "Clock In Records" Google Sheet row projection

struct ClockInSheetRow: Identifiable {
  var id: UUID
  var userId: String
  var tradesmanName: String
  var siteId: String
  var siteName: String
  var date: Date
  var clockInTime: Date
  var clockInLatitude: Double
  var clockInLongitude: Double
  var clockInAccuracy: Double
  var clockInDistance: Double
  var clockInInside: Bool
  var clockOutTime: Date?
  var clockOutLatitude: Double?
  var clockOutLongitude: Double?
  var clockOutAccuracy: Double?
  var clockOutDistance: Double?
  var clockOutInside: Bool?
  var totalTimeOnSite: String
  var claimedHours: Double
  var difference: Double?
  var status: String
  var adminApproval: String
  var notes: String
  var timestamp: Date
}
