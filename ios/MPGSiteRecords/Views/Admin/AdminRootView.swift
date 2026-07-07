import SwiftUI

struct AdminRootView: View {
  @Environment(AppStore.self) private var store

  var body: some View {
    Group {
      TabView {
        Tab("Dashboard", systemImage: "square.grid.2x2.fill") {
          DashboardView()
        }
        Tab("Invoices", systemImage: "doc.text.fill") {
          AdminSubmissionsView()
        }
        Tab("Attendance", systemImage: "location.fill.viewfinder") {
          AttendanceView()
        }
        Tab("Files", systemImage: "folder.fill") {
          FilesView()
        }
        Tab("Alerts", systemImage: "bell.fill") {
          NotificationsView()
        }
        .badge(store.unreadCount)
        Tab("Profile", systemImage: "person.crop.circle.fill") {
          AdminProfileView()
        }
      }
    }
    .__tenxTrackView("AdminRootView")
  }
}

// MARK: - Dashboard

struct AdminDashboardView: View {
  @Environment(AppStore.self) private var store

  var body: some View {
    NavigationStack {
      ZStack {
        MPGBackground()
        ScrollView {
          VStack(spacing: 16) {
            metrics
            let missing = store.missingReceiptMaterials()
            if !missing.isEmpty {
              WarningBanner(
                message:
                  "\(missing.count) materials purchase(s) missing a receipt — review before payment.",
                symbol: "exclamationmark.triangle.fill", tint: Brand.red)
            }
            let late = store.lateSubmissions()
            if !late.isEmpty {
              WarningBanner(
                message: "\(late.count) invoice(s) submitted after the Monday 13:00 deadline.",
                symbol: "clock.badge.exclamationmark", tint: Brand.amber)
            }
            sitesSection
            variationSection
          }
          .padding(16)
        }
      }
      .navigationTitle("Office Dashboard")
    }
  }

  private var metrics: some View {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
      MetricTile(
        value:
          "\(store.submissions.filter { $0.status == .submitted || $0.status == .awaitingSM }.count)",
        label: "Invoices to review", symbol: "tray.full")
      MetricTile(
        value: "\(store.tradesmen().count)", label: "Active tradesmen", symbol: "person.2",
        tint: Brand.blue)
      MetricTile(
        value: "\(store.sites.filter { $0.status == .active }.count)", label: "Active sites",
        symbol: "mappin.and.ellipse", tint: Brand.amber)
      MetricTile(
        value: Fmt.gbp(
          store.submissions.filter { $0.status != .paid }.reduce(0) { $0 + $1.netDue }),
        label: "Outstanding", symbol: "sterlingsign.circle", tint: Brand.red)
    }
  }

  private var sitesSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Sites")
      ForEach(store.sites) { site in
        VStack(alignment: .leading, spacing: 6) {
          HStack {
            Text(site.name).font(.headline).foregroundStyle(Brand.ink)
            Spacer()
            StatusChip(
              text: site.status.rawValue,
              color: site.status == .active ? Brand.paidGreen : Brand.amber)
          }
          Text(site.address).font(.caption).foregroundStyle(Brand.inkSoft)
          if let sm = site.siteManagerId.flatMap(store.user) {
            Label(sm.name, systemImage: "hard.hat").font(.caption).foregroundStyle(Brand.inkSoft)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .mpgCard(padding: 12)
      }
    }
  }

  private var variationSection: some View {
    let variations = store.variationRecords()
    return Group {
      if !variations.isEmpty {
        VStack(alignment: .leading, spacing: 12) {
          SectionHeader(title: "Variation register")
          ForEach(variations) { v in
            VStack(alignment: .leading, spacing: 4) {
              HStack {
                Text(store.site(v.siteId)?.name ?? "Site").font(.subheadline.weight(.semibold))
                  .foregroundStyle(Brand.ink)
                Spacer()
                if let vs = v.variationStatus {
                  StatusChip(text: vs.rawValue, color: Brand.blue)
                }
              }
              Text(v.description).font(.footnote).foregroundStyle(Brand.inkSoft)
              if !v.variationInstructedBy.isEmpty {
                Text("Instructed by: \(v.variationInstructedBy)").font(.caption2).foregroundStyle(
                  Brand.inkSoft)
              }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .mpgFormSection(padding: 12)
          }
        }
        .mpgCard()
      }
    }
  }
}

// MARK: - Admin submissions (payment run)

struct AdminSubmissionsView: View {
  @Environment(AppStore.self) private var store

  var body: some View {
    NavigationStack {
      ZStack {
        MPGBackground()
        ScrollView {
          VStack(spacing: 12) {
            ForEach(store.submissions.sorted { $0.weekEnding > $1.weekEnding }) { sub in
              AdminSubmissionRow(submission: sub)
            }
          }
          .padding(16)
        }
      }
      .navigationTitle("Invoices")
    }
  }
}

struct AdminSubmissionRow: View {
  @Environment(AppStore.self) private var store
  let submission: WeeklySubmission

