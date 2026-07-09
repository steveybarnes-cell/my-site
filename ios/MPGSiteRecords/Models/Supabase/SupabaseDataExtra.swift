import Foundation

/// Maps the remaining app models (allocations, materials, site photos,
/// notifications, query comments) to/from the live Supabase tables.
/// Same RLS-through-token pattern as `SupabaseData`.
extension SupabaseData {

  // MARK: - Sites (admin write-back)

  static func siteBody(for s: Site) -> [String: Any] {
    var dict: [String: Any] = [
      "id": s.id.uuidString.lowercased(),
      "name": s.name,
      "address": s.address,
      "client": s.client,
      "status": s.status.rawValue,
      "notes": s.notes,
      "whatsapp_link": s.whatsappLink,
      "default_start": s.defaultStart,
      "default_finish": s.defaultFinish,
      "latitude": s.latitude,
      "longitude": s.longitude,
      "geofence_radius": s.geofenceRadius,
    ]
    if let sm = s.siteManagerId { dict["site_manager_id"] = sm.uuidString.lowercased() }
    return dict
  }

  static func save(_ s: Site, token: String) async throws {
    try await SupabaseClient.shared.upsert(
      table: "sites", body: try encode(siteBody(for: s)), accessToken: token)
  }

  // MARK: - Team members (profiles)

  static func profileBody(for u: AppUser) -> [String: Any] {
    [
      "id": u.id.uuidString.lowercased(),
      "name": u.name,
      "email": u.email,
      "role": u.role.rawValue,
      "phone": u.phone,
      "active": u.active,
    ]
  }

  static func save(_ u: AppUser, token: String) async throws {
    try await SupabaseClient.shared.upsert(
      table: "profiles", body: try encode(profileBody(for: u)), accessToken: token)
  }

  // MARK: - Work allocations

  struct AllocationRow: Decodable {
    let id: String
    let site_id: String
    let tradesman_id: String
    let site_manager_id: String?
    let date: String?
    let start_time: String?
    let expected_finish: String?
    let trade: String?
    let task_description: String?
    let category: String?
    let priority: String?
    let required_photos: Bool?
    let required_materials: String?
    let notes: String?
    let status: String?

    var model: WorkAllocation? {
      guard let uid = UUID(uuidString: id), let siteUUID = UUID(uuidString: site_id),
        let tradeUUID = UUID(uuidString: tradesman_id)
      else { return nil }
      return WorkAllocation(
        id: uid, siteId: siteUUID, tradesmanId: tradeUUID,
        siteManagerId: site_manager_id.flatMap { UUID(uuidString: $0) },
        date: parseDate(date) ?? Date(), startTime: start_time ?? "",
        expectedFinish: expected_finish ?? "", trade: trade ?? "",
        taskDescription: task_description ?? "",
        category: WorkCategory(rawValue: category ?? "") ?? .contract,
        priority: Priority(rawValue: priority ?? "") ?? .normal,
        requiredPhotos: required_photos ?? false, requiredMaterials: required_materials ?? "",
        notes: notes ?? "", status: AllocationStatus(rawValue: status ?? "") ?? .allocated)
    }
  }

  static func body(for a: WorkAllocation) -> [String: Any] {
    var dict: [String: Any] = [
      "id": a.id.uuidString.lowercased(),
      "site_id": a.siteId.uuidString.lowercased(),
      "tradesman_id": a.tradesmanId.uuidString.lowercased(),
      "date": dateOnly.string(from: a.date),
      "start_time": a.startTime,
      "expected_finish": a.expectedFinish,
      "trade": a.trade,
      "task_description": a.taskDescription,
      "category": a.category.rawValue,
      "priority": a.priority.rawValue,
      "required_photos": a.requiredPhotos,
      "required_materials": a.requiredMaterials,
      "notes": a.notes,
      "status": a.status.rawValue,
    ]
    if let sm = a.siteManagerId { dict["site_manager_id"] = sm.uuidString.lowercased() }
    return dict
  }

  static func loadAllocations(token: String) async throws -> [WorkAllocation] {
    let data = try await SupabaseClient.shared.get(
      table: "work_allocations", query: "select=*&order=date.desc", accessToken: token)
    let rows = try JSONDecoder().decode([AllocationRow].self, from: data)
    return rows.compactMap { $0.model }
  }

  static func save(_ a: WorkAllocation, token: String) async throws {
    try await SupabaseClient.shared.upsert(
      table: "work_allocations", body: try encode(body(for: a)), accessToken: token)
  }

  // MARK: - Materials

