import Foundation
import SwiftUI

// MARK: - Site Files Hub store logic

extension AppStore {

  // MARK: Permissions & visibility

  /// Sites the current user may open in the Files Hub.
  func hubSites() -> [Site] {
    guard let me = currentUser else { return [] }
    switch me.role {
    case .admin:
      return sites
    case .siteManager:
      return sitesManaged(by: me.id)
    case .tradesman:
      let siteIds = Set(allocations(for: me.id).map { $0.siteId })
      return sites.filter { siteIds.contains($0.id) }
    }
  }

  /// Whether the current user can see a specific file (role + visibility + allocation rules).
  func canView(_ file: SiteFile) -> Bool {
    guard let me = currentUser else { return false }
    switch me.role {
    case .admin:
      return true
    case .siteManager:
      let mySites = Set(sitesManaged(by: me.id).map { $0.id })
      guard mySites.contains(file.siteId) else { return false }
      return file.visibility != .adminOnly
    case .tradesman:
      // Tradesmen only see files on their allocated sites.
      let mySites = Set(allocations(for: me.id).map { $0.siteId })
      guard mySites.contains(file.siteId) else { return false }
      switch file.visibility {
      case .adminOnly, .managersOnly: return false
      case .uploaderOnly: return file.uploadedById == me.id
      case .everyone: return true
      }
    }
  }

  /// Whether the current user can upload/add files to a given site.
  func canUpload(to site: Site) -> Bool {
    guard let me = currentUser else { return false }
    switch me.role {
    case .admin: return true
    case .siteManager: return site.siteManagerId == me.id
    case .tradesman:
      return allocations(for: me.id).contains { $0.siteId == site.id }
    }
  }

  /// Whether the current user can approve / manage files (admin + site managers).
  var canManageFiles: Bool {
    role == .admin || role == .siteManager
  }

  // MARK: Queries

  /// All files the current user may see, newest first.
  func visibleSiteFiles() -> [SiteFile] {
    siteFiles.filter { canView($0) }.sorted { $0.uploadedAt > $1.uploadedAt }
  }

  /// Files for a specific site the current user may see.
  func files(forSite siteId: UUID) -> [SiteFile] {
    visibleSiteFiles().filter { $0.siteId == siteId }
  }

  /// Files for a site in a specific category.
  func files(forSite siteId: UUID, category: FileCategory) -> [SiteFile] {
    files(forSite: siteId).filter { $0.category == category }
  }

  /// Count of visible files for a site in a category.
  func fileCount(forSite siteId: UUID, category: FileCategory) -> Int {
    files(forSite: siteId, category: category).count
  }

  func fileCount(forSite siteId: UUID, group: FileGroup) -> Int {
    files(forSite: siteId).filter { group.categories.contains($0.category) }.count
  }

  /// Cross-field search across all visible files.
  func searchSiteFiles(_ query: String) -> [SiteFile] {
    let q = query.trimmingCharacters(in: .whitespaces).lowercased()
    guard !q.isEmpty else { return [] }
    return visibleSiteFiles().filter { f in
      let siteName = site(f.siteId)?.name ?? ""
      let hay =
        [
          f.title, f.category.rawValue, f.uploadedByName, f.notes, siteName,
          f.fileType, f.tags.joined(separator: " "),
        ]
        .joined(separator: " ").lowercased()
      return hay.contains(q)
    }
  }

  // MARK: Mutations

  @discardableResult
  func addSiteFile(
    site: Site, title: String, category: FileCategory, origin: FileOrigin,
    fileType: String, driveURL: String, notes: String, visibility: FileVisibility,
    tags: [String], tradesmanId: UUID? = nil, allocationId: UUID? = nil,
    dailyRecordId: UUID? = nil, submissionId: UUID? = nil, materialId: UUID? = nil,
    variationId: UUID? = nil
  ) -> SiteFile {
    let me = currentUser
    let uploaderName = me?.name ?? "Unknown"
    let week = FileStorage.weekEndingSunday(for: Date())
    let folder =
      [
        FileStorage.rootFolder, "Site Files", site.name, category.rawValue,
        "WE " + week.formatted(.dateTime.day().month(.twoDigits).year()),
      ].joined(separator: " / ")

    // Uploaders (site team) auto-approve nothing; admin uploads are auto-approved.
    let approval: FileApproval = (me?.role == .admin) ? .approved : .awaiting

    let file = SiteFile(
      id: UUID(), siteId: site.id, title: title.isEmpty ? category.rawValue : title,
      category: category, origin: origin,
      fileType: fileType.isEmpty ? (origin == .driveLink ? "Drive link" : "File") : fileType,
      uploadedById: me?.id ?? UUID(), uploadedByName: uploaderName, uploadedAt: Date(),
      tradesmanId: tradesmanId, allocationId: allocationId, dailyRecordId: dailyRecordId,
      submissionId: submissionId, materialId: materialId, variationId: variationId,
      notes: notes, driveURL: driveURL, driveFolderPath: folder, visibility: visibility,
      approval: approval, tags: tags)

    siteFiles.append(file)

    // Notify the office when site-team evidence lands and needs review.
    if approval == .awaiting, let admin = users.first(where: { $0.role == .admin }) {
      notify(
        admin.id, type: "File",
        message: "\(uploaderName) added \(category.rawValue) to \(site.name) — awaiting review.",
        symbol: category.symbol)
    }
    return file
  }

