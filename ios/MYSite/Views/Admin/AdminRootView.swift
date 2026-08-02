import SwiftUI

struct AdminRootView: View {
  @Environment(AppStore.self) private var store

  var body: some View {
    Group {
      TabView {
        Tab("Team", systemImage: "bubble.left.and.bubble.right.fill") {
          CompanyFeedView()
        }
        Tab("Dashboard", systemImage: "square.grid.2x2.fill") {
          DashboardView()
        }
        Tab("Invoices", systemImage: "doc.text.fill") {
          AdminSubmissionsView()
        }
        .badge(store.invoiceActionCount)
        Tab("Alerts", systemImage: "bell.fill") {
          NotificationsView()
        }
        .badge(store.unreadCount)
        Tab("More", systemImage: "ellipsis.circle.fill") {
          AdminMoreView()
        }
      }
    }
    .onAppear { store.notifyPendingReviews() }
    .__tenxTrackView("AdminRootView")
  }
}

// MARK: - More hub

struct AdminMoreView: View {
  @Environment(AppStore.self) private var store

  var body: some View {
    MoreHubView(
      roleTitle: "Office / Admin",
      roleSymbol: "shield.lefthalf.filled",
      items: [
        MoreHubItem(
          title: "Manage",
          subtitle: "Sites, team & work allocations",
          symbol: "square.and.pencil"
        ) { ManageView() },
        MoreHubItem(
          title: "Weekly Recap",
          subtitle: "AI spend summary per week",
          symbol: "sparkles",
          tint: Brand.olive
        ) { WeeklySpendSummaryView() },
        MoreHubItem(
          title: "Ask MPG",
          subtitle: "Ask about spend, invoices & sites",
          symbol: "sparkles.rectangle.stack",
          tint: Brand.blue
        ) { AskMPGView() },
        MoreHubItem(
          title: "Work by Trade",
          subtitle: "Unified timeline per trade",
          symbol: "hammer.fill",
          tint: Brand.amber
        ) { TradeWorkFeedView() },
        MoreHubItem(
          title: "Attendance",
          subtitle: "Clock-ins, geofence & approvals",
          symbol: "location.fill.viewfinder",
          tint: Brand.blue
        ) { AttendanceView() },
        MoreHubItem(
          title: "Files",
          subtitle: "Site file hub & registers",
          symbol: "folder.fill"
        ) { FilesView() },
        MoreHubItem(
          title: "Profile & Integrations",
          subtitle: "Xero, team & log out",
          symbol: "person.crop.circle.fill",
          tint: Brand.charcoal
        ) { AdminProfileView() },
      ]
    )
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
        value: "\(store.pendingAdminReviewCount)",
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
            Label(sm.name, systemImage: "person.bust").font(.caption).foregroundStyle(Brand.inkSoft)
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
  @State private var showAudit = false

  private var live: WeeklySubmission {
    store.submissions.first(where: { $0.id == submission.id }) ?? submission
  }

  private var audit: InvoiceAudit {
    InvoiceAuditor.audit(live, store: store)
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

      Button {
        showAudit = true
      } label: {
        HStack(spacing: 8) {
          AuditRiskBadge(audit: audit)
          Text(audit.topSeverity >= .warning ? "Review AI audit" : "AI audit — clear")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Brand.ink)
          Spacer()
          Image(systemName: "chevron.right").font(.caption2).foregroundStyle(Brand.inkSoft)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Brand.lightGreen.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
      }
      .buttonStyle(.plain)
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
    .sheet(isPresented: $showAudit) {
      InvoiceAuditView(submission: live).environment(store)
    }
  }
}

struct AdminProfileView: View {
  @Environment(AppStore.self) private var store
  @Environment(AuthManager.self) private var auth

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

            // Admin-only: generate invite codes and decide upgrade requests.
            if store.isLiveBackend {
              NavigationLink {
                RoleAdminView()
              } label: {
                HStack(spacing: 12) {
                  Image(systemName: "person.badge.key.fill")
                    .foregroundStyle(Brand.oliveDark)
                    .frame(width: 28, height: 28)
                    .background(Brand.lightGreen, in: RoundedRectangle(cornerRadius: 8))
                  VStack(alignment: .leading, spacing: 2) {
                    Text("Access & Invites")
                      .font(.subheadline.weight(.semibold)).foregroundStyle(Brand.ink)
                    Text("Invite managers and approve requests")
                      .font(.caption).foregroundStyle(Brand.inkSoft)
                  }
                  Spacer()
                  Image(systemName: "chevron.right").font(.caption).foregroundStyle(Brand.inkSoft)
                }
                .mpgCard()
              }
              .buttonStyle(.plain)
            }

            PrimaryButton(
              title: "Log Out", symbol: "rectangle.portrait.and.arrow.right", tint: Brand.charcoal
            ) {
              // Revokes the token and returns to LoginView. store.logout()
              // alone leaves auth.phase == .signedIn, which drops the user
              // into the tradesman app instead of signing them out.
              Task { await auth.signOut() }
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

      Text(
        "Approved invoices push straight into Xero as draft bills. The Xero secret stays server-side."
      )
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
