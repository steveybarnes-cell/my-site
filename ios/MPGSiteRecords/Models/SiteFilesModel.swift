import Foundation
import SwiftUI

// MARK: - File category

/// The full set of Site Files Hub categories.
enum FileCategory: String, Codable, CaseIterable, Identifiable {
  case drawings = "Drawings"
  case structural = "Structural calculations"
  case buildingControl = "Building control"
  case planning = "Planning"
  case clientInstruction = "Client instruction"
  case variationEvidence = "Variation evidence"
  case snagging = "Snagging"
  case sitePhotos = "Site photos"
  case progressPhotos = "Progress photos"
  case beforePhotos = "Before photos"
  case completedWorks = "Completed works"
  case delayEvidence = "Delay evidence"
  case damageEvidence = "Damage / issue evidence"
  case materialsReceipt = "Materials receipt"
  case supplierInvoice = "Supplier invoice"
  case quoteOrder = "Quote / order"
  case rams = "RAMS"
  case healthSafety = "Health & safety"
  case programme = "Programme / schedule"
  case report = "Report"
  case handover = "Handover"
  case warranty = "Warranty"
  case other = "Other"

  var id: String { rawValue }

  var symbol: String {
    switch self {
    case .drawings: return "ruler"
    case .structural: return "function"
    case .buildingControl: return "checkmark.seal"
    case .planning: return "map"
    case .clientInstruction: return "envelope.open"
    case .variationEvidence: return "photo.badge.checkmark"
    case .snagging: return "exclamationmark.triangle"
    case .sitePhotos: return "photo"
    case .progressPhotos: return "photo.stack"
    case .beforePhotos: return "photo.on.rectangle"
    case .completedWorks: return "photo.fill"
    case .delayEvidence: return "clock.badge.exclamationmark"
    case .damageEvidence: return "hammer"
    case .materialsReceipt: return "doc.text.viewfinder"
    case .supplierInvoice: return "doc.richtext"
    case .quoteOrder: return "cart"
    case .rams: return "shield.lefthalf.filled"
    case .healthSafety: return "cross.case"
    case .programme: return "calendar"
    case .report: return "doc.plaintext"
    case .handover: return "shippingbox"
    case .warranty: return "rosette"
    case .other: return "folder"
    }
  }

  /// High-level folder group shown on the site hub screen.
  var group: FileGroup {
    switch self {
    case .drawings, .structural, .buildingControl, .planning: return .technical
    case .sitePhotos, .progressPhotos, .beforePhotos, .completedWorks: return .photos
    case .materialsReceipt, .supplierInvoice, .quoteOrder: return .financial
    case .variationEvidence, .delayEvidence, .damageEvidence, .snagging: return .evidence
    case .clientInstruction, .report, .programme: return .records
    case .rams, .healthSafety: return .safety
    case .handover, .warranty, .other: return .handover
    }
  }
}

/// Folder groups used to organise categories on the site hub screen.
enum FileGroup: String, CaseIterable, Identifiable {
  case technical = "Drawings & Technical"
  case photos = "Photos"
  case financial = "Receipts & Invoices"
  case evidence = "Evidence & Snagging"
  case records = "Records & Instructions"
  case safety = "RAMS / Health & Safety"
  case handover = "Handover & Other"

  var id: String { rawValue }

  var symbol: String {
    switch self {
    case .technical: return "ruler.fill"
    case .photos: return "photo.stack.fill"
    case .financial: return "sterlingsign.circle.fill"
    case .evidence: return "exclamationmark.bubble.fill"
    case .records: return "doc.on.doc.fill"
    case .safety: return "cross.case.fill"
    case .handover: return "shippingbox.fill"
    }
  }

  var categories: [FileCategory] { FileCategory.allCases.filter { $0.group == self } }
}

// MARK: - File source, visibility, approval

enum FileOrigin: String, Codable, CaseIterable, Identifiable {
  case upload = "Uploaded file"
  case driveLink = "Google Drive link"
  var id: String { rawValue }
  var symbol: String { self == .upload ? "arrow.up.doc" : "link" }
}

enum FileVisibility: String, Codable, CaseIterable, Identifiable {
  case everyone = "All site team"
  case managersOnly = "Managers & admin"
  case adminOnly = "Admin only"
  case uploaderOnly = "Uploader only"
  var id: String { rawValue }
  var symbol: String {
    switch self {
    case .everyone: return "person.3"
    case .managersOnly: return "person.2.badge.gearshape"
    case .adminOnly: return "lock.shield"
    case .uploaderOnly: return "person.crop.circle.badge.checkmark"
    }
  }
}

enum FileApproval: String, Codable, CaseIterable, Identifiable {
  case approved = "Approved"
  case awaiting = "Awaiting review"
  case rejected = "Rejected"
  var id: String { rawValue }
  var color: Color {
    switch self {
    case .approved: return Brand.paidGreen
    case .awaiting: return Brand.amber
    case .rejected: return Brand.red
    }
  }
  var symbol: String {
    switch self {
    case .approved: return "checkmark.seal.fill"
    case .awaiting: return "clock.badge"
    case .rejected: return "xmark.seal.fill"
    }
  }
}

// MARK: - Site file

/// A document or Google Drive link stored in a site's Files Hub.
struct SiteFile: Identifiable, Hashable {
  let id: UUID
  var siteId: UUID
  var title: String
  var category: FileCategory
  var origin: FileOrigin
  var fileType: String  // e.g. "PDF", "JPG", "XLSX", "Drive link"
  var uploadedById: UUID
  var uploadedByName: String
  var uploadedAt: Date

  // Optional relations
  var tradesmanId: UUID? = nil
  var allocationId: UUID? = nil
  var dailyRecordId: UUID? = nil
  var submissionId: UUID? = nil
  var materialId: UUID? = nil
  var variationId: UUID? = nil

  var notes: String = ""
  var driveURL: String = ""  // Google Drive link or internal file URL
  var driveFolderPath: String = ""
  var visibility: FileVisibility = .everyone
  var approval: FileApproval = .awaiting
  var tags: [String] = []
  var inHandoverPack: Bool = false

  var isImage: Bool {
    ["JPG", "JPEG", "PNG", "HEIC"].contains(fileType.uppercased())
  }
}

/// A row in the modelled "Site Files Register" Google Sheet tab.
struct SiteFileRegisterRow: Identifiable {
  var id: UUID
  var fileId: String
  var siteId: String
  var siteName: String
  var title: String
  var category: String
  var fileType: String
  var uploadedBy: String
  var uploadedDate: Date
  var relatedTradesman: String
  var relatedAllocation: String
  var relatedDailyRecord: String
  var relatedSubmission: String
  var relatedMaterial: String
  var relatedVariation: String
  var driveLink: String
  var notes: String
  var visibility: String
  var approval: String
  var tags: String
}
