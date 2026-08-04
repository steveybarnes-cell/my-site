import Foundation

/// Turning a worked day into something that can be invoiced.
///
/// Everything needed already existed and none of it was joined up: the clock
/// wrote `ClockRecord`s, the day sheet wrote `DailyRecord`s, receipts wrote
/// `MaterialItem`s — and `saveSubmission` had no callers anywhere in the app,
/// so a tradesman could work all week and still have no way to bill for it.
/// The four submissions people saw were seed data.
///
/// This is the join. A day is closed off into a `DailyRecord` from what was
/// actually captured, and a week's `WeeklySubmission` is those days added up.
/// Nothing is retyped, which matters more than it sounds: the hours on the
/// invoice are the hours the clock recorded, so the number the office queries
/// is the number the phone captured.
extension AppStore {

  // MARK: - Reading a day

  /// Work lines logged by someone on a given day, oldest first, voids excluded.
  func workLog(for userId: UUID, on date: Date) -> [WorkLogEntry] {
    workLogEntries
      .filter {
        $0.userId == userId && !$0.voided
          && Calendar.current.isDate($0.date, inSameDayAs: date)
      }
      .sorted { $0.createdAt < $1.createdAt }
  }

  /// Clock records for someone on a given day. Usually one, but a man who
  /// travels between two sites clocks in twice, so this is deliberately plural.
  func clockRecords(for userId: UUID, on date: Date) -> [ClockRecord] {
    clockRecords
      .filter { $0.userId == userId && Calendar.current.isDate($0.date, inSameDayAs: date) }
      .sorted { $0.clockInTime < $1.clockInTime }
  }

  /// Hours the clock actually recorded, closed spans only.
  ///
  /// An open span counts as zero rather than as time-so-far. Somebody still on
  /// site has not finished, and a total that creeps upward while you look at it
  /// is not a total.
  func clockedHours(for userId: UUID, on date: Date) -> Double {
    clockRecords(for: userId, on: date).reduce(0) { acc, r in
      guard let out = r.clockOutTime else { return acc }
      return acc + out.timeIntervalSince(r.clockInTime) / 3600
    }
  }

  /// Hours claimed across the day's work lines.
  func loggedHours(for userId: UUID, on date: Date) -> Double {
    workLog(for: userId, on: date).totalHours
  }

  /// Photos captured by someone on a day.
  func photos(for userId: UUID, on date: Date) -> [SitePhoto] {
    photos
      .filter {
        $0.userId == userId && Calendar.current.isDate($0.timestamp, inSameDayAs: date)
      }
      .sorted { $0.timestamp < $1.timestamp }
  }

  /// Materials logged by someone on a day.
  func materials(for userId: UUID, on date: Date) -> [MaterialItem] {
    materials
      .filter { $0.userId == userId && Calendar.current.isDate($0.date, inSameDayAs: date) }
      .sorted { $0.date < $1.date }
  }

  /// The day sheet for a day, if it has already been closed off.
  func dayRecord(for userId: UUID, on date: Date) -> DailyRecord? {
    dailyRecords.first {
      $0.userId == userId && Calendar.current.isDate($0.date, inSameDayAs: date)
    }
  }

  // MARK: - Work lines

  func addWorkLogEntry(_ e: WorkLogEntry) {
    workLogEntries.append(e)
    sync(queued: SupabaseData.operation(for: e)) { try await SupabaseData.save(e, token: $0) }
  }

  func updateWorkLogEntry(_ e: WorkLogEntry) {
    guard let i = workLogEntries.firstIndex(where: { $0.id == e.id }) else { return }
    workLogEntries[i] = e
    sync(queued: SupabaseData.operation(for: e)) { try await SupabaseData.save(e, token: $0) }
  }

  /// Removes a line from every total while leaving the row in place.
  func voidWorkLogEntry(_ id: UUID) {
    guard let i = workLogEntries.firstIndex(where: { $0.id == id }) else { return }
    workLogEntries[i].voided = true
    let updated = workLogEntries[i]
    sync(queued: SupabaseData.operation(for: updated)) {
      try await SupabaseData.save(updated, token: $0)
    }
  }

  // MARK: - Closing a day

  /// Whether a day has anything worth closing off.
  func dayHasContent(for userId: UUID, on date: Date) -> Bool {
    !workLog(for: userId, on: date).isEmpty || clockedHours(for: userId, on: date) > 0
  }

