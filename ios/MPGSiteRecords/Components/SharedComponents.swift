import SwiftUI

// MARK: - Status chip

struct StatusChip: View {
  let text: String
  let color: Color
  var filled: Bool = false

  var body: some View {
    Text(text)
      .font(.caption.weight(.semibold))
      .lineLimit(1)
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .foregroundStyle(filled ? .white : color)
      .background(filled ? color : color.opacity(0.14), in: Capsule())
  }
}

extension AllocationStatus {
  var color: Color {
    switch self {
    case .allocated: return Brand.blue
    case .accepted: return Brand.olive
    case .started, .inProgress: return Brand.amber
    case .completed: return Brand.paidGreen
    case .queried: return Brand.red
    case .cancelled: return Brand.inkSoft
    }
  }
}

extension SubmissionStatus {
  var color: Color {
    switch self {
    case .draft: return Brand.inkSoft
    case .submitted, .awaitingSM: return Brand.blue
    case .queryRaised, .rejected: return Brand.red
    case .approvedSM, .approvedPayment: return Brand.olive
    case .onHold: return Brand.amber
    case .paid: return Brand.paidGreen
    }
  }
  var short: String {
    switch self {
    case .awaitingSM: return "Awaiting SM"
    case .approvedSM: return "SM Approved"
    case .approvedPayment: return "For Payment"
    default: return rawValue
    }
  }
}

extension Priority {
  var color: Color {
    switch self {
    case .low: return Brand.inkSoft
    case .normal: return Brand.blue
    case .high: return Brand.amber
    case .urgent: return Brand.red
    }
  }
}

// MARK: - Section header

struct SectionHeader: View {
  let title: String
  var subtitle: String? = nil
  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title.uppercased())
        .font(.caption.weight(.bold))
        .foregroundStyle(Brand.olive)
        .tracking(0.6)
      if let subtitle {
        Text(subtitle).font(.subheadline).foregroundStyle(Brand.inkSoft)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

// MARK: - Metric tile

struct MetricTile: View {
  let value: String
  let label: String
  var symbol: String
  var tint: Color = Brand.olive

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Image(systemName: symbol)
        .font(.title3)
        .foregroundStyle(tint)
      Text(value)
        .font(.title2.bold())
        .foregroundStyle(Brand.ink)
      Text(label)
        .font(.caption)
        .foregroundStyle(Brand.inkSoft)
        .lineLimit(2)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .mpgCard()
  }
}

// MARK: - Primary button

struct PrimaryButton: View {
  let title: String
  var symbol: String? = nil
  var tint: Color = Brand.olive
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 8) {
        if let symbol { Image(systemName: symbol) }
        Text(title).fontWeight(.semibold)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 15)
      .foregroundStyle(.white)
      .background(tint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Info row

struct InfoRow: View {
  let label: String
  let value: String
  var symbol: String? = nil

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      if let symbol {
        Image(systemName: symbol)
          .font(.footnote)
          .foregroundStyle(Brand.olive)
          .frame(width: 18)
      }
      Text(label)
        .font(.subheadline)
        .foregroundStyle(Brand.inkSoft)
      Spacer(minLength: 12)
      Text(value)
        .font(.subheadline.weight(.medium))
        .foregroundStyle(Brand.ink)
        .multilineTextAlignment(.trailing)
    }
  }
}

// MARK: - Empty state

struct EmptyStateView: View {
  let symbol: String
  let title: String
  let message: String
  var actionTitle: String? = nil
  var action: (() -> Void)? = nil

  var body: some View {
    VStack(spacing: 14) {
      Image(systemName: symbol)
        .font(.system(size: 44))
        .foregroundStyle(Brand.olive.opacity(0.7))
      Text(title).font(.headline).foregroundStyle(Brand.ink)
      Text(message)
        .font(.subheadline)
        .foregroundStyle(Brand.inkSoft)
        .multilineTextAlignment(.center)
      if let actionTitle, let action {
        Button(actionTitle, action: action)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(Brand.olive)
          .padding(.top, 2)
      }
    }
    .padding(28)
    .frame(maxWidth: .infinity)
  }
}

// MARK: - Warning banner

struct WarningBanner: View {
  let message: String
  var symbol: String = "exclamationmark.triangle.fill"
  var tint: Color = Brand.amber

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: symbol).foregroundStyle(tint)
      Text(message)
        .font(.footnote.weight(.medium))
        .foregroundStyle(Brand.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(12)
    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .stroke(tint.opacity(0.35), lineWidth: 1)
    )
  }
}

// MARK: - Formatters

enum Fmt {
  static func gbp(_ v: Double) -> String {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.currencyCode = "GBP"
    f.maximumFractionDigits = 2
    return f.string(from: NSNumber(value: v)) ?? "£\(v)"
  }
  static func date(_ d: Date, _ style: Date.FormatStyle.DateStyle = .abbreviated) -> String {
    d.formatted(.dateTime.day().month().weekday())
  }
  static func fullDate(_ d: Date) -> String {
    d.formatted(.dateTime.day().month(.wide).year())
  }
  static func hours(_ h: Double) -> String {
    h.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(h))h" : String(format: "%.2fh", h)
  }
  static func time(_ d: Date) -> String {
    d.formatted(.dateTime.hour().minute())
  }
  static func metres(_ m: Double) -> String {
    m < 0 ? "—" : "\(Int(m.rounded()))m"
  }
}

extension ClockStatus {
  var color: Color {
    switch self {
    case .valid: return Brand.paidGreen
    case .outsideSite: return Brand.red
    case .permissionDenied: return Brand.amber
    case .requiresApproval: return Brand.blue
    }
  }
}
