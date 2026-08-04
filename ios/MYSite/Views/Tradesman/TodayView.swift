import SwiftUI

/// The working day, on one screen.
///
/// Today used to be a greeting, a receipt-scanning shortcut and a list of
/// allocations — a noticeboard. Everything a man actually does during a day
/// lived somewhere else: the clock under More → Attendance, the day sheet under
/// My Records, receipts under Scan. Four screens to record one day, and at the
/// end of it nothing added up to an invoice.
///
/// So this is the day itself: clock on, log what you did as you do it, add
/// photos, and close it off. The hours that reach the invoice are the hours
/// recorded here, which is the point — the figure the office queries is the
/// figure the phone captured.
struct TradesmanTodayView: View {
  @Environment(AppStore.self) private var store

  @State private var showAddWork = false
  @State private var editing: WorkLogEntry?
  @State private var showClock = false
  @State private var closedRecord: DailyRecord?
  @State private var showClosedConfirmation = false

  private var me: AppUser? { store.currentUser }
  private var today: Date { Date() }

  private var lines: [WorkLogEntry] {
    me.map { store.workLog(for: $0.id, on: today) } ?? []
  }
  private var openClock: ClockRecord? { me.flatMap { store.openClockRecord(for: $0.id) } }
  private var clockedHours: Double { me.map { store.clockedHours(for: $0.id, on: today) } ?? 0 }
  private var loggedHours: Double { lines.totalHours }
  private var todaysPhotos: [SitePhoto] { me.map { store.photos(for: $0.id, on: today) } ?? [] }
  private var todaysMaterials: [MaterialItem] {
    me.map { store.materials(for: $0.id, on: today) } ?? []
  }
  private var alreadyClosed: DailyRecord? {
    me.flatMap { store.dayRecord(for: $0.id, on: today) }
  }

  /// Where a new work line should default to: the site you are clocked into,
  /// then the site of your last line, then today's allocation.
  private var defaultSite: Site? {
    if let open = openClock { return store.site(open.siteId) }
    if let last = lines.last { return store.site(last.siteId) }
    guard let me else { return nil }
    return store.todaysAllocations(for: me.id).first.flatMap { store.site($0.siteId) }
  }

