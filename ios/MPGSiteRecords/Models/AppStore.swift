import Observation
import SwiftUI

@Observable
final class AppStore {
  // Session
  var currentUser: AppUser?

  // Data
  var users: [AppUser] = []
  var profiles: [TradesmanProfile] = []
  var sites: [Site] = []
  var allocations: [WorkAllocation] = []
  var dailyRecords: [DailyRecord] = []
  var materials: [MaterialItem] = []
  var photos: [SitePhoto] = []
  var submissions: [WeeklySubmission] = []
  var comments: [QueryComment] = []
  var notifications: [AppNotification] = []
  var clockRecords: [ClockRecord] = []
  var siteFiles: [SiteFile] = []

  /// Whether the company Xero organisation is connected (modelled — real flow is Xero OAuth).
  var xeroConnected: Bool = false

  // MARK: - Live backend (Supabase)

  /// When set, the three core areas (clock records, daily records, weekly
  /// submissions) read from and write to Supabase. `nil` = local/demo mode.
  private(set) var backendToken: String?

  /// True while the initial live data load is running.
  var isLoadingLiveData = false
  /// Set if a live sync fails, so the UI can surface it instead of showing stale data.
  var liveDataError: String?

  /// Number of writes captured offline and waiting to reach Supabase.
  var pendingSyncCount = 0

  var isLiveBackend: Bool { backendToken != nil }

  init() {
    seed()
    pendingSyncCount = SyncQueue.shared.count
  }

  // MARK: - Auth (mock)

  func login(as user: AppUser) { currentUser = user }

  func logout() {
    currentUser = nil
    backendToken = nil
    liveDataError = nil
  }

  // MARK: - Live backend session

  /// Switch the store into live mode for a signed-in Supabase user and load
  /// real sites + core records. Keeps sample users/profiles for name lookups.
  @MainActor
  func startLiveSession(user: AppUser, token: String) async {
    currentUser = user
    backendToken = token
    // Ensure the signed-in user is resolvable in `users` for name/lookup helpers.
    if !users.contains(where: { $0.id == user.id }) {
      users.append(user)
    }
    await loadLiveData()
  }

  /// Reload the three core areas + sites from Supabase.
  @MainActor
  func loadLiveData() async {
    guard let token = backendToken else { return }
    isLoadingLiveData = true
    liveDataError = nil
    defer { isLoadingLiveData = false }
    do {
      let liveSites = try await SupabaseData.loadSites(token: token)
      if !liveSites.isEmpty { sites = liveSites }
      clockRecords = try await SupabaseData.loadClockRecords(token: token)
      dailyRecords = try await SupabaseData.loadDailyRecords(token: token)
      submissions = try await SupabaseData.loadSubmissions(token: token)
      allocations = try await SupabaseData.loadAllocations(token: token)
      materials = try await SupabaseData.loadMaterials(token: token)
      photos = try await SupabaseData.loadPhotos(token: token)
      notifications = try await SupabaseData.loadNotifications(token: token)
      comments = try await SupabaseData.loadComments(token: token)
    } catch {
      liveDataError =
        (error as? SupabaseError)?.errorDescription ?? error.localizedDescription
    }
    // Connectivity is proven good — flush anything captured while offline.
    await drainSyncQueue()
  }

  /// Replays any queued offline writes to Supabase, in order.
  @MainActor
  func drainSyncQueue() async {
    guard let token = backendToken, !SyncQueue.shared.isEmpty else {
      pendingSyncCount = SyncQueue.shared.count
      return
    }
    let delivered = await SyncQueue.shared.drain(token: token)
    pendingSyncCount = SyncQueue.shared.count
    if delivered > 0 {
      TenXPreviewSupport.log("sync-queue drained \(delivered) op(s), \(pendingSyncCount) remaining")
    }
  }

  /// Persists a value to Supabase when in live mode. On failure (typically no
  /// connectivity) the operation is enqueued to the disk-backed `SyncQueue` and
  /// replayed automatically on the next successful live reload / drain, so the
  /// user never loses a capture. `queued` builds the replayable operation.
  private func sync(
    queued: @autoclosure () -> SyncOperation?,
    _ work: @escaping (String) async throws -> Void
  ) {
    guard let token = backendToken else { return }
    let op = queued()
    Task { @MainActor in
      do {
        try await work(token)
        await drainSyncQueue()
      } catch {
        if let op {
          SyncQueue.shared.enqueue(op)
          pendingSyncCount = SyncQueue.shared.count
        }
        self.liveDataError =
          (error as? SupabaseError)?.errorDescription ?? error.localizedDescription
      }
    }
  }

