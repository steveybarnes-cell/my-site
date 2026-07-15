import SwiftUI

struct DailyRecordFormView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  let allocation: WorkAllocation

  @State private var startTime = "08:00"
  @State private var finishTime = "16:30"
  @State private var breakMinutes = 30
  @State private var description = ""
  @State private var category: WorkCategory = .contract
  @State private var delay: DelayReason = .none
  @State private var delayNote = ""
  @State private var instructedBy = ""
  @State private var showVoice = false
  @State private var didRestore = false
  private let drafts = DraftStore.shared

  private var totalHours: Double {
    let s = minutes(startTime)
    let f = minutes(finishTime)
    guard f > s else { return 0 }
    return Double(f - s - breakMinutes) / 60
  }

  var body: some View {
    Group {
      NavigationStack {
        ZStack {
          MPGBackground()
          ScrollView {
            VStack(spacing: 16) {
              siteHeader
              voicePrompt
              timesSection
              workSection
              if category == .variation { variationSection }
              delaySection
              totalBanner
              PrimaryButton(title: "Save Daily Record", symbol: "checkmark") { save() }
                .disabled(description.isEmpty || totalHours <= 0)
                .opacity(description.isEmpty || totalHours <= 0 ? 0.5 : 1)
              Button {
                saveDraft()
              } label: {
                Label("Save draft & finish later", systemImage: "tray.and.arrow.down")
                  .font(.subheadline.weight(.semibold))
                  .frame(maxWidth: .infinity)
                  .padding(.vertical, 14)
                  .foregroundStyle(Brand.olive)
                  .background(
                    Brand.lightGreen, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
              }
              .buttonStyle(.plain)
              Text("Works offline — saved on this device until you submit.")
                .font(.caption2).foregroundStyle(Brand.inkSoft)
                .frame(maxWidth: .infinity)
            }
            .padding(16)
          }
        }
        .navigationTitle("Daily Site Record")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        }
        .sheet(isPresented: $showVoice) {
          VoiceDailyRecordView { result in apply(result) }
        }
        .onAppear {
          guard !didRestore else { return }
          didRestore = true
          if let d = drafts.draft(forAllocation: allocation.id) {
            startTime = d.startTime
            finishTime = d.finishTime
            breakMinutes = d.breakMinutes
            description = d.description
            category = d.category
            delay = d.delay
            delayNote = d.delayNote
            instructedBy = d.instructedBy
          } else {
            startTime = allocation.startTime
            finishTime = allocation.expectedFinish
            category = allocation.category
            if let sm = allocation.siteManagerId.flatMap(store.user) { instructedBy = sm.name }
          }
        }
      }
    }
    .__tenxTrackView("DailyRecordFormView")
  }

  private var voicePrompt: some View {
    Button {
      showVoice = true
    } label: {
      HStack(spacing: 12) {
        ZStack {
          Circle().fill(Brand.olive).frame(width: 40, height: 40)
          Image(systemName: "waveform.badge.mic")
            .font(.headline).foregroundStyle(.white)
        }
        VStack(alignment: .leading, spacing: 1) {
          Text("Speak your record")
            .font(.subheadline.weight(.semibold)).foregroundStyle(Brand.ink)
          Text("Talk through your day — we'll fill it in")
            .font(.caption).foregroundStyle(Brand.inkSoft)
        }
        Spacer()
        Image(systemName: "chevron.right").font(.caption.weight(.bold))
          .foregroundStyle(Brand.inkSoft)
      }
      .mpgCard(padding: 12)
    }
    .buttonStyle(.plain)
  }

  private func apply(_ r: DailyRecordParser.Result) {
    if let s = r.startTime { startTime = s }
    if let f = r.finishTime { finishTime = f }
    if let b = r.breakMinutes { breakMinutes = b }
    if let c = r.category { category = c }
    if let d = r.delay, d != .none {
      delay = d
      if delayNote.isEmpty { delayNote = r.delayNote ?? "" }
    }
    if !r.description.isEmpty {
      description = description.isEmpty ? r.description : description + "\n" + r.description
    }
  }

  private var siteHeader: some View {
    HStack(spacing: 10) {
      Image(systemName: "mappin.circle.fill").foregroundStyle(Brand.olive).font(.title3)
      VStack(alignment: .leading, spacing: 1) {
        Text(store.site(allocation.siteId)?.name ?? "Site").font(.subheadline.weight(.semibold))
          .foregroundStyle(Brand.ink)
        Text(Fmt.date(allocation.date)).font(.caption).foregroundStyle(Brand.inkSoft)
      }
      Spacer()
    }
    .mpgCard(padding: 12)
  }

  private var timesSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Hours")
      timeStepper("Start time", $startTime)
      timeStepper("Finish time", $finishTime)
      Stepper(value: $breakMinutes, in: 0...180, step: 15) {
        HStack {
          Text("Break").foregroundStyle(Brand.ink)
          Spacer()
          Text("\(breakMinutes) min").foregroundStyle(Brand.inkSoft)
        }
        .font(.subheadline)
      }
    }
    .mpgFormSection()
  }

  private var workSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Work carried out")
      Picker("Category", selection: $category) {
        ForEach(WorkCategory.allCases) { Text($0.rawValue).tag($0) }
      }
      .pickerStyle(.menu).tint(Brand.olive)
      .frame(maxWidth: .infinity, alignment: .leading)
      ZStack(alignment: .topLeading) {
        if description.isEmpty {
          Text("Describe the work you completed today…")
            .font(.subheadline).foregroundStyle(Brand.inkSoft).padding(10)
        }
        TextEditor(text: $description)
          .font(.subheadline).frame(minHeight: 100).scrollContentBackground(.hidden).padding(4)
      }
      .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    .mpgFormSection()
  }

  private var variationSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Variation details")
      WarningBanner(
        message:
          "Photo evidence is required for variation work and must be approved by the site manager.",
        symbol: "photo.badge.checkmark", tint: Brand.blue)
      labelledField("Who instructed it?", $instructedBy)
    }
    .mpgFormSection()
  }

  private var delaySection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Delays")
      Picker("Delay", selection: $delay) {
        ForEach(DelayReason.allCases) { Text($0.rawValue).tag($0) }
      }
      .pickerStyle(.menu).tint(Brand.olive)
      .frame(maxWidth: .infinity, alignment: .leading)
      if delay != .none {
        labelledField("Delay note (required)", $delayNote)
      }
    }
    .mpgFormSection()
  }

  private var totalBanner: some View {
    HStack {
      Text("Total hours today").font(.subheadline.weight(.medium)).foregroundStyle(.white)
      Spacer()
      Text(Fmt.hours(totalHours)).font(.title3.bold()).foregroundStyle(.white)
    }
    .padding(16)
    .background(Brand.olive, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
  }

  private func timeStepper(_ label: String, _ binding: Binding<String>) -> some View {
    HStack {
      Text(label).font(.subheadline).foregroundStyle(Brand.ink)
      Spacer()
      TextField("08:00", text: binding)
        .font(.subheadline.weight(.medium))
        .multilineTextAlignment(.trailing)
        .frame(width: 70)
        .foregroundStyle(Brand.ink)
    }
  }

  private func labelledField(_ label: String, _ binding: Binding<String>) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(label).font(.caption).foregroundStyle(Brand.inkSoft)
      TextField("", text: binding)
        .font(.subheadline).padding(10)
        .background(.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
  }

  private func minutes(_ t: String) -> Int {
    let parts = t.split(separator: ":")
    guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return 0 }
    return h * 60 + m
  }

  private func save() {
    guard let me = store.currentUser else { return }
    let rec = DailyRecord(
      id: UUID(), allocationId: allocation.id, userId: me.id, siteId: allocation.siteId,
      date: allocation.date, startTime: startTime, finishTime: finishTime,
      breakMinutes: breakMinutes, totalHours: totalHours, trade: allocation.trade,
      description: description, category: category, delayReason: delay, delayNote: delayNote,
      notes: "", variationInstructedBy: instructedBy,
      variationStatus: category == .variation ? .awaiting : nil)
    store.addRecord(rec)
    store.updateAllocationStatus(allocation.id, to: .inProgress)
    if let existing = drafts.draft(forAllocation: allocation.id) {
      drafts.delete(existing.id)
    }
    dismiss()
  }

  private func saveDraft() {
    guard let me = store.currentUser else { return }
    let draft = RecordDraft(
      allocationId: allocation.id, siteId: allocation.siteId, userId: me.id,
      siteName: store.site(allocation.siteId)?.name ?? "Site",
      startTime: startTime, finishTime: finishTime, breakMinutes: breakMinutes,
      description: description, category: category, delay: delay, delayNote: delayNote,
      instructedBy: instructedBy)
    drafts.save(draft)
    dismiss()
  }
}