  private var live: WeeklySubmission {
    store.submissions.first { $0.id == submission.id } ?? submission
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text(store.user(live.userId)?.name ?? "").font(.headline).foregroundStyle(Brand.ink)
          Text(live.invoiceNumber).font(.caption).foregroundStyle(Brand.inkSoft)
        }
        Spacer()
        StatusChip(text: live.status.short, color: live.status.color, filled: true)
      }
      HStack {
        Text("Net \(Fmt.gbp(live.netDue))").font(.subheadline.weight(.semibold)).foregroundStyle(
          Brand.olive)
        Spacer()
        Text("W/E \(Fmt.date(live.weekEnding))").font(.caption).foregroundStyle(Brand.inkSoft)
      }
      if live.status == .submitted || live.status == .approvedSM {
        HStack(spacing: 10) {
          Button {
            if store.xeroConnected {
              Task { await store.pushSubmissionToXero(live.id) }
            } else {
              store.setSubmissionStatus(live.id, to: .approvedPayment, by: store.currentUser?.name)
            }
          } label: {
            HStack(spacing: 6) {
              if store.xeroWorking { ProgressView().tint(.white) }
              Text(store.xeroConnected ? "Approve & Send to Xero" : "Approve")
            }
          }
          .buttonStyle(.borderedProminent).tint(Brand.olive)
          .disabled(store.xeroWorking)
          Button("Query") {
            store.setSubmissionStatus(live.id, to: .queryRaised, by: store.currentUser?.name)
          }
          .buttonStyle(.bordered).tint(Brand.red)
        }
        .font(.subheadline)
      } else if live.status == .approvedPayment {
        if let number = store.xeroInvoiceNumbers[live.id] {
          Label("Xero \(number)", systemImage: "checkmark.seal.fill")
            .font(.caption.weight(.semibold)).foregroundStyle(Brand.paidGreen)
        }
        Button("Mark as Paid") {
          store.setSubmissionStatus(live.id, to: .paid, by: store.currentUser?.name)
        }
        .buttonStyle(.borderedProminent).tint(Brand.paidGreen)
      }
    }
    .mpgCard()
  }
}

struct AdminProfileView: View {
  @Environment(AppStore.self) private var store

  var body: some View {
    NavigationStack {
      ZStack {
        MPGBackground()
        ScrollView {
          VStack(spacing: 16) {
            VStack(spacing: 8) {
              Image(systemName: "shield.lefthalf.filled").font(.system(size: 40)).foregroundStyle(
                .white)
              Text(store.currentUser?.name ?? "").font(.title3.bold()).foregroundStyle(.white)
              Text("Office / Admin").font(.subheadline).foregroundStyle(.white.opacity(0.75))
            }
            .frame(maxWidth: .infinity).padding(22)
            .background(Brand.charcoal, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            xeroCard

            VStack(alignment: .leading, spacing: 12) {
              SectionHeader(title: "Team")
              ForEach(store.users.filter { $0.role != .admin }) { u in
                HStack(spacing: 12) {
                  Image(systemName: u.role.icon).foregroundStyle(Brand.olive)
                    .frame(width: 30, height: 30).background(Brand.lightGreen, in: Circle())
                  VStack(alignment: .leading, spacing: 1) {
                    Text(u.name).font(.subheadline.weight(.semibold)).foregroundStyle(Brand.ink)
                    Text(u.role.rawValue).font(.caption).foregroundStyle(Brand.inkSoft)
                  }
                  Spacer()
                }
              }
            }
            .mpgCard()

            PrimaryButton(
              title: "Log Out", symbol: "rectangle.portrait.and.arrow.right", tint: Brand.charcoal
            ) {
              store.logout()
            }
          }
          .padding(16)
        }
      }
      .navigationTitle("Profile")
    }
  }

  private var xeroCard: some View {
    @Bindable var store = store
    return VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Integrations")
      HStack(spacing: 12) {
        Image(systemName: "sparkles.rectangle.stack")
          .foregroundStyle(store.xeroConnected ? Brand.paidGreen : Brand.inkSoft)
          .frame(width: 34, height: 34)
          .background(Brand.lightGreen, in: RoundedRectangle(cornerRadius: 10))
        VStack(alignment: .leading, spacing: 2) {
          Text("Xero").font(.subheadline.weight(.semibold)).foregroundStyle(Brand.ink)
          Text(store.xeroConnected ? "Connected — invoices can be pushed" : "Not connected")
            .font(.caption).foregroundStyle(Brand.inkSoft)
        }
        Spacer()
        if store.xeroConnected {
          Image(systemName: "checkmark.seal.fill").foregroundStyle(Brand.paidGreen)
        }
      }

      Button {
        Task { await store.connectXero() }
      } label: {
        HStack(spacing: 8) {
          if store.xeroWorking {
            ProgressView().tint(.white)
          } else {
            Image(systemName: store.xeroConnected ? "arrow.triangle.2.circlepath" : "link")
          }
          Text(store.xeroConnected ? "Reconnect to Xero" : "Connect to Xero")
            .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Brand.charcoal, in: RoundedRectangle(cornerRadius: 12))
        .foregroundStyle(.white)
      }
      .disabled(store.xeroWorking)

      if let err = store.xeroError {
        Text(err).font(.caption2).foregroundStyle(Brand.red)
      }

      Text("Approved invoices push straight into Xero as draft bills. The Xero secret stays server-side.")
        .font(.caption2).foregroundStyle(Brand.inkSoft)
    }
    .mpgCard()
  }
}

#Preview {
  AdminRootView().environment(
    {
      let s = AppStore()
      s.login(as: s.users.first { $0.role == .admin }!)
      return s
    }())
}