  /// Fire-and-forget persist of a value to Supabase when in live mode.
  /// Legacy path (no offline queue) kept for writes without a queue builder.
  private func persist(_ work: @escaping (String) async throws -> Void) {
    guard let token = backendToken else { return }
    Task { @MainActor in
      do {
        try await work(token)
      } catch {
        self.liveDataError =
          (error as? SupabaseError)?.errorDescription ?? error.localizedDescription
      }
    }
  }

  var role: UserRole { currentUser?.role ?? .tradesman }

  // MARK: - Convenience lookups

  func user(_ id: UUID) -> AppUser? { users.first { $0.id == id } }
  func site(_ id: UUID) -> Site? { sites.first { $0.id == id } }
  func profile(for userId: UUID) -> TradesmanProfile? { profiles.first { $0.userId == userId } }

  func tradesmen() -> [AppUser] { users.filter { $0.role == .tradesman } }
  func siteManagers() -> [AppUser] { users.filter { $0.role == .siteManager } }

  // Privacy-aware queries
  func allocations(for userId: UUID) -> [WorkAllocation] {
    allocations.filter { $0.tradesmanId == userId }.sorted { $0.date < $1.date }
  }

  func todaysAllocations(for userId: UUID) -> [WorkAllocation] {
    let cal = Calendar.current
    return allocations(for: userId).filter {
      cal.isDateInToday($0.date) || cal.isDateInTomorrow($0.date)
    }
  }

  func records(for userId: UUID) -> [DailyRecord] {
    dailyRecords.filter { $0.userId == userId }.sorted { $0.date > $1.date }
  }

  func materials(for userId: UUID) -> [MaterialItem] {
    materials.filter { $0.userId == userId }.sorted { $0.date > $1.date }
  }

  func submissions(for userId: UUID) -> [WeeklySubmission] {
    submissions.filter { $0.userId == userId }.sorted { $0.weekEnding > $1.weekEnding }
  }

  func notifications(for userId: UUID) -> [AppNotification] {
    notifications.filter { $0.userId == userId }.sorted { $0.timestamp > $1.timestamp }
  }

  func comments(for submissionId: UUID) -> [QueryComment] {
    comments.filter { $0.submissionId == submissionId }.sorted { $0.timestamp < $1.timestamp }
  }

  func sitesManaged(by managerId: UUID) -> [Site] {
    sites.filter { $0.siteManagerId == managerId }
  }

  var unreadCount: Int {
    guard let u = currentUser else { return 0 }
    return notifications.filter { $0.userId == u.id && !$0.read }.count
  }

  // MARK: - Mutations

  func markAllNotificationsRead() {
    guard let u = currentUser else { return }
    for i in notifications.indices where notifications[i].userId == u.id {
      notifications[i].read = true
    }
    let uid = u.id
    sync(queued: SupabaseData.markNotificationsReadOperation(userId: uid)) {
      try await SupabaseData.markNotificationsRead(userId: uid, token: $0)
    }
  }

  func updateAllocationStatus(_ id: UUID, to status: AllocationStatus) {
    guard let i = allocations.firstIndex(where: { $0.id == id }) else { return }
    allocations[i].status = status
    let updated = allocations[i]
    sync(queued: SupabaseData.operation(for: updated)) {
      try await SupabaseData.save(updated, token: $0)
    }
  }

  func setSubmissionStatus(_ id: UUID, to status: SubmissionStatus, by name: String? = nil) {
    guard let i = submissions.firstIndex(where: { $0.id == id }) else { return }
    submissions[i].status = status
    if status == .paid { submissions[i].paidDate = Date() }
    if let name { submissions[i].approvedBy = name }
    let sub = submissions[i]
    sync(queued: SupabaseData.operation(for: sub)) { try await SupabaseData.save(sub, token: $0) }
    notify(
      sub.userId, type: "Invoice",
      message: "Your invoice \(sub.invoiceNumber) is now \(status.rawValue).", symbol: "doc.text")
  }

  // MARK: - Admin management: sites, staff, allocations

