import SwiftUI

/// Allocate work to a tradesman for a given day, or edit an existing allocation.
struct AllocationFormView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss

  let allocation: WorkAllocation?

  @State private var siteId: UUID?
  @State private var tradesmanId: UUID?
  @State private var date = Date()
  @State private var startTime = "08:00"
  @State private var expectedFinish = "16:30"
  @State private var trade = ""
  @State private var taskDescription = ""
  @State private var category: WorkCategory = .contract
  @State private var priority: Priority = .normal
  @State private var requiredPhotos = true
  @State private var requiredMaterials = ""
  @State private var notes = ""
  @State private var status: AllocationStatus = .allocated
  @State private var confirmCancel = false
  @State private var confirmRemove = false

  private var isEditing: Bool { allocation != nil }
  private var canSave: Bool { siteId != nil && tradesmanId != nil && !taskDescription.isEmpty }

  var body: some View {
    Group {
      NavigationStack {
        ZStack {
          MPGBackground()
          ScrollView {
            VStack(spacing: 16) {
              assignSection
              workSection
              optionsSection
              if isEditing { statusSection }
              PrimaryButton(
                title: isEditing ? "Save Changes" : "Allocate Work", symbol: "checkmark"
              ) { save() }
              .disabled(!canSave)
              .opacity(canSave ? 1 : 0.5)
              if isEditing && status != .cancelled {
                cancelJobButton
              }
              if isEditing {
                removeJobButton
              }
            }
            .padding(16)
          }
        }
        .confirmationDialog(
          "Cancel this job?", isPresented: $confirmCancel, titleVisibility: .visible
        ) {
          Button("Cancel Job", role: .destructive) { cancelJob() }
          Button("Keep Job", role: .cancel) {}
        } message: {
          Text("The tradesman will be notified and the job will be removed from their day. "
            + "It stays in your records as cancelled.")
        }
        .navigationTitle(isEditing ? "Edit Allocation" : "Allocate Work")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        }
        .confirmationDialog(
          "Remove this job?", isPresented: $confirmRemove, titleVisibility: .visible
        ) {
          Button("Remove Job", role: .destructive) { removeJob() }
          Button("Keep Job", role: .cancel) {}
        } message: {
          Text(removeMessage)
        }
        .onAppear(perform: load)
      }
    }
    .__tenxTrackView("AllocationFormView")
  }

  private var assignSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Assign")
      Picker("Site", selection: $siteId) {
        Text("Choose a site").tag(UUID?.none)
        ForEach(store.sites) { s in Text(s.name).tag(UUID?.some(s.id)) }
      }
      .pickerStyle(.menu).tint(Brand.olive).frame(maxWidth: .infinity, alignment: .leading)
      Picker("Tradesman", selection: $tradesmanId) {
        Text("Choose a tradesman").tag(UUID?.none)
        ForEach(store.tradesmen()) { t in Text(t.name).tag(UUID?.some(t.id)) }
      }
      .pickerStyle(.menu).tint(Brand.olive).frame(maxWidth: .infinity, alignment: .leading)
      DatePicker("Date", selection: $date, displayedComponents: .date)
        .tint(Brand.olive)
    }
    .mpgFormSection()
  }

  private var workSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Work")
      Field(label: "Trade", text: $trade)
      Field(label: "Task description", text: $taskDescription)
      Picker("Category", selection: $category) {
        ForEach(WorkCategory.allCases) { Text($0.rawValue).tag($0) }
      }
      .pickerStyle(.menu).tint(Brand.olive).frame(maxWidth: .infinity, alignment: .leading)
      Picker("Priority", selection: $priority) {
        ForEach(Priority.allCases) { Text($0.rawValue).tag($0) }
      }
      .pickerStyle(.segmented)
    }
    .mpgFormSection()
  }

  private var optionsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Requirements")
      HStack {
        Field(label: "Start (HH:mm)", text: $startTime)
        Field(label: "Finish (HH:mm)", text: $expectedFinish)
      }
      Toggle(isOn: $requiredPhotos) {
        Text("Photos required").font(.subheadline).foregroundStyle(Brand.ink)
      }
      .tint(Brand.olive)
      Field(label: "Materials to bring", text: $requiredMaterials)
      Field(label: "Notes", text: $notes)
    }
    .mpgFormSection()
  }

  private var statusSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Status")
      Picker("Status", selection: $status) {
        ForEach(AllocationStatus.allCases) { Text($0.rawValue).tag($0) }
      }
      .pickerStyle(.menu).tint(Brand.olive).frame(maxWidth: .infinity, alignment: .leading)
    }
    .mpgFormSection()
  }

  /// Sits under Save Changes: a quiet outlined button so it can't be hit by
  /// accident, with a confirmation before anything happens.
  private var cancelJobButton: some View {
    Button { confirmCancel = true } label: {
      HStack(spacing: 8) {
        Image(systemName: "xmark.circle")
        Text("Cancel Job").fontWeight(.semibold)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 15)
      .foregroundStyle(Brand.red)
      .background(
        RoundedRectangle(cornerRadius: Brand.Radius.inner, style: .continuous)
          .stroke(Brand.red.opacity(0.6), lineWidth: 1.5))
    }
    .buttonStyle(.plain)
  }

  private var hasActivity: Bool { allocation.map { store.allocationHasActivity($0) } ?? false }

  private var removeMessage: String {
    hasActivity
      ? "Work has already been logged against this job. Removing it deletes the job itself; "
        + "the hours, photos and day sheets stay on record but will no longer be linked to it. "
        + "If the job is simply not going ahead, use Cancel Job instead."
      : "This deletes the job. Nothing has been recorded against it yet."
  }

  /// Plain text link under the two main buttons: it is the destructive one,
  /// so it should be the least prominent.
  private var removeJobButton: some View {
    Button { confirmRemove = true } label: {
      Label("Remove job", systemImage: "trash")
        .font(.subheadline.weight(.medium))
        .foregroundStyle(Brand.inkSoft)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
    .buttonStyle(.plain)
  }

  private func removeJob() {
    guard let allocation else { return }
    store.deleteAllocation(allocation)
    dismiss()
  }

  private func cancelJob() {
    guard let allocation else { return }
    store.cancelAllocation(allocation)
    dismiss()
  }

  private func load() {
    guard let a = allocation else { return }
    siteId = a.siteId
    tradesmanId = a.tradesmanId
    date = a.date
    startTime = a.startTime
    expectedFinish = a.expectedFinish
    trade = a.trade
    taskDescription = a.taskDescription
    category = a.category
    priority = a.priority
    requiredPhotos = a.requiredPhotos
    requiredMaterials = a.requiredMaterials
    notes = a.notes
    status = a.status
  }

  private func save() {
    guard let siteId, let tradesmanId else { return }
    let sm = store.site(siteId)?.siteManagerId
    let updated = WorkAllocation(
      id: allocation?.id ?? UUID(),
      siteId: siteId,
      tradesmanId: tradesmanId,
      siteManagerId: sm,
      date: date,
      startTime: startTime,
      expectedFinish: expectedFinish,
      trade: trade,
      taskDescription: taskDescription,
      category: category,
      priority: priority,
      requiredPhotos: requiredPhotos,
      requiredMaterials: requiredMaterials,
      notes: notes,
      status: status)
    store.saveAllocation(updated)
    dismiss()
  }
}

#Preview {
  AllocationFormView(allocation: nil).environment(AppStore())
}