  /// Writes (or rewrites) the day sheet from what was captured.
  ///
  /// Re-runnable on purpose. Closing a day, remembering another hour, and
  /// closing it again should correct the sheet rather than create a second one,
  /// so this updates in place when a record for the day already exists.
  ///
  /// Hours are the logged lines when there are any, and the clock otherwise. A
  /// man who logged his work knows better than the clock what he was doing; a
  /// man who logged nothing at least clocked in and out.
  @discardableResult
  func closeDay(for userId: UUID, on date: Date, notes: String = "") -> DailyRecord? {
    let lines = workLog(for: userId, on: date)
    let clocks = clockRecords(for: userId, on: date)
    let clocked = clockedHours(for: userId, on: date)
    let logged = lines.totalHours
    guard !lines.isEmpty || clocked > 0 else { return nil }

    // Site is wherever most of the day went, falling back to where the clock
    // was. Picking the first line would put a full day at a site somebody
    // visited for twenty minutes.
    let siteId =
      Dictionary(grouping: lines, by: \.siteId)
      .max { $0.value.totalMinutes < $1.value.totalMinutes }?.key
      ?? clocks.first?.siteId
    guard let siteId else { return nil }

    let hours = logged > 0 ? logged : clocked
    let start = clocks.first.map { Fmt.time($0.clockInTime) } ?? ""
    let finish = clocks.compactMap(\.clockOutTime).last.map(Fmt.time) ?? ""

    // Break is what the clock covered but nobody claimed — a man on site for
    // nine hours who logged eight took an hour off. Negative means he claimed
    // more than the clock saw, which is a query for the office, not a break.
    let breakMinutes = max(0, Int(((clocked - logged) * 60).rounded()))

    let description =
      lines.isEmpty
      ? "Recorded by clock in/out."
      : lines.map { "\($0.description) (\($0.durationLabel))" }.joined(separator: "\n")

    let category = lines.first?.category ?? .contract
    let trade = profile(for: userId)?.mainTrade ?? user(userId)?.name ?? ""

    if var existing = dayRecord(for: userId, on: date) {
      existing.siteId = siteId
      existing.startTime = start
      existing.finishTime = finish
      existing.breakMinutes = lines.isEmpty ? existing.breakMinutes : breakMinutes
      existing.totalHours = hours
      existing.description = description
      existing.category = category
      if !notes.isEmpty { existing.notes = notes }
      updateRecord(existing)
      return existing
    }

    let record = DailyRecord(
      id: UUID(), allocationId: lines.first?.allocationId, userId: userId, siteId: siteId,
      date: date, startTime: start, finishTime: finish, breakMinutes: breakMinutes,
      totalHours: hours, trade: trade, description: description, category: category,
      delayReason: .none, delayNote: "", notes: notes,
      variationInstructedBy: "", variationStatus: nil)
    addRecord(record)
    return record
  }

  // MARK: - The week

  /// Saturday-ending week containing `date`, which is how the app's existing
  /// submissions are dated.
  func weekEnding(for date: Date) -> Date {
    let cal = Calendar.current
    let start = cal.startOfDay(for: date)
    // weekday: 1 = Sunday … 7 = Saturday
    let weekday = cal.component(.weekday, from: start)
    let daysToSaturday = (7 - weekday) % 7
    return cal.date(byAdding: .day, value: daysToSaturday, to: start) ?? start
  }

  /// Day sheets belonging to a week.
  func dayRecords(for userId: UUID, weekEnding week: Date) -> [DailyRecord] {
    dailyRecords
      .filter { $0.userId == userId && weekEnding(for: $0.date) == weekEnding(for: week) }
      .sorted { $0.date < $1.date }
  }

  /// Materials belonging to a week.
  func materials(for userId: UUID, weekEnding week: Date) -> [MaterialItem] {
    materials.filter {
      $0.userId == userId && weekEnding(for: $0.date) == weekEnding(for: week)
    }
  }

  /// Builds this week's invoice from the day sheets, or updates the draft that
  /// already exists.
  ///
  /// Refuses once the office has it. A submitted invoice that silently rewrote
  /// itself because somebody logged another hour would be indistinguishable,
  /// from the office's side, from a subcontractor changing his figures after
  /// the fact — so an approved or paid week is left alone and the caller is
  /// told nothing happened.
  @discardableResult
  func buildWeeklyInvoice(for userId: UUID, weekEnding week: Date) -> WeeklySubmission? {
    let week = weekEnding(for: week)
    let days = dayRecords(for: userId, weekEnding: week)
    guard !days.isEmpty else { return nil }

    let hours = days.reduce(0.0) { $0 + $1.totalHours }
    let materialsTotal = materials(for: userId, weekEnding: week)
      .filter { $0.chargeable != .no }
      .reduce(0.0) { $0 + $1.costExVat }
    let prof = profile(for: userId)

    let existing = submissions.first {
      $0.userId == userId && weekEnding(for: $0.weekEnding) == week
    }
    if let existing, existing.status != .draft {
      return nil
    }

    var sub =
      existing
      ?? WeeklySubmission(
        id: UUID(), userId: userId, weekEnding: week,
        invoiceNumber: nextInvoiceNumber(for: userId, weekEnding: week),
        totalHours: 0, labourRate: prof?.hourlyRate ?? 0, materialsTotal: 0,
        plantMileage: 0, cisRate: 0.20, vatRegistered: prof?.vatRegistered ?? false,
        status: .draft, submittedAt: nil, approvedBy: nil, paidDate: nil)

    sub.totalHours = hours
    sub.materialsTotal = materialsTotal
    sub.labourRate = existing?.labourRate ?? prof?.hourlyRate ?? 0
    sub.vatRegistered = prof?.vatRegistered ?? sub.vatRegistered
    saveSubmission(sub)
    return sub
  }

  /// A readable per-person invoice number: initials, year, week.
  ///
  /// Deliberately derived rather than a counter, so rebuilding the same week
  /// twice produces the same number instead of burning a new one each time.
  func nextInvoiceNumber(for userId: UUID, weekEnding week: Date) -> String {
    let cal = Calendar.current
    let initials =
      (user(userId)?.name ?? "XX")
      .split(separator: " ").compactMap(\.first).map(String.init).joined()
      .uppercased()
    let year = cal.component(.year, from: week) % 100
    let weekNo = cal.component(.weekOfYear, from: week)
    return String(format: "%@-%02d%02d", initials.isEmpty ? "XX" : initials, year, weekNo)
  }
}
