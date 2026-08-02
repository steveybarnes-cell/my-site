import SwiftUI

/// Central company dashboard — the in-app mirror of the Google Sheets report.
/// Visible to Admin (all sites) and Site Managers (assigned sites only).
struct DashboardView: View {
  @Environment(AppStore.self) private var store
  @State private var filter = DashboardFilter()
  @State private var showFilters = false
  @State private var exportURL: URL?

  private var analytics: DashboardAnalytics {
    DashboardAnalytics(store: store, filter: filter)
  }

  var body: some View {
    Group {
      NavigationStack {
        ZStack {
          MPGBackground()
          ScrollView {
            VStack(spacing: 20) {
              if filter.isActive { activeFilterBar }
              if store.pendingSyncCount > 0 { pendingSyncBanner }
              ScanReceiptCard()
              weekSummarySection
              DashboardCharts(analytics: analytics)
              siteCostSection
              tradesmanSection
              allocationTrackerSection
              missingEvidenceSection
              siteFilesSection
              paymentRunSection
              pcAccessSection
              sourceNote
            }
            .padding(16)
          }
        }
        .navigationTitle("Company Dashboard")
        .toolbar {
          ToolbarItem(placement: .primaryAction) {
            Button {
              showFilters = true
            } label: {
              Image(
                systemName: filter.isActive
                  ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
            }
          }
          ToolbarItem(placement: .topBarLeading) {
            if let url = exportURL {
              ShareLink(item: url) {
                Image(systemName: "square.and.arrow.up")
              }
            } else {
              Button {
                exportURL = PDFExportService.exportDashboardReport(
                  analytics: analytics, filter: filter)
              } label: {
                Image(systemName: "arrow.down.doc")
              }
            }
          }
        }
        .sheet(isPresented: $showFilters) {
          DashboardFilterSheet(filter: $filter, analytics: analytics)
        }
      }
    }
    .__tenxTrackView("DashboardView")
  }

  // MARK: - Active filter bar

  private var activeFilterBar: some View {
    HStack {
      Image(systemName: "line.3.horizontal.decrease.circle.fill").foregroundStyle(Brand.olive)
      Text("Filters applied").font(.footnote.weight(.semibold)).foregroundStyle(Brand.ink)
      Spacer()
      Button("Clear") { filter = DashboardFilter() }
        .font(.footnote.weight(.semibold)).foregroundStyle(Brand.red)
    }
    .padding(12)
    .background(
      Brand.surface, in: RoundedRectangle(cornerRadius: Brand.Radius.inner, style: .continuous)
    )
    .overlay(
      RoundedRectangle(cornerRadius: Brand.Radius.inner, style: .continuous)
        .stroke(Brand.hairline, lineWidth: 1)
    )
    .shadow(color: Brand.cardShadow, radius: 8, x: 0, y: 3)
  }

  // MARK: - Pending sync banner

  private var pendingSyncBanner: some View {
    HStack(spacing: 10) {
      Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
        .foregroundStyle(Brand.amber)
      VStack(alignment: .leading, spacing: 2) {
        Text(
          "\(store.pendingSyncCount) change\(store.pendingSyncCount == 1 ? "" : "s") waiting to sync"
        )
        .font(.footnote.weight(.semibold)).foregroundStyle(Brand.ink)
        Text("These will upload to the company database when back online.")
          .font(.caption2).foregroundStyle(Brand.inkSoft)
      }
      Spacer(minLength: 0)
    }
    .padding(12)
    .background(
      Brand.amber.opacity(0.12),
      in: RoundedRectangle(cornerRadius: Brand.Radius.inner, style: .continuous)
    )
    .overlay(
      RoundedRectangle(cornerRadius: Brand.Radius.inner, style: .continuous)
        .stroke(Brand.amber.opacity(0.35), lineWidth: 1))
  }

  // MARK: - 1. This week summary

  private var weekSummarySection: some View {
    let s = analytics.weekSummary
    return VStack(alignment: .leading, spacing: 12) {
      SectionHeader(
        title: "This Week Summary",
        subtitle: filter.weekEnding.map { "Week ending \(Fmt.fullDate($0))" } ?? "All weeks")
      LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
        MetricTile(value: Fmt.hours(s.totalHours), label: "Total hours", symbol: "hourglass")
        MetricTile(
          value: Fmt.gbp(s.labourValue), label: "Labour value", symbol: "hammer.fill",
          tint: Brand.blue)
        MetricTile(
          value: Fmt.gbp(s.materialsValue), label: "Materials value", symbol: "shippingbox.fill",
          tint: Brand.amber)
        MetricTile(
          value: Fmt.gbp(s.cisDeduction), label: "CIS deduction", symbol: "percent",
          tint: Brand.red)
      }
      MetricTile(
        value: Fmt.gbp(s.netDue), label: "Net amount due", symbol: "sterlingsign.circle.fill",
        tint: Brand.olive)
      HStack(spacing: 10) {
        countPill("\(s.invoicesSubmitted)", "Submitted", Brand.blue)
        countPill("\(s.pendingApproval)", "Pending", Brand.amber)
        countPill("\(s.approved)", "Approved", Brand.olive)
      }
      HStack(spacing: 10) {
        countPill("\(s.paid)", "Paid", Brand.paidGreen)
        countPill("\(s.queried)", "Queried", Brand.red)
        Spacer().frame(maxWidth: .infinity)
      }
    }
    .mpgCard()
  }