  var body: some View {
    NavigationStack {
      ZStack {
        MPGBackground()
        ScrollView {
          VStack(spacing: 16) {
            greeting
            clockCard
            workCard
            evidenceCard
            dayTotalCard
            allocationsSection
          }
          .padding(16)
        }
      }
      .navigationTitle("Today")
      .navigationBarTitleDisplayMode(.inline)
      .navigationDestination(for: WorkAllocation.self) { AllocationDetailView(allocation: $0) }
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          NavigationLink { NotificationsView() } label: { Image(systemName: "bell") }
        }
      }
      .sheet(isPresented: $showAddWork) {
        WorkLineSheet(site: defaultSite, date: today)
      }
      .sheet(item: $editing) { entry in
        WorkLineSheet(existing: entry, site: store.site(entry.siteId), date: entry.date)
      }
      .sheet(isPresented: $showClock) { ClockInView() }
      .alert("Day closed off", isPresented: $showClosedConfirmation) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(
          closedRecord.map {
            "\(Fmt.hours($0.totalHours)) recorded for \(store.site($0.siteId)?.name ?? "site"). "
              + "It'll be on this week's invoice."
          } ?? "")
      }
    }
  }

  // MARK: - Greeting

  private var greeting: some View {
    let first = (me?.name.split(separator: " ").first).map(String.init) ?? "there"
    let hour = Calendar.current.component(.hour, from: Date())
    let part = hour < 12 ? "morning" : (hour < 18 ? "afternoon" : "evening")
    return VStack(alignment: .leading, spacing: 14) {
      MPGLogo(height: 40, horizontal: true)
        .frame(maxWidth: .infinity, alignment: .leading)
      VStack(alignment: .leading, spacing: 6) {
        Text("Good \(part), \(first)")
          .font(.title2.bold())
          .foregroundStyle(.white)
        Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide)))
          .font(.subheadline)
          .foregroundStyle(.white.opacity(0.75))
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(18)
    .background(Brand.charcoal, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
  }

  // MARK: - Clock

  /// Clocked-on state gets a live elapsed time via `TimelineView` rather than a
  /// `Timer` the view has to own, start and tear down. SwiftUI redraws it once a
  /// second while it is on screen and stops when it isn't, which is exactly the
  /// behaviour wanted and none of the bookkeeping.
  private var clockCard: some View {
    VStack(alignment: .leading, spacing: 14) {
      SectionHeader(
        title: "Time on site",
        subtitle: openClock == nil ? "Clock on when you arrive" : "Running")

      if let open = openClock {
        TimelineView(.periodic(from: .now, by: 1)) { context in
          let elapsed = context.date.timeIntervalSince(open.clockInTime)
          VStack(alignment: .leading, spacing: 4) {
            Text(elapsedLabel(elapsed))
              .font(.system(size: 40, weight: .bold, design: .rounded))
              .monospacedDigit()
              .foregroundStyle(Brand.olive)
            Text("On since \(Fmt.time(open.clockInTime)) · \(store.site(open.siteId)?.name ?? "site")")
              .font(.footnote)
              .foregroundStyle(Brand.inkSoft)
          }
        }
        Button { showClock = true } label: {
          Label("Clock out", systemImage: "stop.circle.fill")
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Brand.charcoal, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
      } else {
        HStack(spacing: 10) {
          Text(Fmt.hours(clockedHours))
            .font(.system(size: 34, weight: .bold, design: .rounded))
            .foregroundStyle(clockedHours > 0 ? Brand.ink : Brand.inkSoft)
          Text(clockedHours > 0 ? "on site today" : "not clocked on yet")
            .font(.footnote)
            .foregroundStyle(Brand.inkSoft)
          Spacer()
        }
        Button { showClock = true } label: {
          Label("Clock on", systemImage: "play.circle.fill")
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Brand.olive, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
      }
    }
    .mpgCard()
  }

  private func elapsedLabel(_ seconds: TimeInterval) -> String {
    let total = max(0, Int(seconds))
    return String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
  }

  // MARK: - What you did

  private var workCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(
        title: "What you did",
        subtitle: lines.isEmpty
          ? "Add jobs as you go — quicker than remembering at five"
          : "\(lines.count) job\(lines.count == 1 ? "" : "s") · \(Fmt.hours(loggedHours))")

      if lines.isEmpty {
        Text("Nothing logged yet today.")
          .font(.subheadline)
          .foregroundStyle(Brand.inkSoft)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.vertical, 6)
      } else {
        VStack(spacing: 0) {
          ForEach(lines) { line in
            Button { editing = line } label: { workRow(line) }
              .buttonStyle(.plain)
            if line.id != lines.last?.id {
              Divider().overlay(Brand.hairline)
            }
          }
        }
      }

      Button { showAddWork = true } label: {
        Label("Add a job", systemImage: "plus.circle.fill")
          .font(.subheadline.weight(.semibold))
          .frame(maxWidth: .infinity)
          .padding(.vertical, 12)
          .background(Brand.lightGreen, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
          .foregroundStyle(Brand.oliveDark)
      }
      .buttonStyle(.plain)
      .disabled(defaultSite == nil)
      .opacity(defaultSite == nil ? 0.5 : 1)

      if defaultSite == nil {
        Text("You'll need a site before you can log work — clock on, or ask the office to allocate you.")
          .font(.caption)
          .foregroundStyle(Brand.inkSoft)
      }
    }
    .mpgCard()
  }

  private func workRow(_ line: WorkLogEntry) -> some View {
    HStack(alignment: .top, spacing: 12) {
      VStack(alignment: .leading, spacing: 3) {
        Text(line.description)
          .font(.subheadline.weight(.medium))
          .foregroundStyle(Brand.ink)
          .multilineTextAlignment(.leading)
        Text("\(store.site(line.siteId)?.name ?? "Site") · \(line.category.rawValue)")
          .font(.caption)
          .foregroundStyle(Brand.inkSoft)
      }
      Spacer(minLength: 8)
      Text(line.durationLabel)
        .font(.subheadline.weight(.semibold))
        .monospacedDigit()
        .foregroundStyle(Brand.oliveDark)
    }
    .padding(.vertical, 10)
    .contentShape(Rectangle())
  }

  // MARK: - Photos and receipts

  private var evidenceCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Evidence", subtitle: "Photos and receipts logged today")
      HStack(spacing: 10) {
        evidenceTile(
          count: todaysPhotos.count, label: todaysPhotos.count == 1 ? "photo" : "photos",
          symbol: "photo.on.rectangle.angled")
        evidenceTile(
          count: todaysMaterials.count, label: todaysMaterials.count == 1 ? "receipt" : "receipts",
          symbol: "doc.text.viewfinder")
      }
      if !todaysMaterials.isEmpty {
        let spend = todaysMaterials.reduce(0.0) { $0 + $1.costExVat }
        Text("\(Fmt.gbp(spend)) of materials on today's jobs.")
          .font(.caption)
          .foregroundStyle(Brand.inkSoft)
      }
    }
    .mpgCard()
  }

  private func evidenceTile(count: Int, label: String, symbol: String) -> some View {
    VStack(spacing: 4) {
      Image(systemName: symbol).font(.system(size: 18)).foregroundStyle(Brand.oliveDark)
      Text("\(count)").font(.title3.bold()).foregroundStyle(Brand.ink)
      Text(label).font(.caption2).foregroundStyle(Brand.inkSoft)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 12)
    .background(Brand.lightGreen, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
  }

  // MARK: - The day's total

  private var dayTotalCard: some View {
    let gap = clockedHours - loggedHours
    return VStack(alignment: .leading, spacing: 12) {
      SectionHeader(
        title: "Today's total",
        subtitle: alreadyClosed == nil ? "Close it off when you finish" : "Closed off")

      HStack(spacing: 12) {
        MetricTile(value: Fmt.hours(loggedHours), label: "Logged", symbol: "hammer.fill")
        MetricTile(value: Fmt.hours(clockedHours), label: "On site", symbol: "location.fill")
      }

      // Shown, never enforced. The clock is evidence, not an accusation, and a
      // man who forgot to clock on has not stopped being owed for his day —
      // but the office should see the difference rather than discover it.
      if clockedHours > 0, loggedHours > 0, abs(gap) >= 0.5 {
        Text(
          gap > 0
            ? "You've logged \(Fmt.hours(gap)) less than the clock recorded — breaks, or work still to add?"
            : "You've logged \(Fmt.hours(-gap)) more than the clock recorded. Worth a note for the office."
        )
        .font(.caption)
        .foregroundStyle(Brand.inkSoft)
      }

      if let closed = alreadyClosed {
        Label(
          "Day sheet saved — \(Fmt.hours(closed.totalHours))",
          systemImage: "checkmark.seal.fill"
        )
        .font(.footnote.weight(.medium))
        .foregroundStyle(Brand.oliveDark)
      }

      Button {
        guard let me else { return }
        closedRecord = store.closeDay(for: me.id, on: today)
        if closedRecord != nil { showClosedConfirmation = true }
      } label: {
        Label(
          alreadyClosed == nil ? "Finish the day" : "Update the day sheet",
          systemImage: "checkmark.circle.fill"
        )
        .font(.headline)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Brand.charcoal, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .foregroundStyle(.white)
      }
      .buttonStyle(.plain)
      .disabled(loggedHours == 0 && clockedHours == 0)
      .opacity(loggedHours == 0 && clockedHours == 0 ? 0.5 : 1)
    }
    .mpgCard()
  }

  // MARK: - Allocations

  @ViewBuilder private var allocationsSection: some View {
    let allocs = me.map { store.todaysAllocations(for: $0.id) } ?? []
    if !allocs.isEmpty {
      VStack(alignment: .leading, spacing: 10) {
        SectionHeader(title: "Allocated to you", subtitle: "Today and tomorrow")
        ForEach(allocs) { alloc in
          NavigationLink(value: alloc) {
            AllocationCard(allocation: alloc, showTradesman: false)
          }
          .buttonStyle(.plain)
        }
      }
    }
  }
}