  /// Adds or updates a site (job). Local-first; live-mode persistence for sites
  /// is handled on next backend sync once a Site save endpoint is added.
  func saveSite(_ s: Site) {
    if let i = sites.firstIndex(where: { $0.id == s.id }) {
      sites[i] = s
    } else {
      sites.append(s)
    }
  }

  /// Adds or updates a team member (tradesman or site manager).
  func saveUser(_ u: AppUser) {
    if let i = users.firstIndex(where: { $0.id == u.id }) {
      users[i] = u
    } else {
      users.append(u)
    }
  }

  /// Adds or updates a work allocation (job assigned to a tradesman for a day).
  func saveAllocation(_ a: WorkAllocation) {
    let isNew = !allocations.contains(where: { $0.id == a.id })
    if let i = allocations.firstIndex(where: { $0.id == a.id }) {
      allocations[i] = a
    } else {
      allocations.append(a)
    }
    sync(queued: SupabaseData.operation(for: a)) { try await SupabaseData.save(a, token: $0) }
    if isNew {
      notify(
        a.tradesmanId, type: "Allocation",
        message: "You have been allocated work at \(site(a.siteId)?.name ?? "a site") on "
          + "\(Fmt.date(a.date)).", symbol: "hammer.fill")
    }
  }

  func addRecord(_ r: DailyRecord) {
    dailyRecords.append(r)
    sync(queued: SupabaseData.operation(for: r)) { try await SupabaseData.save(r, token: $0) }
  }

  /// Adds or upserts a weekly submission (used when a tradesman creates/edits an invoice).
  func saveSubmission(_ s: WeeklySubmission) {
    if let i = submissions.firstIndex(where: { $0.id == s.id }) {
      submissions[i] = s
    } else {
      submissions.append(s)
    }
    sync(queued: SupabaseData.operation(for: s)) { try await SupabaseData.save(s, token: $0) }
  }

  func addMaterial(_ m: MaterialItem) {
    materials.append(m)
    sync(queued: SupabaseData.operation(for: m)) { try await SupabaseData.save(m, token: $0) }
  }
  func addPhoto(_ p: SitePhoto) {
    photos.append(p)
    sync(queued: SupabaseData.operation(for: p)) { try await SupabaseData.save(p, token: $0) }
  }

  // MARK: - File storage (Google Drive + Sheets projection)

