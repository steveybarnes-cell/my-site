import SwiftUI

struct TradesmanSubmissionsView: View {
  @Environment(AppStore.self) private var store
  private var me: AppUser? { store.currentUser }

  var body: some View {
    Group {
      NavigationStack {
        ZStack {
          MPGBackground()
          ScrollView {
            VStack(spacing: 16) {
              deadlineBanner
              let subs = me.map { store.submissions(for: $0.id) } ?? []
              if subs.isEmpty {
                EmptyStateView(
                  symbol: "sterlingsign.circle", title: "No invoices yet",
                  message: "Your weekly invoices and their payment status will appear here."
                ).mpgCard()
              } else {
                ForEach(subs) { sub in
                  NavigationLink(value: sub) {
                    SubmissionCard(submission: sub)
                  }
                  .buttonStyle(.plain)
                }
              }
            }
            .padding(16)
          }
        }
        .navigationTitle("My Invoices")
        .navigationDestination(for: WeeklySubmission.self) { SubmissionDetailView(submission: $0) }
      }
    }
    .__tenxTrackView("TradesmanSubmissionsView")
  }

  private var deadlineBanner: some View {
    WarningBanner(
      message:
        "Weekly invoices are due by Monday 13:00. Late submissions may delay payment to the following week.",
      symbol: "clock.badge.exclamationmark", tint: Brand.amber)
  }
}

struct SubmissionCard: View {
  @Environment(AppStore.self) private var store
  let submission: WeeklySubmission

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text(submission.invoiceNumber).font(.headline).foregroundStyle(Brand.ink)
        Spacer()
        StatusChip(text: submission.status.short, color: submission.status.color, filled: true)
      }
      Text("Week ending \(Fmt.date(submission.weekEnding))")
        .font(.caption).foregroundStyle(Brand.inkSoft)
      Divider().overlay(Brand.hairline)
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text("Net due").font(.caption).foregroundStyle(Brand.inkSoft)
          Text(Fmt.gbp(submission.netDue)).font(.title3.bold()).foregroundStyle(Brand.olive)
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 2) {
          Text(Fmt.hours(submission.totalHours)).font(.subheadline.weight(.medium)).foregroundStyle(
            Brand.ink)
          Text("CIS −\(Fmt.gbp(submission.cisDeduction))").font(.caption).foregroundStyle(Brand.red)
        }
      }
    }
    .mpgCard()
  }
}

struct SubmissionDetailView: View {
  @Environment(AppStore.self) private var store
  let submission: WeeklySubmission

  private var live: WeeklySubmission {
    store.submissions.first { $0.id == submission.id } ?? submission
  }

  var body: some View {
    ZStack {
      MPGBackground()
      ScrollView {
        VStack(spacing: 16) {
          breakdownCard
          let queries = store.comments(for: live.id)
          if !queries.isEmpty { queriesCard(queries) }
          if live.status == .draft {
            PrimaryButton(title: "Submit Invoice", symbol: "paperplane.fill") {
              store.setSubmissionStatus(live.id, to: .submitted)
            }
          }
        }
        .padding(16)
      }
    }
    .navigationTitle(live.invoiceNumber)
    .navigationBarTitleDisplayMode(.inline)
  }

  private var breakdownCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        StatusChip(text: live.status.rawValue, color: live.status.color, filled: true)
        Spacer()
        Text("W/E \(Fmt.date(live.weekEnding))").font(.caption).foregroundStyle(Brand.inkSoft)
      }
      SectionHeader(title: "Invoice breakdown")
      VStack(spacing: 10) {
        InfoRow(
          label: "Labour (\(Fmt.hours(live.totalHours)) @ \(Fmt.gbp(live.labourRate)))",
          value: Fmt.gbp(live.labourTotal))
        InfoRow(label: "Materials", value: Fmt.gbp(live.materialsTotal))
        InfoRow(label: "Plant / mileage", value: Fmt.gbp(live.plantMileage))
        Divider().overlay(Brand.hairline)
        InfoRow(label: "Gross", value: Fmt.gbp(live.gross))
        InfoRow(
          label: "CIS deduction (\(Int(live.cisRate * 100))%)",
          value: "−\(Fmt.gbp(live.cisDeduction))")
        if live.vatRegistered { InfoRow(label: "VAT (20%)", value: Fmt.gbp(live.vat)) }
        Divider().overlay(Brand.hairline)
        InfoRow(label: "Net due", value: Fmt.gbp(live.netDue))
      }
      if let by = live.approvedBy {
        InfoRow(label: "Approved by", value: by, symbol: "checkmark.seal")
      }
      if let paid = live.paidDate {
        InfoRow(label: "Paid", value: Fmt.fullDate(paid), symbol: "banknote")
      }
    }
    .mpgCard()
  }

  private func queriesCard(_ queries: [QueryComment]) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Queries")
      ForEach(queries) { q in
        VStack(alignment: .leading, spacing: 4) {
          HStack {
            Text(q.fromName).font(.caption.weight(.bold)).foregroundStyle(Brand.olive)
            Spacer()
            Text(Fmt.date(q.timestamp)).font(.caption2).foregroundStyle(Brand.inkSoft)
          }
          Text(q.message).font(.footnote).foregroundStyle(Brand.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .mpgFormSection(padding: 12)
      }
    }
    .mpgCard()
  }
}

#Preview {
  TradesmanSubmissionsView().environment(
    {
      let s = AppStore()
      s.login(as: s.tradesmen().first!)
      return s
    }())
}