// MARK: - Add / edit a work line

/// One job, on one site, for however long it took.
///
/// Duration is chosen in quarter-hours from a wheel rather than typed. Typing
/// a number on site, one-handed, in gloves, is how "1.5" becomes "15" — and a
/// tenfold error in hours is a tenfold error on an invoice.
struct WorkLineSheet: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss

  var existing: WorkLogEntry?
  var site: Site?
  var date: Date

  @State private var description = ""
  @State private var category: WorkCategory = .contract
  @State private var siteId: UUID?
  @State private var minutes: Int = 60

  private var availableSites: [Site] {
    let mine = store.sites.filter { $0.status == .active }
    return mine.isEmpty ? store.sites : mine
  }

  private var canSave: Bool {
    !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && minutes > 0 && siteId != nil
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("What did you do?") {
          TextField("First fix to plots 3 and 4", text: $description, axis: .vertical)
            .lineLimit(2...4)
        }
        Section("Where") {
          Picker("Site", selection: $siteId) {
            ForEach(availableSites) { s in
              Text(s.name).tag(Optional(s.id))
            }
          }
          Picker("Type of work", selection: $category) {
            ForEach(WorkCategory.allCases) { c in Text(c.rawValue).tag(c) }
          }
        }
        Section("How long") {
          Picker("Time", selection: $minutes) {
            ForEach(Array(stride(from: 15, through: 720, by: 15)), id: \.self) { m in
              Text(durationLabel(m)).tag(m)
            }
          }
          .pickerStyle(.wheel)
        }
        if existing != nil {
          Section {
            Button(role: .destructive) {
              if let existing { store.voidWorkLogEntry(existing.id) }
              dismiss()
            } label: {
              Label("Remove this job", systemImage: "trash")
            }
          } footer: {
            Text("It comes off your totals. The entry itself is kept, so a week that's already been invoiced still shows what it was built from.")
          }
        }
      }
      .navigationTitle(existing == nil ? "Add a job" : "Edit job")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") { save() }.disabled(!canSave)
        }
      }
      .onAppear(perform: load)
    }
  }

  private func durationLabel(_ m: Int) -> String {
    let h = m / 60
    let r = m % 60
    if h == 0 { return "\(r) min" }
    if r == 0 { return "\(h) hr\(h == 1 ? "" : "s")" }
    return "\(h) hr \(r) min"
  }

  private func load() {
    guard let existing else {
      siteId = site?.id ?? availableSites.first?.id
      return
    }
    description = existing.description
    category = existing.category
    siteId = existing.siteId
    minutes = existing.minutes
  }

  private func save() {
    guard let userId = store.currentUser?.id, let siteId else { return }
    let text = description.trimmingCharacters(in: .whitespacesAndNewlines)
    if var entry = existing {
      entry.description = text
      entry.category = category
      entry.siteId = siteId
      entry.minutes = minutes
      store.updateWorkLogEntry(entry)
    } else {
      store.addWorkLogEntry(
        WorkLogEntry(
          userId: userId, siteId: siteId, date: date, description: text,
          category: category, minutes: minutes))
    }
    dismiss()
  }
}
