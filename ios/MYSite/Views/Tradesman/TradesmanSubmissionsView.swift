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
              if store.isOffline || store.pendingSyncCount > 0 { syncBanner }
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

  /// Offline is not an error: work carries on and uploads itself the moment
  /// there is signal. This just says so, so nobody retypes a day.
  private var syncBanner: some View {
    let n = store.pendingSyncCount
    let message: String
    if store.isOffline {
      message =
        n > 0
        ? "No signal \u{2014} \(n) change\(n == 1 ? "" : "s") saved on this phone and will upload as soon as you're back online."
        : "No signal \u{2014} keep going. Everything saves on this phone and uploads as soon as you're back online."
    } else {
      message = "\(n) change\(n == 1 ? "" : "s") uploading now\u{2026}"
    }
    return WarningBanner(
      message: message,
      symbol: store.isOffline ? "wifi.slash" : "arrow.triangle.2.circlepath",
      tint: store.isOffline ? Brand.amber : Brand.blue)
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

  @State private var editingLine: WorkLogEntry?
  @State private var photoTarget: WorkAllocation?

  private var live: WeeklySubmission {
    store.submissions.first { $0.id == submission.id } ?? submission
  }

  /// Job details can be corrected until the office has approved or paid.
  private var canAmend: Bool { store.canAmend(live) }

  private var days: [DailyRecord] {
    store.dayRecords(for: live.userId, weekEnding: live.weekEnding)
  }

  private var weekMaterials: [MaterialItem] {
    store.materials(for: live.userId, weekEnding: live.weekEnding)
      .sorted { $0.date < $1.date }
  }

  var body: some View {
    ZStack {
      MPGBackground()
      ScrollView {
        VStack(spacing: 16) {
          if store.isOffline || store.pendingSyncCount > 0 { offlineNote }
          breakdownCard
          workCard
          if !weekMaterials.isEmpty { materialsCard }
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
    .sheet(item: $editingLine) { entry in
      WorkLineSheet(existing: entry, site: store.site(entry.siteId), date: entry.date)
    }
    .sheet(item: $photoTarget) { allocation in
      PhotoCaptureView(allocation: allocation)
    }
  }

  private var offlineNote: some View {
    WarningBanner(
      message: store.isOffline
        ? "No signal \u{2014} changes save on this phone and upload as soon as you're back online."
        : "\(store.pendingSyncCount) change\(store.pendingSyncCount == 1 ? "" : "s") uploading now\u{2026}",
      symbol: store.isOffline ? "wifi.slash" : "arrow.triangle.2.circlepath",
      tint: store.isOffline ? Brand.amber : Brand.blue)
  }

  // MARK: - Totals

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
          value: "\u{2212}\(Fmt.gbp(live.cisDeduction))")
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

  // MARK: - Work, day by day

  /// Every task on the invoice, under the day it was done, with what it is
  /// worth. The clock and the site are shown but locked; the job details and
  /// photos are the tradesman's to correct, and the office hears about it.
  private var workCard: some View {
    VStack(alignment: .leading, spacing: 14) {
      SectionHeader(
        title: "Work on this invoice",
        subtitle: canAmend
          ? "Tap a job to correct what was done. Times and sites are locked."
          : "Approved \u{2014} locked.")

      if days.isEmpty {
        Text("No day sheets in this week yet.")
          .font(.subheadline).foregroundStyle(Brand.inkSoft)
      }

      ForEach(days) { day in
        dayBlock(day)
      }
    }
    .mpgCard()
  }

  private func dayBlock(_ day: DailyRecord) -> some View {
    let lines = store.workLog(for: live.userId, on: day.date)
    let clocks = store.clockRecords(for: live.userId, on: day.date)
    let dayPhotos = store.photos(for: live.userId, on: day.date)
    let dayValue = day.totalHours * live.labourRate

    return VStack(alignment: .leading, spacing: 10) {
      // Day header: locked facts.
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 3) {
          Text(day.date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
            .font(.subheadline.weight(.semibold)).foregroundStyle(Brand.ink)
          Label(store.site(day.siteId)?.name ?? "Site", systemImage: "mappin.and.ellipse")
            .font(.caption).foregroundStyle(Brand.inkSoft)
          if let first = clocks.first {
            Label(
              "Clocked \(Fmt.time(first.clockInTime))"
                + (clocks.compactMap(\.clockOutTime).last.map { " \u{2013} \(Fmt.time($0))" } ?? " (still on)"),
              systemImage: "lock.fill"
            )
            .font(.caption).foregroundStyle(Brand.inkSoft)
          } else if !day.startTime.isEmpty {
            Label("\(day.startTime) \u{2013} \(day.finishTime)", systemImage: "lock.fill")
              .font(.caption).foregroundStyle(Brand.inkSoft)
          }
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 3) {
          Text(Fmt.hours(day.totalHours))
            .font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(Brand.oliveDark)
          Text(Fmt.gbp(dayValue))
            .font(.caption).monospacedDigit().foregroundStyle(Brand.inkSoft)
        }
      }

      // Tasks.
      if lines.isEmpty {
        Text(day.description)
          .font(.footnote).foregroundStyle(Brand.ink)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(10)
          .background(Brand.lightGreen, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
      } else {
        VStack(spacing: 6) {
          ForEach(lines) { line in
            taskRow(line)
          }
        }
      }

      // Photos for the day.
      HStack(spacing: 8) {
        if dayPhotos.isEmpty {
          Label("No photos", systemImage: "photo")
            .font(.caption).foregroundStyle(Brand.inkSoft)
        } else {
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
              ForEach(dayPhotos) { p in photoThumb(p) }
            }
          }
        }
        Spacer(minLength: 0)
        if canAmend,
          let target = store.allocationForPhotos(
            userId: live.userId, on: day.date, preferring: lines.first?.allocationId)
        {
          Button { photoTarget = target } label: {
            Label("Add photo", systemImage: "camera.fill")
              .font(.caption.weight(.semibold))
              .padding(.horizontal, 10).padding(.vertical, 7)
              .background(Brand.lightGreen, in: Capsule())
              .foregroundStyle(Brand.oliveDark)
          }
          .buttonStyle(.plain)
        }
      }
    }
    .padding(12)
    .background(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .stroke(Brand.hairline, lineWidth: 1))
  }

  private func taskRow(_ line: WorkLogEntry) -> some View {
    let value = line.hours * live.labourRate
    return Button {
      if canAmend { editingLine = line }
    } label: {
      HStack(alignment: .top, spacing: 10) {
        VStack(alignment: .leading, spacing: 3) {
          Text(line.description)
            .font(.footnote.weight(.medium)).foregroundStyle(Brand.ink)
            .multilineTextAlignment(.leading)
          Text("\(line.category.rawValue) \u{00B7} \(line.durationLabel)")
            .font(.caption2).foregroundStyle(Brand.inkSoft)
        }
        Spacer()
        Text(Fmt.gbp(value))
          .font(.footnote.weight(.semibold)).monospacedDigit().foregroundStyle(Brand.ink)
        if canAmend {
          Image(systemName: "pencil.circle")
            .font(.footnote).foregroundStyle(Brand.olive)
        }
      }
      .padding(10)
      .background(Brand.lightGreen, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    .buttonStyle(.plain)
    .disabled(!canAmend)
  }

  private func photoThumb(_ p: SitePhoto) -> some View {
    Group {
      if let url = URL(string: p.driveURL), p.driveURL.hasPrefix("http") {
        AsyncImage(url: url) { phase in
          if let image = phase.image {
            image.resizable().scaledToFill()
          } else {
            Image(systemName: p.symbol).foregroundStyle(Brand.olive)
          }
        }
      } else {
        Image(systemName: p.symbol).foregroundStyle(Brand.olive)
      }
    }
    .frame(width: 44, height: 44)
    .background(Brand.lightGreen)
    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
  }

  // MARK: - Materials

  private var materialsCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(
        title: "Materials",
        subtitle: "Chargeable items are added to the invoice. Correct a receipt from Today \u{2192} Evidence.")
      VStack(spacing: 0) {
        ForEach(weekMaterials) { m in
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
              Text(m.description.isEmpty ? m.supplier : m.description)
                .font(.subheadline.weight(.medium)).foregroundStyle(Brand.ink)
              Text("\(m.supplier.isEmpty ? "" : m.supplier + " \u{00B7} ")\(Fmt.date(m.date))")
                .font(.caption).foregroundStyle(Brand.inkSoft)
              HStack(spacing: 6) {
                StatusChip(
                  text: m.chargeable == .yes ? "Chargeable" : (m.chargeable == .no ? "Not charged" : "Chargeable TBC"),
                  color: m.chargeable == .no ? Brand.inkSoft : Brand.olive)
                if m.receiptUploaded {
                  Label("Receipt", systemImage: "doc.text").font(.caption2).foregroundStyle(Brand.inkSoft)
                }
              }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
              Text(Fmt.gbp(m.costExVat)).font(.subheadline.weight(.semibold)).monospacedDigit()
                .foregroundStyle(m.chargeable == .no ? Brand.inkSoft : Brand.ink)
              if m.vatAmount > 0 {
                Text("+ VAT \(Fmt.gbp(m.vatAmount))").font(.caption2).foregroundStyle(Brand.inkSoft)
              }
            }
          }
          .padding(.vertical, 9)
          if m.id != weekMaterials.last?.id { Divider().overlay(Brand.hairline) }
        }
      }
    }
    .mpgCard()
  }

  // MARK: - Queries and edits

  private func queriesCard(_ queries: [QueryComment]) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Queries & edits")
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