  private func countPill(_ value: String, _ label: String, _ color: Color) -> some View {
    VStack(spacing: 2) {
      Text(value).font(.title3.bold()).monospacedDigit().foregroundStyle(color)
      Text(label).font(.caption2).foregroundStyle(Brand.inkSoft)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 10)
    .background(
      color.opacity(0.10), in: RoundedRectangle(cornerRadius: Brand.Radius.chip, style: .continuous)
    )
    .overlay(
      RoundedRectangle(cornerRadius: Brand.Radius.chip, style: .continuous)
        .stroke(color.opacity(0.18), lineWidth: 1)
    )
  }

  // MARK: - 2. Site cost summary

  private var siteCostSection: some View {
    let rows = analytics.siteCosts
    return VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Site Cost Summary")
      if rows.isEmpty {
        Text("No site costs for this selection.").font(.footnote).foregroundStyle(Brand.inkSoft)
      } else {
        ForEach(rows) { r in
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              Text(r.siteName).font(.subheadline.weight(.semibold)).foregroundStyle(Brand.ink)
              Spacer(minLength: 10)
              Text(Fmt.gbp(r.total)).font(.subheadline.bold()).monospacedDigit()
                .foregroundStyle(Brand.olive)
            }
            InfoRow(label: "Labour", value: Fmt.gbp(r.labour), symbol: "hammer")
            InfoRow(label: "Materials", value: Fmt.gbp(r.materials), symbol: "shippingbox")
            InfoRow(
              label: "Variation", value: Fmt.gbp(r.variation), symbol: "arrow.triangle.branch")
            if r.missingReceipts > 0 {
              InfoRow(
                label: "Missing receipts", value: "\(r.missingReceipts)",
                symbol: "exclamationmark.triangle")
            }
          }
          .mpgFormSection(padding: 12)
        }
      }
    }
    .mpgCard()
  }

  // MARK: - 3. Tradesman summary

  private var tradesmanSection: some View {
    let rows = analytics.tradesmanRows
    return VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Tradesman Summary")
      if rows.isEmpty {
        Text("No tradesman activity for this selection.").font(.footnote).foregroundStyle(
          Brand.inkSoft)
      } else {
        ForEach(rows) { r in
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              Text(r.name).font(.subheadline.weight(.semibold)).foregroundStyle(Brand.ink)
              Spacer(minLength: 10)
              Text(Fmt.gbp(r.invoiceValue)).font(.subheadline.bold()).monospacedDigit()
                .foregroundStyle(Brand.olive)
            }
            HStack(spacing: 8) {
              tag(Fmt.hours(r.hours), "clock", Brand.blue)
              if r.missingReceipts > 0 { tag("\(r.missingReceipts) rcpt", "doc.text", Brand.red) }
              if r.lateSubmissions > 0 {
                tag("\(r.lateSubmissions) late", "clock.badge.exclamationmark", Brand.amber)
              }
              if r.queries > 0 { tag("\(r.queries) query", "questionmark.circle", Brand.red) }
            }
          }
          .mpgFormSection(padding: 12)
        }
      }
    }
    .mpgCard()
  }

  private func tag(_ text: String, _ symbol: String, _ color: Color) -> some View {
    Label(text, systemImage: symbol)
      .font(.caption2.weight(.semibold))
      .foregroundStyle(color)
      .padding(.horizontal, 8).padding(.vertical, 4)
      .background(color.opacity(0.12), in: Capsule())
  }

  // MARK: - 4. Work allocation tracker

  private var allocationTrackerSection: some View {
    let t = analytics.allocationTracker
    return VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Work Allocation Tracker")
      LazyVGrid(
        columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10
      ) {
        trackerCell("\(t.allocated)", "Allocated", Brand.blue)
        trackerCell("\(t.accepted)", "Accepted", Brand.olive)
        trackerCell("\(t.started)", "Started", Brand.amber)
        trackerCell("\(t.completed)", "Completed", Brand.paidGreen)
        trackerCell("\(t.notSubmitted)", "Not submitted", Brand.red)
        trackerCell("\(t.cancelled)", "Cancelled", Brand.inkSoft)
      }
    }
    .mpgCard()
  }

  private func trackerCell(_ value: String, _ label: String, _ color: Color) -> some View {
    VStack(spacing: 4) {
      Text(value).font(.title3.bold()).monospacedDigit().foregroundStyle(color)
      Text(label).font(.caption2).foregroundStyle(Brand.inkSoft).multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 12)
    .background(
      color.opacity(0.10), in: RoundedRectangle(cornerRadius: Brand.Radius.chip, style: .continuous)
    )
    .overlay(
      RoundedRectangle(cornerRadius: Brand.Radius.chip, style: .continuous)
        .stroke(color.opacity(0.18), lineWidth: 1)
    )
  }

  // MARK: - 5. Missing evidence

  private var missingEvidenceSection: some View {
    let m = analytics.missingEvidence
    let clear =
      m.materialsNoReceipt.isEmpty && m.variationNoPhotos.isEmpty
      && m.delaysNoEvidence.isEmpty && m.recordsUnapproved.isEmpty
    return VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Missing Evidence")
      if clear {
        Label("All evidence accounted for.", systemImage: "checkmark.seal.fill")
          .font(.footnote.weight(.medium)).foregroundStyle(Brand.paidGreen)
      } else {
        evidenceRow(
          "Materials without receipts", m.materialsNoReceipt.count, "doc.text.magnifyingglass")
        evidenceRow(
          "Variation work without photos", m.variationNoPhotos.count, "photo.badge.exclamationmark")
        evidenceRow(
          "Delays without notes/photos", m.delaysNoEvidence.count, "clock.badge.exclamationmark")
        evidenceRow(
          "Records awaiting SM approval", m.recordsUnapproved.count, "checkmark.circle.badge.xmark")
      }
    }
    .mpgCard()
  }

  private func evidenceRow(_ label: String, _ count: Int, _ symbol: String) -> some View {
    HStack(spacing: 10) {
      Image(systemName: symbol).foregroundStyle(count > 0 ? Brand.red : Brand.inkSoft)
        .frame(width: 22)
      Text(label).font(.subheadline).foregroundStyle(Brand.ink)
      Spacer()
      Text("\(count)")
        .font(.subheadline.bold())
        .monospacedDigit()
        .foregroundStyle(count > 0 ? Brand.red : Brand.paidGreen)
        .padding(.horizontal, 10).padding(.vertical, 3)
        .background(
          (count > 0 ? Brand.red : Brand.paidGreen).opacity(0.12), in: Capsule())
    }
    .padding(.vertical, 4)
  }

  // MARK: - 6. Payment run

  private var paymentRunSection: some View {
    let rows = analytics.paymentRun
    return VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Payment Run")
      if rows.isEmpty {
        Text("No invoices for this selection.").font(.footnote).foregroundStyle(Brand.inkSoft)
      } else {
        ForEach(rows) { r in
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              VStack(alignment: .leading, spacing: 1) {
                Text(r.contractor).font(.subheadline.weight(.semibold)).foregroundStyle(Brand.ink)
                Text(r.invoiceNumber).font(.caption2).foregroundStyle(Brand.inkSoft)
              }
              Spacer()
              StatusChip(
                text: r.paymentStatus,
                color: r.paymentStatus == "Paid" ? Brand.paidGreen : Brand.amber, filled: true)
            }
            InfoRow(label: "Week ending", value: Fmt.date(r.weekEnding))
            InfoRow(label: "Gross total", value: Fmt.gbp(r.gross))
            InfoRow(label: "CIS deduction", value: "−\(Fmt.gbp(r.cis))")
            InfoRow(label: "Net due", value: Fmt.gbp(r.netDue))
            InfoRow(label: "Approval", value: r.approvalStatus)
            if let d = r.paymentDate {
              InfoRow(label: "Paid on", value: Fmt.date(d), symbol: "checkmark.seal")
            }
          }
          .mpgFormSection(padding: 12)
        }
      }
    }
    .mpgCard()
  }

  // MARK: - Site files health

  private var siteFilesSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Site Files Hub")
      LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
        MetricTile(
          value: "\(store.filesThisWeek)", label: "Files this week", symbol: "folder.badge.plus")
        MetricTile(
          value: "\(store.filesAwaitingApproval().count)", label: "Awaiting approval",
          symbol: "clock.badge", tint: Brand.amber)
        MetricTile(
          value: "\(store.sitesMissingDrawings().count)", label: "Sites with no drawings",
          symbol: "ruler", tint: Brand.red)
        MetricTile(
          value: "\(store.sitesMissingHealthSafety().count)", label: "Sites missing H&S",
          symbol: "cross.case", tint: Brand.red)
      }
      fileHealthRow(
        "Variation work without photos", store.variationsMissingPhotos().count,
        "photo.badge.exclamationmark")
      fileHealthRow(
        "Material claims without receipts", store.missingReceiptMaterials().count,
        "doc.text.magnifyingglass")

      if !store.recentSiteFiles().isEmpty {
        Divider().overlay(Brand.hairline)
        Text("RECENTLY UPLOADED").font(.caption2.weight(.bold)).foregroundStyle(Brand.olive)
          .tracking(0.8)
        ForEach(store.recentSiteFiles(5)) { f in
          HStack(spacing: 10) {
            Image(systemName: f.category.symbol).foregroundStyle(Brand.olive).frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
              Text(f.title).font(.caption.weight(.semibold)).foregroundStyle(Brand.ink).lineLimit(1)
              Text("\(store.site(f.siteId)?.name ?? "") · \(f.uploadedByName)")
                .font(.caption2).foregroundStyle(Brand.inkSoft).lineLimit(1)
            }
            Spacer()
            Image(systemName: f.approval.symbol).font(.caption2).foregroundStyle(f.approval.color)
          }
          .padding(.vertical, 3)
        }
      }
    }
    .mpgCard()
  }

  private func fileHealthRow(_ label: String, _ count: Int, _ symbol: String) -> some View {
    HStack(spacing: 10) {
      Image(systemName: symbol).foregroundStyle(count > 0 ? Brand.red : Brand.inkSoft)
        .frame(width: 22)
      Text(label).font(.subheadline).foregroundStyle(Brand.ink)
      Spacer()
      Text("\(count)")
        .font(.subheadline.bold())
        .monospacedDigit()
        .foregroundStyle(count > 0 ? Brand.red : Brand.paidGreen)
        .padding(.horizontal, 10).padding(.vertical, 3)
        .background((count > 0 ? Brand.red : Brand.paidGreen).opacity(0.12), in: Capsule())
    }
    .padding(.vertical, 4)
  }

  private var pcAccessSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(
        title: "PC / Web Access",
        subtitle: "Open the live company report from any computer")
      VStack(alignment: .leading, spacing: 10) {
        Label {
          Text("Everything logged in the app syncs to your shared company database.")
            .font(.footnote).foregroundStyle(Brand.ink)
        } icon: {
          Image(systemName: "externaldrive.connected.to.line.below").foregroundStyle(Brand.olive)
        }
        Divider().overlay(Brand.hairline)
        pcStep(1, "On a PC browser, go to supabase.com and sign in.")
        pcStep(2, "Open the My Project Group project, then choose Table Editor.")
        pcStep(3, "Open any report view to read the live data:")
        VStack(alignment: .leading, spacing: 4) {
          reportName("report_work_allocations", "Work Allocations")
          reportName("report_daily_records", "Daily Records")
          reportName("report_materials", "Materials & Receipts")
          reportName("report_photos_files", "Photos & Files")
          reportName("report_payment_run", "Payment Run")
          reportName("report_site_cost_summary", "Site Cost Summary")
          reportName("report_attendance", "Attendance (clock in/out)")
        }
        .padding(.leading, 26)
      }
    }
    .mpgCard()
  }

  private func pcStep(_ n: Int, _ text: String) -> some View {
    HStack(alignment: .top, spacing: 10) {
      Text("\(n)")
        .font(.caption.weight(.bold)).foregroundStyle(.white)
        .frame(width: 20, height: 20)
        .background(Brand.olive, in: Circle())
      Text(text).font(.footnote).foregroundStyle(Brand.ink)
      Spacer(minLength: 0)
    }
  }

  private func reportName(_ code: String, _ label: String) -> some View {
    HStack(spacing: 8) {
      Text(code)
        .font(.caption2.monospaced().weight(.semibold))
        .foregroundStyle(Brand.oliveDark)
      Text("— \(label)")
        .font(.caption2).foregroundStyle(Brand.inkSoft)
      Spacer(minLength: 0)
    }
  }

  private var sourceNote: some View {
    Text(
      "This dashboard mirrors the central Google Sheets report (Work Allocations, Daily Records, Materials, Photos & Files, Weekly Submissions, Variation & Delay Registers, Approval Tracker, Payment Run). Live Google Sheets sync requires the Drive/Sheets backend."
    )
    .font(.caption2)
    .foregroundStyle(Brand.inkSoft)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

// MARK: - Filter sheet

struct DashboardFilterSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Binding var filter: DashboardFilter
  let analytics: DashboardAnalytics

  var body: some View {
    NavigationStack {
      Form {
        Section("Week ending") {
          Picker("Week", selection: $filter.weekEnding) {
            Text("All weeks").tag(Date?.none)
            ForEach(analytics.availableWeekEndings, id: \.self) { d in
              Text(Fmt.fullDate(d)).tag(Date?.some(d))
            }
          }
        }
        Section("Site") {
          Picker("Site", selection: $filter.siteId) {
            Text("All sites").tag(UUID?.none)
            ForEach(analytics.visibleSites) { s in
              Text(s.name).tag(UUID?.some(s.id))
            }
          }
        }
        Section("Tradesman") {
          Picker("Tradesman", selection: $filter.tradesmanId) {
            Text("All tradesmen").tag(UUID?.none)
            ForEach(analytics.availableTradesmen) { t in
              Text(t.name).tag(UUID?.some(t.id))
            }
          }
        }
        Section("Trade") {
          Picker("Trade", selection: $filter.trade) {
            Text("All trades").tag(String?.none)
            ForEach(analytics.availableTrades, id: \.self) { t in
              Text(t).tag(String?.some(t))
            }
          }
        }
        Section("Invoice status") {
          Picker("Status", selection: $filter.submissionStatus) {
            Text("All statuses").tag(SubmissionStatus?.none)
            ForEach(SubmissionStatus.allCases) { s in
              Text(s.rawValue).tag(SubmissionStatus?.some(s))
            }
          }
        }
        Section("Work category") {
          Picker("Category", selection: $filter.workCategory) {
            Text("All categories").tag(WorkCategory?.none)
            ForEach(WorkCategory.allCases) { c in
              Text(c.rawValue).tag(WorkCategory?.some(c))
            }
          }
        }
        Section("Evidence") {
          Toggle("Missing receipts only", isOn: $filter.missingReceiptOnly)
          Toggle("Variation work only", isOn: $filter.variationOnly)
        }
        Section {
          Button("Clear all filters", role: .destructive) {
            filter = DashboardFilter()
          }
        }
      }
      .navigationTitle("Filter Dashboard")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
    }
  }
}

#Preview {
  DashboardView().environment(
    {
      let s = AppStore()
      s.login(as: s.users.first { $0.role == .admin }!)
      return s
    }())
}