  /// Uploads a captured file: builds the Drive folder path, auto-renames it, links it to the
  /// correct register, and records the SitePhoto (which also backs the "Photos & Files" sheet row).
  @discardableResult
  func uploadFile(
    type: PhotoType, description: String, source: CaptureSource, ext: String = "jpg",
    site: Site, allocation: WorkAllocation? = nil, dailyRecordId: UUID? = nil,
    submissionId: UUID? = nil, materialId: UUID? = nil, date: Date = Date(),
    imageData: Data? = nil
  ) -> SitePhoto {
    let uploader = currentUser?.name ?? "Unknown"
    let tradesman = allocation.flatMap { user($0.tradesmanId)?.name } ?? uploader

    let result = FileStorage.upload(
      type: type, date: date, site: site, tradesman: tradesman, ext: ext,
      allocation: allocation, dailyRecordId: dailyRecordId, submissionId: submissionId)

    // Auto-link receipts/supplier invoices to the most recent open material if none supplied.
    var linkedMaterial = materialId
    if type == .receipt || type == .supplierInvoice, linkedMaterial == nil {
      linkedMaterial =
        materials
        .filter { $0.siteId == site.id && !$0.receiptUploaded }
        .sorted { $0.date > $1.date }
        .first?.id
    }
    if let mid = linkedMaterial, let i = materials.firstIndex(where: { $0.id == mid }) {
      materials[i].receiptUploaded = true
      let updatedMaterial = materials[i]
      sync(queued: SupabaseData.operation(for: updatedMaterial)) {
        try await SupabaseData.save(updatedMaterial, token: $0)
      }
    }

    let ownerId = currentUser?.id ?? allocation?.tradesmanId ?? UUID()
    let objectPath =
      imageData != nil
      ? SupabaseStorage.objectPath(siteId: site.id, userId: ownerId, fileName: result.driveFileName)
      : ""

    let photo = SitePhoto(
      id: UUID(),
      userId: ownerId,
      siteId: site.id,
      allocationId: allocation?.id,
      type: type,
      description: description.isEmpty ? type.rawValue : description,
      symbol: type.symbol,
      timestamp: Date(),
      source: source,
      fileExtension: ext,
      dailyRecordId: dailyRecordId,
      submissionId: submissionId,
      materialId: linkedMaterial,
      driveFileId: result.driveFileId,
      driveFolderPath: result.driveFolderPath,
      driveFileName: result.driveFileName,
      driveURL: result.driveURL,
      weekEnding: result.weekEnding,
      storageObjectPath: objectPath)

    photos.append(photo)

    // Upload the real bytes to the private Storage bucket, then persist the row
    // with a signed display URL. Falls back to metadata-only if no bytes/token.
    if let imageData, !objectPath.isEmpty, let token = backendToken {
      let photoId = photo.id
      Task { @MainActor in
        do {
          try await SupabaseStorage.upload(
            data: imageData, path: objectPath,
            contentType: ext == "png" ? "image/png" : "image/jpeg", token: token)
          let signed = try? await SupabaseStorage.signedURL(path: objectPath, token: token)
          if let i = self.photos.firstIndex(where: { $0.id == photoId }) {
            if let signed { self.photos[i].driveURL = signed.absoluteString }
            self.photos[i].syncStatus = .synced
            self.photos[i].syncedAt = Date()
            let updated = self.photos[i]
            try await SupabaseData.save(updated, token: token)
          }
        } catch {
          if let i = self.photos.firstIndex(where: { $0.id == photoId }) {
            self.photos[i].syncStatus = .failed
          }
          self.liveDataError =
            (error as? SupabaseError)?.errorDescription ?? error.localizedDescription
        }
      }
    } else {
      persist { try await SupabaseData.save(photo, token: $0) }
    }

    // Notify the office when register-linked evidence lands.
    if let register = type.linkedRegister, let admin = users.first(where: { $0.role == .admin }) {
      notify(
        admin.id, type: "File",
        message: "\(tradesman) uploaded \(type.rawValue) for \(site.name) — linked to \(register).",
        symbol: type.symbol)
    }
    return photo
  }

  /// Files visible to the current user, honouring privacy rules:
  /// tradesman -> own files, site manager -> files on their assigned sites, admin -> all.
  func visibleFiles() -> [SitePhoto] {
    guard let me = currentUser else { return [] }
    let all: [SitePhoto]
    switch me.role {
    case .admin:
      all = photos
    case .siteManager:
      let siteIds = Set(sitesManaged(by: me.id).map { $0.id })
      all = photos.filter { siteIds.contains($0.siteId) }
    case .tradesman:
      all = photos.filter { $0.userId == me.id }
    }
    return all.sorted { $0.timestamp > $1.timestamp }
  }

  /// Projects a stored file into a "Photos & Files" sheet row.
  func sheetRow(for p: SitePhoto) -> FileSheetRow {
    let allocRef =
      p.allocationId.map { id in
        allocations.first { $0.id == id }.map { "ALLO " + $0.taskDescription } ?? "—"
      } ?? "—"
    return FileSheetRow(
      id: p.id,
      fileId: p.driveFileId,
      driveURL: p.driveURL,
      uploadedBy: currentUser?.name ?? user(p.userId)?.name ?? "—",
      tradesmanName: user(p.userId)?.name ?? "—",
      site: site(p.siteId)?.name ?? "—",
      date: p.timestamp,
      weekEnding: p.weekEnding,
      linkedAllocation: allocRef,
      linkedDailyRecord: p.dailyRecordId != nil ? "Linked" : "—",
      linkedSubmission: p.submissionId != nil ? "Linked" : "—",
      fileType: p.type.rawValue,
      notes: p.description,
      timestamp: p.timestamp,
      linkedRegister: p.type.linkedRegister)
  }

  // MARK: - Xero / Hub sync (modelled)

  /// File types that can be pushed to Xero / the company hub as an expense record.
  func canSyncToXero(_ p: SitePhoto) -> Bool {
    p.type == .receipt || p.type == .supplierInvoice
  }

