import Foundation

/// Maps app models to/from the live Supabase (PostgREST) tables for the three
/// core data areas that must be viewable from a PC: sites, clock records,
/// daily records and weekly submissions.
///
/// All reads/writes go through `SupabaseClient` with the signed-in user's token,
/// so Row Level Security decides what each role can see and write.
enum SupabaseData {

  // MARK: - Formatters

  /// `timestamptz` columns.
  static let timestamp: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
  }()

  private static let timestampNoFraction: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
  }()

  /// `date` columns (yyyy-MM-dd).
  static let dateOnly: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(identifier: "UTC")
    f.dateFormat = "yyyy-MM-dd"
    return f
  }()

  static func parseTimestamp(_ s: String?) -> Date? {
    guard let s else { return nil }
    return timestamp.date(from: s) ?? timestampNoFraction.date(from: s)
  }

  static func parseDate(_ s: String?) -> Date? {
    guard let s else { return nil }
    return dateOnly.date(from: s) ?? parseTimestamp(s)
  }

  static func encode(_ object: [String: Any]) throws -> Data {
    try JSONSerialization.data(withJSONObject: object)
  }

  static func encode(_ array: [[String: Any]]) throws -> Data {
    try JSONSerialization.data(withJSONObject: array)
  }

  // MARK: - Sites (read-only for the app)

  struct SiteRow: Decodable {
    let id: String
    let name: String
    let address: String?
    let client: String?
    let site_manager_id: String?
    let status: String
    let notes: String?
    let whatsapp_link: String?
    let default_start: String?
    let default_finish: String?
    let latitude: Double?
    let longitude: Double?
    let geofence_radius: Double?

    var model: Site? {
      guard let uid = UUID(uuidString: id) else { return nil }
      return Site(
        id: uid, name: name, address: address ?? "", client: client ?? "",
        siteManagerId: site_manager_id.flatMap { UUID(uuidString: $0) },
        status: SiteStatus(rawValue: status) ?? .active, notes: notes ?? "",
        whatsappLink: whatsapp_link ?? "", defaultStart: default_start ?? "08:00",
        defaultFinish: default_finish ?? "16:30", latitude: latitude ?? 0,
        longitude: longitude ?? 0, geofenceRadius: geofence_radius ?? 150)
    }
  }

  static func loadSites(token: String) async throws -> [Site] {
    let data = try await SupabaseClient.shared.get(
      table: "sites", query: "select=*&order=name", accessToken: token)
    let rows = try JSONDecoder().decode([SiteRow].self, from: data)
    return rows.compactMap { $0.model }
  }

  // MARK: - Clock records

  struct ClockRow: Decodable {
    let id: String
    let user_id: String
    let tradesman_name: String?
    let site_id: String
    let site_name: String?
    let date: String?
    let device: String?
    let clock_in_time: String?
    let clock_in_lat: Double?
    let clock_in_lng: Double?
    let clock_in_accuracy: Double?
    let clock_in_distance: Double?
    let clock_in_inside: Bool?
    let clock_in_status: String?
    let clock_out_time: String?
    let clock_out_lat: Double?
    let clock_out_lng: Double?
    let clock_out_accuracy: Double?
    let clock_out_distance: Double?
    let clock_out_inside: Bool?
    let clock_out_status: String?
    let claimed_hours: Double?
    let admin_approved: Bool?
    let reason_note: String?
    let created_at: String?

    private func fix(
      _ lat: Double?, _ lng: Double?, _ acc: Double?, _ dist: Double?, _ inside: Bool?
    )
      -> LocationFix?
    {
      guard let lat, let lng else { return nil }
      return LocationFix(
        latitude: lat, longitude: lng, accuracy: acc ?? -1, distanceFromSite: dist ?? -1,
        insideGeofence: inside ?? false, permissionDenied: false)
    }

    var model: ClockRecord? {
      guard let uid = UUID(uuidString: id), let userUUID = UUID(uuidString: user_id),
        let siteUUID = UUID(uuidString: site_id),
        let inFix = fix(
          clock_in_lat, clock_in_lng, clock_in_accuracy, clock_in_distance, clock_in_inside)
      else { return nil }
      return ClockRecord(
        id: uid, userId: userUUID, tradesmanName: tradesman_name ?? "Unknown", siteId: siteUUID,
        siteName: site_name ?? "", date: parseDate(date) ?? Date(),
        device: device ?? "Mobile device",
        clockInTime: parseTimestamp(clock_in_time) ?? Date(), clockInFix: inFix,
        clockInStatus: ClockStatus(rawValue: clock_in_status ?? "Valid") ?? .valid,
        clockOutTime: parseTimestamp(clock_out_time),
        clockOutFix: fix(
          clock_out_lat, clock_out_lng, clock_out_accuracy, clock_out_distance, clock_out_inside),
        clockOutStatus: clock_out_status.flatMap { ClockStatus(rawValue: $0) },
        reasonNote: reason_note ?? "", adminApproved: admin_approved,
        claimedHours: claimed_hours ?? 0, createdAt: parseTimestamp(created_at) ?? Date())
    }
  }

  static func body(for r: ClockRecord) -> [String: Any] {
    var dict: [String: Any] = [
      "id": r.id.uuidString.lowercased(),
      "user_id": r.userId.uuidString.lowercased(),
      "tradesman_name": r.tradesmanName,
      "site_id": r.siteId.uuidString.lowercased(),
      "site_name": r.siteName,
      "date": dateOnly.string(from: r.date),
      "device": r.device,
      "clock_in_time": timestamp.string(from: r.clockInTime),
      "clock_in_lat": r.clockInFix.latitude,
      "clock_in_lng": r.clockInFix.longitude,
      "clock_in_accuracy": r.clockInFix.accuracy,
      "clock_in_distance": r.clockInFix.distanceFromSite,
      "clock_in_inside": r.clockInFix.insideGeofence,
      "clock_in_status": r.clockInStatus.rawValue,
      "claimed_hours": r.claimedHours,
      "reason_note": r.reasonNote,
      "created_at": timestamp.string(from: r.createdAt),
    ]
    if let out = r.clockOutTime { dict["clock_out_time"] = timestamp.string(from: out) }
    if let f = r.clockOutFix {
      dict["clock_out_lat"] = f.latitude
      dict["clock_out_lng"] = f.longitude
      dict["clock_out_accuracy"] = f.accuracy
      dict["clock_out_distance"] = f.distanceFromSite
      dict["clock_out_inside"] = f.insideGeofence
    }
    if let s = r.clockOutStatus { dict["clock_out_status"] = s.rawValue }
    if let a = r.adminApproved { dict["admin_approved"] = a }
    return dict
  }

  static func loadClockRecords(token: String) async throws -> [ClockRecord] {
    let data = try await SupabaseClient.shared.get(
      table: "clock_records", query: "select=*&order=clock_in_time.desc", accessToken: token)
    let rows = try JSONDecoder().decode([ClockRow].self, from: data)
    return rows.compactMap { $0.model }
  }

  static func save(_ r: ClockRecord, token: String) async throws {
    try await SupabaseClient.shared.upsert(
      table: "clock_records", body: try encode(body(for: r)), accessToken: token)
  }

  // MARK: - Daily records

  struct DailyRow: Decodable {
    let id: String
    let allocation_id: String?
    let user_id: String
    let site_id: String
    let date: String?
    let start_time: String?
    let finish_time: String?
    let break_minutes: Int?
    let total_hours: Double?
    let trade: String?
    let description: String?
    let category: String?
    let delay_reason: String?
    let delay_note: String?
    let notes: String?
    let variation_instructed_by: String?
    let variation_status: String?

    var model: DailyRecord? {
      guard let uid = UUID(uuidString: id), let userUUID = UUID(uuidString: user_id),
        let siteUUID = UUID(uuidString: site_id)
      else { return nil }
      return DailyRecord(
        id: uid, allocationId: allocation_id.flatMap { UUID(uuidString: $0) }, userId: userUUID,
        siteId: siteUUID, date: parseDate(date) ?? Date(), startTime: start_time ?? "",
        finishTime: finish_time ?? "", breakMinutes: break_minutes ?? 0,
        totalHours: total_hours ?? 0, trade: trade ?? "", description: description ?? "",
        category: WorkCategory(rawValue: category ?? "") ?? .contract,
        delayReason: DelayReason(rawValue: delay_reason ?? "") ?? .none,
        delayNote: delay_note ?? "",
        notes: notes ?? "", variationInstructedBy: variation_instructed_by ?? "",
        variationStatus: variation_status.flatMap { VariationStatus(rawValue: $0) })
    }
  }

  static func body(for r: DailyRecord) -> [String: Any] {
    var dict: [String: Any] = [
      "id": r.id.uuidString.lowercased(),
      "user_id": r.userId.uuidString.lowercased(),
      "site_id": r.siteId.uuidString.lowercased(),
      "date": dateOnly.string(from: r.date),
      "start_time": r.startTime,
      "finish_time": r.finishTime,
      "break_minutes": r.breakMinutes,
      "total_hours": r.totalHours,
      "trade": r.trade,
      "description": r.description,
      "category": r.category.rawValue,
      "delay_reason": r.delayReason.rawValue,
      "delay_note": r.delayNote,
      "notes": r.notes,
      "variation_instructed_by": r.variationInstructedBy,
    ]
    if let a = r.allocationId { dict["allocation_id"] = a.uuidString.lowercased() }
    if let v = r.variationStatus { dict["variation_status"] = v.rawValue }
    return dict
  }

  static func loadDailyRecords(token: String) async throws -> [DailyRecord] {
    let data = try await SupabaseClient.shared.get(
      table: "daily_records", query: "select=*&order=date.desc", accessToken: token)
    let rows = try JSONDecoder().decode([DailyRow].self, from: data)
    return rows.compactMap { $0.model }
  }

  static func save(_ r: DailyRecord, token: String) async throws {
    try await SupabaseClient.shared.upsert(
      table: "daily_records", body: try encode(body(for: r)), accessToken: token)
  }

  // MARK: - Weekly submissions

  struct SubmissionRow: Decodable {
    let id: String
    let user_id: String
    let week_ending: String?
    let invoice_number: String
    let total_hours: Double?
    let labour_rate: Double?
    let materials_total: Double?
    let plant_mileage: Double?
    let cis_rate: Double?
    let vat_registered: Bool?
    let status: String
    let submitted_at: String?
    let approved_by: String?
    let paid_date: String?

    var model: WeeklySubmission? {
      guard let uid = UUID(uuidString: id), let userUUID = UUID(uuidString: user_id) else {
        return nil
      }
      return WeeklySubmission(
        id: uid, userId: userUUID, weekEnding: parseDate(week_ending) ?? Date(),
        invoiceNumber: invoice_number, totalHours: total_hours ?? 0, labourRate: labour_rate ?? 0,
        materialsTotal: materials_total ?? 0, plantMileage: plant_mileage ?? 0,
        cisRate: cis_rate ?? 0.2, vatRegistered: vat_registered ?? false,
        status: SubmissionStatus(rawValue: status) ?? .submitted,
        submittedAt: parseTimestamp(submitted_at), approvedBy: approved_by,
        paidDate: parseTimestamp(paid_date))
    }
  }

  static func body(for r: WeeklySubmission) -> [String: Any] {
    var dict: [String: Any] = [
      "id": r.id.uuidString.lowercased(),
      "user_id": r.userId.uuidString.lowercased(),
      "week_ending": dateOnly.string(from: r.weekEnding),
      "invoice_number": r.invoiceNumber,
      "total_hours": r.totalHours,
      "labour_rate": r.labourRate,
      "materials_total": r.materialsTotal,
      "plant_mileage": r.plantMileage,
      "cis_rate": r.cisRate,
      "vat_registered": r.vatRegistered,
      "status": r.status.rawValue,
    ]
    if let s = r.submittedAt { dict["submitted_at"] = timestamp.string(from: s) }
    if let a = r.approvedBy { dict["approved_by"] = a }
    if let p = r.paidDate { dict["paid_date"] = timestamp.string(from: p) }
    return dict
  }

  static func loadSubmissions(token: String) async throws -> [WeeklySubmission] {
    let data = try await SupabaseClient.shared.get(
      table: "weekly_submissions", query: "select=*&order=week_ending.desc", accessToken: token)
    let rows = try JSONDecoder().decode([SubmissionRow].self, from: data)
    return rows.compactMap { $0.model }
  }

  static func save(_ r: WeeklySubmission, token: String) async throws {
    try await SupabaseClient.shared.upsert(
      table: "weekly_submissions", body: try encode(body(for: r)), accessToken: token)
  }
}
