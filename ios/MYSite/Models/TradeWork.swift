import Foundation

/// A unified work-timeline row used by the admin "Work by trade" feed.
struct TradeWorkItem: Identifiable, Hashable {
  enum Kind: String {
    case record = "Daily record"
    case allocation = "Allocation"
    case photo = "Photo"

    var symbol: String {
      switch self {
      case .record: return "list.clipboard.fill"
      case .allocation: return "calendar.badge.clock"
      case .photo: return "photo.fill"
      }
    }
  }

  let id: UUID
  var date: Date
  var kind: Kind
  var userName: String
  var siteName: String
  var title: String
  var subtitle: String
}
