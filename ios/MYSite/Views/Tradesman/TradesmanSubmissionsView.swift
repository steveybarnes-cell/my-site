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
              thisWeekCard
              let subs = me.map { store.submissions(for: $0.id) } ?? []
              if subs.isEmpty {
                EmptyStateView(
                  symbol: "sterlingsign.circle", title: "No invoices yet",
                  message: "Finish your days on the Today screen and this week's invoice builds "
                    + "itself from them."
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

  // MARK: - This week

  /// Builds the week's invoice from the day sheets.
  ///
  /// This is the piece that was missing. `saveSubmission` existed and nothing
  /// in the app called it, so every invoice on screen came from seed data and
  /// a real subcontractor had no way to bill for a week he had worked. The
  /// hours here are the day sheets added up — nothing is retyped, which is the
  /// whole point: the figure the office queries is the figure the phone
  /// captured.
  @ViewBuilder private var thisWeekCard: some View {
    if let me {
      let week = store.weekEnding(for: Date())
      let days = store.dayRecords(for: me.id, weekEnding: week)
      let hours = days.reduce(0.0) { $0 + $1.totalHours }
      let existing = store.submissions(for: me.id).first {
        store.weekEnding(for: $0.weekEnding) == week
      }
      let locked = existing.map { $0.status != .draft } ?? false

      VStack(alignment: .leading, spacing: 12) {
        SectionHeader(
          title: "This week",
          subtitle: "Week ending \(Fmt.date(week))")

        if days.isEmpty {
          Text(
            "No days closed off yet. Finish a day on the Today screen and it lands here."
          )
          .font(.subheadline)
          .foregroundStyle(Brand.inkSoft)
          .frame(maxWidth: .infinity, alignment: .leading)
        } else {
          VStack(spacing: 0) {
            ForEach(days) { day in
              HStack {
                VStack(alignment: .leading, spacing: 2) {
                  Text(day.date.formatted(.dateTime.weekday(.wide)))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Brand.ink)
                  Text(store.site(day.siteId)?.name ?? "Site")
                    .font(.caption)
                    .foregroundStyle(Brand.inkSoft)
                }
                Spacer()
                Text(Fmt.hours(day.totalHours))
                  .font(.subheadline.weight(.semibold))
                  .monospacedDigit()
                  .foregroundStyle(Brand.oliveDark)
              }
              .padding(.vertical, 9)
              if day.id != days.last?.id { Divider().overlay(Brand.hairline) }
            }
          }
          HStack {
            Text("\(days.count) day\(days.count == 1 ? "" : "s")")
              .font(.footnote).foregroundStyle(Brand.inkSoft)
            Spacer()
            Text(Fmt.hours(hours))
              .font(.headline).monospacedDigit().foregroundStyle(Brand.ink)
          }

          if locked {
            Label(
              "Already with the office — \(existing?.status.rawValue ?? "")",
              systemImage: "lock.fill"
            )
            .font(.caption).foregroundStyle(Brand.inkSoft)
          } else {
            Button {
              store.buildWeeklyInvoice(for: me.id, weekEnding: week)
            } label: {
              Label(
                existing == nil ? "Build this week's invoice" : "Update the draft",
                systemImage: "sterlingsign.circle.fill"
              )
              .font(.headline)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 14)
              .background(Brand.olive, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
              .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
          }
        }
      }
      .mpgCard()
    }
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
