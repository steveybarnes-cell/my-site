import Foundation

// MARK: - Roles & enums

enum UserRole: String, Codable, CaseIterable, Identifiable {
    case admin = "Admin"
    case siteManager = "Site Manager"
    case tradesman = "Tradesman"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .admin: return "shield.lefthalf.filled"
        case .siteManager: return "hard.hat"
        case .tradesman: return "hammer.fill"
        }
    }
}

enum WorkCategory: String, Codable, CaseIterable, Identifiable {
    case contract = "Contract Work"
    case variation = "Variation"
    case snagging = "Snagging"
    case callOut = "Call Out"
    case remedial = "Remedial"
    var id: String { rawValue }
}

enum Priority: String, Codable, CaseIterable, Identifiable {
    case low = "Low", normal = "Normal", high = "High", urgent = "Urgent"
    var id: String { rawValue }
}

enum AllocationStatus: String, Codable, CaseIterable, Identifiable {
    case allocated = "Allocated"
    case accepted = "Accepted"
    case started = "Started"
    case inProgress = "In Progress"
    case completed = "Completed"
    case queried = "Queried"
    case cancelled = "Cancelled"
    var id: String { rawValue }
}

enum SiteStatus: String, Codable, CaseIterable, Identifiable {
    case active = "Active", paused = "Paused", completed = "Completed"
    var id: String { rawValue }
}

enum DelayReason: String, Codable, CaseIterable, Identifiable {
    case none = "No delay"
    case weather = "Weather"
    case materials = "Waiting for materials"
    case client = "Waiting for client"
    case drawings = "Waiting for drawings"
    case otherTrade = "Waiting for another trade"
    case access = "Access issue"
    case parking = "Parking issue"
    case plant = "Plant/equipment issue"
    case design = "Design change"
    case other = "Other"
    var id: String { rawValue }
}

enum Chargeable: String, Codable, CaseIterable, Identifiable {
    case yes = "Yes", no = "No", tbc = "To be confirmed"
    var id: String { rawValue }
}

enum PhotoType: String, Codable, CaseIterable, Identifiable {
    case before = "Before works"
    case during = "During works"
    case completed = "Completed works"
    case variation = "Variation evidence"
    case snagging = "Snagging evidence"
    case delay = "Delay evidence"
    case damage = "Damage/issue evidence"
    case materials = "Materials"
    case receipt = "Receipt/supplier invoice"
    case other = "Other"
    var id: String { rawValue }
}

enum SubmissionStatus: String, Codable, CaseIterable, Identifiable {
    case draft = "Draft"
    case submitted = "Submitted"
    case queryRaised = "Query Raised"
    case awaitingSM = "Awaiting Site Manager Approval"
    case approvedSM = "Approved by Site Manager"
    case approvedPayment = "Approved for Payment"
    case rejected = "Rejected"
    case onHold = "On Hold"
    case paid = "Paid"
    var id: String { rawValue }
}

enum VariationStatus: String, Codable, CaseIterable, Identifiable {
    case draft = "Draft"
    case submitted = "Submitted"
    case awaiting = "Awaiting Approval"
    case approved = "Approved"
    case rejected = "Rejected"
    case chargeable = "Chargeable"
    case nonChargeable = "Non-chargeable"
    case tbc = "To be confirmed"
    var id: String { rawValue }
}

// MARK: - Core models

struct AppUser: Identifiable, Hashable {
    let id: UUID
    var name: String
    var email: String
    var role: UserRole
    var phone: String
    var active: Bool
}

struct TradesmanProfile: Identifiable, Hashable {
    let id: UUID
    var userId: UUID
    var company: String
    var address: String
    var utr: String
    var niNumber: String
    var cisStatus: String
    var mainTrade: String
    var vehicleReg: String
    var bankName: String
    var sortCode: String
    var accountNumber: String
    var hourlyRate: Double
    var dayRate: Double
    var vatRegistered: Bool
    var vatNumber: String
    var notes: String
    var bankChangePending: Bool
}

struct Site: Identifiable, Hashable {
    let id: UUID
    var name: String
    var address: String
    var client: String
    var siteManagerId: UUID?
    var status: SiteStatus
    var notes: String
    var whatsappLink: String
    var defaultStart: String
    var defaultFinish: String
}

struct WorkAllocation: Identifiable, Hashable {
    let id: UUID
    var siteId: UUID
    var tradesmanId: UUID
    var siteManagerId: UUID?
    var date: Date
    var startTime: String
    var expectedFinish: String
    var trade: String
    var taskDescription: String
    var category: WorkCategory
    var priority: Priority
    var requiredPhotos: Bool
    var requiredMaterials: String
    var notes: String
    var status: AllocationStatus
}

struct DailyRecord: Identifiable, Hashable {
    let id: UUID
    var allocationId: UUID?
    var userId: UUID
    var siteId: UUID
    var date: Date
    var startTime: String
    var finishTime: String
    var breakMinutes: Int
    var totalHours: Double
    var trade: String
    var description: String
    var category: WorkCategory
    var delayReason: DelayReason
    var delayNote: String
    var notes: String
    // Variation extras
    var variationInstructedBy: String
    var variationStatus: VariationStatus?
}

struct MaterialItem: Identifiable, Hashable {
    let id: UUID
    var userId: UUID
    var siteId: UUID
    var dailyRecordId: UUID?
    var date: Date
    var supplier: String
    var description: String
    var reason: String
    var costExVat: Double
    var vatAmount: Double
    var receiptUploaded: Bool
    var chargeable: Chargeable
    var approved: Bool
    var notes: String
    var total: Double { costExVat + vatAmount }
}

struct SitePhoto: Identifiable, Hashable {
    let id: UUID
    var userId: UUID
    var siteId: UUID
    var allocationId: UUID?
    var type: PhotoType
    var description: String
    var symbol: String   // SF Symbol stand-in for a real image
    var timestamp: Date
}

struct WeeklySubmission: Identifiable, Hashable {
    let id: UUID
    var userId: UUID
    var weekEnding: Date
    var invoiceNumber: String
    var totalHours: Double
    var labourRate: Double
    var materialsTotal: Double
    var plantMileage: Double
    var cisRate: Double        // e.g. 0.20
    var vatRegistered: Bool
    var status: SubmissionStatus
    var submittedAt: Date?
    var approvedBy: String?
    var paidDate: Date?

    var labourTotal: Double { totalHours * labourRate }
    var gross: Double { labourTotal + materialsTotal + plantMileage }
    var cisDeduction: Double { labourTotal * cisRate }
    var vat: Double { vatRegistered ? (labourTotal + plantMileage) * 0.20 : 0 }
    var netDue: Double { gross - cisDeduction + vat }
}

struct QueryComment: Identifiable, Hashable {
    let id: UUID
    var submissionId: UUID
    var fromName: String
    var toUserId: UUID
    var message: String
    var timestamp: Date
    var fromAdmin: Bool
}

struct AppNotification: Identifiable, Hashable {
    let id: UUID
    var userId: UUID
    var type: String
    var message: String
    var read: Bool
    var timestamp: Date
    var symbol: String
}