  struct MaterialRow: Decodable {
    let id: String
    let user_id: String
    let site_id: String
    let daily_record_id: String?
    let date: String?
    let supplier: String?
    let description: String?
    let reason: String?
    let cost_ex_vat: Double?
    let vat_amount: Double?
    let receipt_uploaded: Bool?
    let chargeable: String?
    let approved: Bool?
    let notes: String?

    var model: MaterialItem? {
      guard let uid = UUID(uuidString: id), let userUUID = UUID(uuidString: user_id),
        let siteUUID = UUID(uuidString: site_id)
      else { return nil }
      return MaterialItem(
        id: uid, userId: userUUID, siteId: siteUUID,
        dailyRecordId: daily_record_id.flatMap { UUID(uuidString: $0) },
        date: parseDate(date) ?? Date(), supplier: supplier ?? "", description: description ?? "",
        reason: reason ?? "", costExVat: cost_ex_vat ?? 0, vatAmount: vat_amount ?? 0,
        receiptUploaded: receipt_uploaded ?? false,
        chargeable: Chargeable(rawValue: chargeable ?? "") ?? .tbc, approved: approved ?? false,
        notes: notes ?? "")
    }
  }

  static func body(for m: MaterialItem) -> [String: Any] {
    var dict: [String: Any] = [
      "id": m.id.uuidString.lowercased(),
      "user_id": m.userId.uuidString.lowercased(),
      "site_id": m.siteId.uuidString.lowercased(),
      "date": dateOnly.string(from: m.date),
      "supplier": m.supplier,
      "description": m.description,
      "reason": m.reason,
      "cost_ex_vat": m.costExVat,
      "vat_amount": m.vatAmount,
      "receipt_uploaded": m.receiptUploaded,
      "chargeable": m.chargeable.rawValue,
      "approved": m.approved,
      "notes": m.notes,
    ]
    if let d = m.dailyRecordId { dict["daily_record_id"] = d.uuidString.lowercased() }
    return dict
  }

  static func loadMaterials(token: String) async throws -> [MaterialItem] {
    let data = try await SupabaseClient.shared.get(
      table: "materials", query: "select=*&order=date.desc", accessToken: token)
    let rows = try JSONDecoder().decode([MaterialRow].self, from: data)
    return rows.compactMap { $0.model }
  }

  static func save(_ m: MaterialItem, token: String) async throws {
    try await SupabaseClient.shared.upsert(
      table: "materials", body: try encode(body(for: m)), accessToken: token)
  }

  // MARK: - Site photos / files

  struct PhotoRow: Decodable {
    let id: String
    let user_id: String
    let site_id: String
    let allocation_id: String?
    let type: String?
    let description: String?
    let timestamp: String?
    let source: String?
    let file_extension: String?
    let sync_status: String?
    let synced_at: String?
    let xero_reference: String?
    let daily_record_id: String?
    let submission_id: String?
    let material_id: String?
    let storage_path: String?
    let storage_url: String?
    let week_ending: String?

    var model: SitePhoto? {
      guard let uid = UUID(uuidString: id), let userUUID = UUID(uuidString: user_id),
        let siteUUID = UUID(uuidString: site_id)
      else { return nil }
      let photoType = PhotoType(rawValue: type ?? "") ?? .other
      return SitePhoto(
        id: uid, userId: userUUID, siteId: siteUUID,
        allocationId: allocation_id.flatMap { UUID(uuidString: $0) }, type: photoType,
        description: description ?? "", symbol: photoType.symbol,
        timestamp: parseTimestamp(timestamp) ?? Date(),
        source: CaptureSource(rawValue: source ?? "") ?? .camera,
        fileExtension: file_extension ?? "jpg",
        syncStatus: SyncStatus(rawValue: sync_status ?? "") ?? .notSynced,
        syncedAt: parseTimestamp(synced_at), xeroReference: xero_reference ?? "",
        dailyRecordId: daily_record_id.flatMap { UUID(uuidString: $0) },
        submissionId: submission_id.flatMap { UUID(uuidString: $0) },
        materialId: material_id.flatMap { UUID(uuidString: $0) },
        driveURL: storage_url ?? "", weekEnding: parseDate(week_ending),
        storageObjectPath: storage_path ?? "")
    }
  }