  func setFileApproval(_ id: UUID, to approval: FileApproval) {
    guard let i = siteFiles.firstIndex(where: { $0.id == id }) else { return }
    siteFiles[i].approval = approval
  }

  func toggleHandover(_ id: UUID) {
    guard let i = siteFiles.firstIndex(where: { $0.id == id }) else { return }
    siteFiles[i].inHandoverPack.toggle()
  }

  func deleteSiteFile(_ id: UUID) {
    siteFiles.removeAll { $0.id == id }
  }

  // MARK: Register projection (modelled Google Sheet)

  func registerRow(for f: SiteFile) -> SiteFileRegisterRow {
    func short(_ id: UUID?) -> String { id.map { String($0.uuidString.prefix(6)) } ?? "—" }
    return SiteFileRegisterRow(
      id: f.id,
      fileId: String(f.id.uuidString.prefix(8)),
      siteId: String(f.siteId.uuidString.prefix(6)),
      siteName: site(f.siteId)?.name ?? "—",
      title: f.title,
      category: f.category.rawValue,
      fileType: f.fileType,
      uploadedBy: f.uploadedByName,
      uploadedDate: f.uploadedAt,
      relatedTradesman: f.tradesmanId.flatMap { user($0)?.name } ?? "—",
      relatedAllocation: short(f.allocationId),
      relatedDailyRecord: short(f.dailyRecordId),
      relatedSubmission: short(f.submissionId),
      relatedMaterial: short(f.materialId),
      relatedVariation: short(f.variationId),
      driveLink: f.driveURL,
      notes: f.notes,
      visibility: f.visibility.rawValue,
      approval: f.approval.rawValue,
      tags: f.tags.joined(separator: ", "))
  }

  // MARK: Dashboard rollups & prompts

  var filesThisWeek: Int {
    let start = FileStorage.weekEndingSunday(for: Date()).addingTimeInterval(-7 * 86_400)
    return siteFiles.filter { $0.uploadedAt >= start }.count
  }

  func filesAwaitingApproval() -> [SiteFile] {
    siteFiles.filter { $0.approval == .awaiting }.sorted { $0.uploadedAt > $1.uploadedAt }
  }

  func recentSiteFiles(_ limit: Int = 6) -> [SiteFile] {
    Array(siteFiles.sorted { $0.uploadedAt > $1.uploadedAt }.prefix(limit))
  }

  /// Sites that have no drawings uploaded yet.
  func sitesMissingDrawings() -> [Site] {
    sites.filter { s in
      !siteFiles.contains { $0.siteId == s.id && $0.category == .drawings }
    }
  }

  /// Sites missing any RAMS / health & safety document.
  func sitesMissingHealthSafety() -> [Site] {
    sites.filter { s in
      !siteFiles.contains {
        $0.siteId == s.id && ($0.category == .rams || $0.category == .healthSafety)
      }
    }
  }

  /// Variation daily records with no variation-evidence photo uploaded.
  func variationsMissingPhotos() -> [DailyRecord] {
    variationRecords().filter { rec in
      !siteFiles.contains { $0.dailyRecordId == rec.id && $0.category == .variationEvidence }
        && !photos.contains { $0.dailyRecordId == rec.id && $0.type == .variation }
    }
  }

  /// Files-by-site counts for the dashboard.
  func fileCountsBySite() -> [(Site, Int)] {
    sites.map { s in (s, siteFiles.filter { $0.siteId == s.id }.count) }
  }

  /// Files marked for the handover pack on a given site.
  func handoverFiles(forSite siteId: UUID) -> [SiteFile] {
    siteFiles.filter { $0.siteId == siteId && $0.inHandoverPack }
      .sorted { $0.category.rawValue < $1.category.rawValue }
  }
}