  /// Simulates sending a receipt to Google Drive/Sheets hub + Xero.
  /// Marks it pending, then resolves to synced with a Xero reference. Replace the async
  /// body with a real Xero Files/Bills API call once Xero OAuth + a backend are connected.
  func sendToXero(_ photoId: UUID) {
    guard let i = photos.firstIndex(where: { $0.id == photoId }), canSyncToXero(photos[i]) else {
      return
    }
    photos[i].syncStatus = .pending
    let pendingPhoto = photos[i]
    persist { try await SupabaseData.save(pendingPhoto, token: $0) }
    let capturedId = photoId
    Task { @MainActor in
      try? await Task.sleep(for: .seconds(1.4))
      guard let j = self.photos.firstIndex(where: { $0.id == capturedId }) else { return }
      self.photos[j].syncStatus = .synced
      self.photos[j].syncedAt = Date()
      self.photos[j].xeroReference =
        "XERO-" + String(capturedId.uuidString.prefix(6)).uppercased()
      let syncedPhoto = self.photos[j]
      self.persist { try await SupabaseData.save(syncedPhoto, token: $0) }
    }
  }

  // MARK: - Xero (live)

  /// True while a connect / push request is in flight.
  var xeroWorking = false
  /// Set when a Xero connect/push fails, so the UI can show it.
  var xeroError: String?
  /// Xero invoice numbers keyed by submission id, once pushed successfully.
  var xeroInvoiceNumbers: [UUID: String] = [:]

  /// Runs the live "Connect to Xero" OAuth flow via the `xero-oauth` Edge Function.
  @MainActor
  func connectXero() async {
    guard let token = backendToken else {
      xeroError = "Sign in with your MPG account first to connect Xero."
      return
    }
    xeroWorking = true
    xeroError = nil
    defer { xeroWorking = false }
    do {
      try await XeroService.shared.connect(token: token)
      xeroConnected = true
    } catch let e as SupabaseError {
      if e == .oauthCancelled { return }
      xeroError = e.errorDescription
    } catch {
      xeroError = error.localizedDescription
    }
  }

  /// Pushes an approved submission to Xero as a draft invoice via the
  /// `xero-push-invoice` Edge Function, then marks it approved for payment.
  @MainActor
  func pushSubmissionToXero(_ id: UUID) async {
    guard let token = backendToken else {
      xeroError = "Sign in with your MPG account first to push to Xero."
      return
    }
    guard let sub = submissions.first(where: { $0.id == id }) else { return }
    let tradesman = user(sub.userId)?.name ?? "Subcontractor"

    var lines: [XeroService.LineItem] = []
    if sub.labourTotal > 0 {
      lines.append(
        .init(
          description: "Labour — \(String(format: "%.1f", sub.totalHours)) hrs (week ending "
            + "\(Self.shortDate(sub.weekEnding)))",
          quantity: sub.totalHours, unitAmount: sub.labourRate, accountCode: "200"))
    }
    if sub.materialsTotal > 0 {
      lines.append(
        .init(
          description: "Materials", quantity: 1, unitAmount: sub.materialsTotal, accountCode: "310")
      )
    }
    if sub.plantMileage > 0 {
      lines.append(
        .init(
          description: "Plant / mileage", quantity: 1, unitAmount: sub.plantMileage,
          accountCode: "449"))
    }
    guard !lines.isEmpty else {
      xeroError = "This invoice has no billable lines to send."
      return
    }

    xeroWorking = true
    xeroError = nil
    defer { xeroWorking = false }
    do {
      let result = try await XeroService.shared.pushInvoice(
        contactName: tradesman, reference: sub.invoiceNumber, lineItems: lines, token: token)
      if let number = result.invoiceNumber ?? result.invoiceId {
        xeroInvoiceNumbers[id] = number
      }
      setSubmissionStatus(id, to: .approvedPayment, by: currentUser?.name)
      notify(
        sub.userId, type: "Invoice",
        message: "Your invoice \(sub.invoiceNumber) has been sent to Xero for payment.",
        symbol: "sparkles.rectangle.stack")
    } catch let e as SupabaseError {
      xeroError = e.errorDescription
    } catch {
      xeroError = error.localizedDescription
    }
  }

  private static func shortDate(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "d MMM"
    return f.string(from: date)
  }

  func addQuery(submissionId: UUID, toUserId: UUID, message: String, fromAdmin: Bool) {
    let name = currentUser?.name ?? "Office"
    let comment = QueryComment(
      id: UUID(), submissionId: submissionId, fromName: name,
      toUserId: toUserId, message: message, timestamp: Date(), fromAdmin: fromAdmin)
    comments.append(comment)
    sync(queued: SupabaseData.operation(for: comment)) {
      try await SupabaseData.save(comment, token: $0)
    }
  }

