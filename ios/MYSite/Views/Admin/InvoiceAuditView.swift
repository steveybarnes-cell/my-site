import SwiftUI

// MARK: - Severity → Brand colour

extension AuditSeverity {
  var color: Color {
    switch self {
    case .pass: return Brand.paidGreen
    case .info: return Brand.blue
    case .warning: return Brand.amber
    case .critical: return Brand.red
    }
  }
}

// MARK: - Risk badge (compact, for the invoice row)

/// Small AI-audit chip shown on each invoice row. Tapping runs / re-opens the
/// full audit. Colour and number communicate risk at a glance.
struct AuditRiskBadge: View {
  let audit: InvoiceAudit

  var body: some View {
    HStack(spacing: 5) {
      Image(systemName: "sparkles")
        .font(.caption2.weight(.bold))
      Text("\(audit.riskScore)")
        .font(.caption.weight(.heavy))
        .monospacedDigit()
    }
    .foregroundStyle(audit.band == .pass ? Brand.paidGreen : audit.band.color)
    .padding(.horizontal, 9)
    .padding(.vertical, 5)
    .background(
      (audit.band == .pass ? Brand.paidGreen : audit.band.color).opacity(0.14),
      in: Capsule())
  }
}

// MARK: - Full audit sheet

struct InvoiceAuditView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  let submission: WeeklySubmission

  private var audit: InvoiceAudit {
    InvoiceAuditor.audit(submission, store: store)
  }

  var body: some View {
    NavigationStack {
      ZStack {
        MPGBackground()
        ScrollView {
          VStack(spacing: 18) {
            scoreCard
            findingsList
            disclaimer
          }
          .padding(16)
        }
      }
      .navigationTitle("AI Invoice Audit")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") { dismiss() }
        }
      }
    }
    .__tenxTrackView("InvoiceAuditView")
  }

  // MARK: Score header

  private var scoreCard: some View {
    let band = audit.band
    return VStack(spacing: 14) {
      HStack(spacing: 14) {
        ZStack {
          Circle()
            .stroke(band.color.opacity(0.18), lineWidth: 8)
          Circle()
            .trim(from: 0, to: CGFloat(audit.riskScore) / 100)
            .stroke(
              band.color,
              style: StrokeStyle(lineWidth: 8, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
          VStack(spacing: 0) {
            Text("\(audit.riskScore)")
              .font(.title.bold().monospacedDigit())
              .foregroundStyle(Brand.ink)
            Text("risk").font(.caption2).foregroundStyle(Brand.inkSoft)
          }
        }
        .frame(width: 84, height: 84)

        VStack(alignment: .leading, spacing: 6) {
          Label(band.label, systemImage: band.symbol)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(band.color)
          Text(audit.verdict)
            .font(.footnote)
            .foregroundStyle(Brand.inkSoft)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }

      Divider()

      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text(store.user(submission.userId)?.name ?? "Subcontractor")
            .font(.subheadline.weight(.semibold)).foregroundStyle(Brand.ink)
          Text("\(submission.invoiceNumber) • W/E \(Fmt.date(submission.weekEnding))")
            .font(.caption).foregroundStyle(Brand.inkSoft)
        }
        Spacer()
        Text(Fmt.gbp(submission.netDue))
          .font(.headline).foregroundStyle(Brand.olive)
      }
    }
    .mpgCard()
  }

  // MARK: Findings

  private var findingsList: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(
        title: "What the auditor checked",
        subtitle: "Cross-referenced against GPS attendance, receipts, photos & deadlines")
      ForEach(audit.findings) { finding in
        AuditFindingRow(finding: finding)
      }
    }
  }

  private var disclaimer: some View {
    Text(
      "The auditor compares this invoice against the tradesman's clock-ins, uploaded receipts and "
        + "site photos for the week. Flags are guidance to review — the final approval decision is yours."
    )
    .font(.caption2)
    .foregroundStyle(Brand.inkSoft)
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.top, 4)
  }
}

// MARK: - Single finding row

struct AuditFindingRow: View {
  let finding: AuditFinding

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: finding.severity.symbol)
        .font(.subheadline)
        .foregroundStyle(finding.severity.color)
        .frame(width: 26, height: 26)
        .background(finding.severity.color.opacity(0.14), in: Circle())
      VStack(alignment: .leading, spacing: 3) {
        Text(finding.title)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(Brand.ink)
        Text(finding.detail)
          .font(.footnote)
          .foregroundStyle(Brand.inkSoft)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .mpgCard(padding: 12)
  }
}

private struct InvoiceAuditPreview: View {
  @State private var store = AppStore()
  var body: some View {
    if let sub = store.submissions.first {
      InvoiceAuditView(submission: sub).environment(store)
    } else {
      Text("No submissions")
    }
  }
}

#Preview { InvoiceAuditPreview() }