  static func body(for p: SitePhoto) -> [String: Any] {
    var dict: [String: Any] = [
      "id": p.id.uuidString.lowercased(),
      "user_id": p.userId.uuidString.lowercased(),
      "site_id": p.siteId.uuidString.lowercased(),
      "type": p.type.rawValue,
      "description": p.description,
      "timestamp": timestamp.string(from: p.timestamp),
      "source": p.source.rawValue,
      "file_extension": p.fileExtension,
      "sync_status": p.syncStatus.rawValue,
      "xero_reference": p.xeroReference,
      "storage_path": p.storageObjectPath.isEmpty ? p.driveFolderPath : p.storageObjectPath,
      "storage_url": p.driveURL,
    ]
    if let a = p.allocationId { dict["allocation_id"] = a.uuidString.lowercased() }
    if let d = p.dailyRecordId { dict["daily_record_id"] = d.uuidString.lowercased() }
    if let s = p.submissionId { dict["submission_id"] = s.uuidString.lowercased() }
    if let m = p.materialId { dict["material_id"] = m.uuidString.lowercased() }
    if let sa = p.syncedAt { dict["synced_at"] = timestamp.string(from: sa) }
    if let we = p.weekEnding { dict["week_ending"] = dateOnly.string(from: we) }
    return dict
  }

  static func loadPhotos(token: String) async throws -> [SitePhoto] {
    let data = try await SupabaseClient.shared.get(
      table: "site_photos", query: "select=*&order=timestamp.desc", accessToken: token)
    let rows = try JSONDecoder().decode([PhotoRow].self, from: data)
    return rows.compactMap { $0.model }
  }

  static func save(_ p: SitePhoto, token: String) async throws {
    try await SupabaseClient.shared.upsert(
      table: "site_photos", body: try encode(body(for: p)), accessToken: token)
  }

  // MARK: - Notifications

  struct NotificationRow: Decodable {
    let id: String
    let user_id: String
    let type: String?
    let message: String?
    let read: Bool?
    let timestamp: String?
    let symbol: String?

    var model: AppNotification? {
      guard let uid = UUID(uuidString: id), let userUUID = UUID(uuidString: user_id) else {
        return nil
      }
      return AppNotification(
        id: uid, userId: userUUID, type: type ?? "", message: message ?? "",
        read: read ?? false, timestamp: parseTimestamp(timestamp) ?? Date(),
        symbol: symbol ?? "bell")
    }
  }

  static func body(for n: AppNotification) -> [String: Any] {
    [
      "id": n.id.uuidString.lowercased(),
      "user_id": n.userId.uuidString.lowercased(),
      "type": n.type,
      "message": n.message,
      "read": n.read,
      "timestamp": timestamp.string(from: n.timestamp),
      "symbol": n.symbol,
    ]
  }

  static func loadNotifications(token: String) async throws -> [AppNotification] {
    let data = try await SupabaseClient.shared.get(
      table: "notifications", query: "select=*&order=timestamp.desc", accessToken: token)
    let rows = try JSONDecoder().decode([NotificationRow].self, from: data)
    return rows.compactMap { $0.model }
  }

  static func save(_ n: AppNotification, token: String) async throws {
    try await SupabaseClient.shared.upsert(
      table: "notifications", body: try encode(body(for: n)), accessToken: token)
  }

  static func markNotificationsRead(userId: UUID, token: String) async throws {
    try await SupabaseClient.shared.patch(
      table: "notifications",
      query: "user_id=eq.\(userId.uuidString.lowercased())&read=eq.false",
      body: try encode(["read": true]), accessToken: token)
  }

  // MARK: - Query comments

  struct CommentRow: Decodable {
    let id: String
    let submission_id: String
    let from_name: String?
    let to_user_id: String
    let message: String?
    let timestamp: String?
    let from_admin: Bool?

    var model: QueryComment? {
      guard let uid = UUID(uuidString: id), let subUUID = UUID(uuidString: submission_id),
        let toUUID = UUID(uuidString: to_user_id)
      else { return nil }
      return QueryComment(
        id: uid, submissionId: subUUID, fromName: from_name ?? "", toUserId: toUUID,
        message: message ?? "", timestamp: parseTimestamp(timestamp) ?? Date(),
        fromAdmin: from_admin ?? false)
    }
  }

  static func body(for c: QueryComment) -> [String: Any] {
    [
      "id": c.id.uuidString.lowercased(),
      "submission_id": c.submissionId.uuidString.lowercased(),
      "from_name": c.fromName,
      "to_user_id": c.toUserId.uuidString.lowercased(),
      "message": c.message,
      "timestamp": timestamp.string(from: c.timestamp),
      "from_admin": c.fromAdmin,
    ]
  }

  static func loadComments(token: String) async throws -> [QueryComment] {
    let data = try await SupabaseClient.shared.get(
      table: "query_comments", query: "select=*&order=timestamp", accessToken: token)
    let rows = try JSONDecoder().decode([CommentRow].self, from: data)
    return rows.compactMap { $0.model }
  }

  static func save(_ c: QueryComment, token: String) async throws {
    try await SupabaseClient.shared.upsert(
      table: "query_comments", body: try encode(body(for: c)), accessToken: token)
  }
}