  func notify(_ userId: UUID, type: String, message: String, symbol: String) {
    let n = AppNotification(
      id: UUID(), userId: userId, type: type,
      message: message, read: false, timestamp: Date(), symbol: symbol)
    notifications.append(n)
    sync(queued: SupabaseData.operation(for: n)) { try await SupabaseData.save(n, token: $0) }
  }

  // Dashboard rollups
  func missingReceiptMaterials() -> [MaterialItem] { materials.filter { !$0.receiptUploaded } }

  func lateSubmissions() -> [WeeklySubmission] {
    submissions.filter { sub in
      guard let submitted = sub.submittedAt else { return false }
      return submitted > deadline(for: sub.weekEnding)
    }
  }

  /// Monday 13:00 after the given week ending.
  func deadline(for weekEnding: Date) -> Date {
    let cal = Calendar.current
    let monday = cal.date(byAdding: .day, value: 2, to: weekEnding) ?? weekEnding
    return cal.date(bySettingHour: 13, minute: 0, second: 0, of: monday) ?? monday
  }

  func labourCostBySite() -> [(Site, Double)] {
    sites.map { site in
      let cost = dailyRecords.filter { $0.siteId == site.id }.reduce(0.0) { acc, r in
        let rate = profile(for: r.userId)?.hourlyRate ?? 0
        return acc + r.totalHours * rate
      }
      return (site, cost)
    }
  }

  func materialsCostBySite() -> [(Site, Double)] {
    sites.map { site in
      let cost = materials.filter { $0.siteId == site.id }.reduce(0.0) { $0 + $1.total }
      return (site, cost)
    }
  }

  func variationRecords() -> [DailyRecord] {
    dailyRecords.filter { $0.category == .variation }.sorted { $0.date > $1.date }
  }

  // MARK: - Attendance / clock in-out

  static let locationNotice =
    "My Project Group Ltd uses your phone location only to verify clock-in, clock-out, site "
    + "attendance, and site evidence. Your location is recorded when you clock in, clock out, "
    + "upload site photos, or submit site records. The app does not track your personal movement "
    + "outside work."

  /// The open (not yet clocked-out) record for a tradesman today, if any.
  func openClockRecord(for userId: UUID) -> ClockRecord? {
    clockRecords.first {
      $0.userId == userId && $0.isOpen && Calendar.current.isDateInToday($0.date)
    }
  }

  func clockRecords(for userId: UUID) -> [ClockRecord] {
    clockRecords.filter { $0.userId == userId }.sorted { $0.clockInTime > $1.clockInTime }
  }

  /// Clock records visible to the current viewer (privacy rules).
  func visibleClockRecords() -> [ClockRecord] {
    guard let me = currentUser else { return [] }
    let all: [ClockRecord]
    switch me.role {
    case .admin:
      all = clockRecords
    case .siteManager:
      let siteIds = Set(sitesManaged(by: me.id).map { $0.id })
      all = clockRecords.filter { siteIds.contains($0.siteId) }
    case .tradesman:
      all = clockRecords.filter { $0.userId == me.id }
    }
    return all.sorted { $0.clockInTime > $1.clockInTime }
  }

  private func status(for fix: LocationFix) -> ClockStatus {
    if fix.permissionDenied { return .permissionDenied }
    return fix.insideGeofence ? .valid : .outsideSite
  }

  /// Public status resolver for previewing a fix before committing it.
  func statusFor(_ fix: LocationFix) -> ClockStatus { status(for: fix) }

  /// Records a clock-in event.
  @discardableResult
  func clockIn(
    site: Site, fix: LocationFix, device: String, reasonNote: String,
    photoDescription: String? = nil
  ) -> ClockRecord {
    let me = currentUser
    let name = me?.name ?? "Unknown"
    let st = status(for: fix)

    var photoId: UUID? = nil
    if let desc = photoDescription {
      let p = uploadFile(
        type: .clockIn, description: desc.isEmpty ? "Clock-in photo" : desc, source: .camera,
        site: site)
      photoId = p.id
    }

    let record = ClockRecord(
      id: UUID(), userId: me?.id ?? UUID(), tradesmanName: name, siteId: site.id,
      siteName: site.name, date: Date(), device: device,
      clockInTime: Date(), clockInFix: fix, clockInStatus: st, clockInPhotoId: photoId,
      reasonNote: reasonNote)
    clockRecords.append(record)

    sync(queued: SupabaseData.operation(for: record)) {
      try await SupabaseData.save(record, token: $0)
    }
    notifyAttendance(record: record, event: "clocked in")
    return record
  }

  /// Closes an open clock record with a clock-out event.
  func clockOut(
    recordId: UUID, site: Site, fix: LocationFix, reasonNote: String,
    claimedHours: Double = 0, photoDescription: String? = nil
  ) {
    guard let i = clockRecords.firstIndex(where: { $0.id == recordId }) else { return }
    let st = status(for: fix)

    if let desc = photoDescription {
      let p = uploadFile(
        type: .clockIn, description: desc.isEmpty ? "Clock-out photo" : desc, source: .camera,
        site: site)
      clockRecords[i].clockOutPhotoId = p.id
    }

    clockRecords[i].clockOutTime = Date()
    clockRecords[i].clockOutFix = fix
    clockRecords[i].clockOutStatus = st
    if claimedHours > 0 { clockRecords[i].claimedHours = claimedHours }
    if !reasonNote.isEmpty {
      clockRecords[i].reasonNote =
        clockRecords[i].reasonNote.isEmpty
        ? reasonNote : clockRecords[i].reasonNote + "\n" + reasonNote
    }
    notifyAttendance(record: clockRecords[i], event: "clocked out")
    let updated = clockRecords[i]
    sync(queued: SupabaseData.operation(for: updated)) {
      try await SupabaseData.save(updated, token: $0)
    }
  }

  func setClockApproval(_ id: UUID, approved: Bool) {
    guard let i = clockRecords.firstIndex(where: { $0.id == id }) else { return }
    clockRecords[i].adminApproved = approved
    let updated = clockRecords[i]
    sync(queued: SupabaseData.operation(for: updated)) {
      try await SupabaseData.save(updated, token: $0)
    }
  }

  /// Notifies admin + site manager when an attendance event needs review.
  private func notifyAttendance(record: ClockRecord, event: String) {
    guard record.overallStatus.needsReview else { return }
    let reason = record.overallStatus.rawValue
    if let admin = users.first(where: { $0.role == .admin }) {
      notify(
        admin.id, type: "Attendance",
        message: "\(record.tradesmanName) \(event) at \(record.siteName) — \(reason).",
        symbol: "location.slash")
    }
    if let smId = site(record.siteId)?.siteManagerId {
      notify(
        smId, type: "Attendance",
        message: "\(record.tradesmanName) \(event) at \(record.siteName) — \(reason).",
        symbol: "location.slash")
    }
  }

  /// Projects a clock record into a "Clock In Records" Google Sheet row.
  func clockInSheetRow(for r: ClockRecord) -> ClockInSheetRow {
    ClockInSheetRow(
      id: r.id,
      userId: String(r.userId.uuidString.prefix(8)),
      tradesmanName: r.tradesmanName,
      siteId: String(r.siteId.uuidString.prefix(8)),
      siteName: r.siteName,
      date: r.date,
      clockInTime: r.clockInTime,
      clockInLatitude: r.clockInFix.latitude,
      clockInLongitude: r.clockInFix.longitude,
      clockInAccuracy: r.clockInFix.accuracy,
      clockInDistance: r.clockInFix.distanceFromSite,
      clockInInside: r.clockInFix.insideGeofence,
      clockOutTime: r.clockOutTime,
      clockOutLatitude: r.clockOutFix?.latitude,
      clockOutLongitude: r.clockOutFix?.longitude,
      clockOutAccuracy: r.clockOutFix?.accuracy,
      clockOutDistance: r.clockOutFix?.distanceFromSite,
      clockOutInside: r.clockOutFix?.insideGeofence,
      totalTimeOnSite: r.timeOnSiteString,
      claimedHours: r.claimedHours,
      difference: r.hoursDifference,
      status: r.overallStatus.rawValue,
      adminApproval: r.adminApproved == nil
        ? (r.requiresManualApproval ? "Pending" : "N/A")
        : (r.adminApproved! ? "Approved" : "Rejected"),
      notes: r.reasonNote,
      timestamp: r.createdAt)
  }
}
