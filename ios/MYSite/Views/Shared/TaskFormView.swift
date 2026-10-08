import SwiftUI

/// Setting out a job — for yourself, or for someone else if you run the office.
///
/// Available to every role on purpose. A site manager plans his own week, a
/// tradesman writes down the three things he means to get through, and an
/// admin allocates to the team. Same screen; the only difference is whether
/// the "who" picker appears at all.
struct TaskFormView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss

  var existing: WorkAllocation?
  var site: Site?

  @State private var taskDescription = ""
  @State private var siteId: UUID?
  @State private var tradesmanId: UUID?
  @State private var date = Date()
  @State private var trade = ""
  @State private var category: WorkCategory = .contract
  @State private var priority: Priority = .normal
  @State private var notes = ""

  /// Only an admin picks somebody else. Everyone else is quietly allocating to
  /// themselves, which is what "add a task" means when you are on the tools.
  private var canAssignOthers: Bool { store.currentUser?.role == .admin }

  private var people: [AppUser] {
    canAssignOthers ? store.users : [store.currentUser].compactMap { $0 }
  }
  private var sites: [Site] {
    let active = store.sites.filter { $0.status == .active }
    return active.isEmpty ? store.sites : active
  }
  private var canSave: Bool {
    !taskDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && siteId != nil && tradesmanId != nil
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("What needs doing?") {
          DictationField(
            placeholder: "Board out bedroom 2", text: $taskDescription, lines: 1...3)
        }
        Section("Where and when") {
          Picker("Site", selection: $siteId) {
            ForEach(sites) { s in Text(s.name).tag(Optional(s.id)) }
          }
          DatePicker("Date", selection: $date, displayedComponents: .date)
          if canAssignOthers {
            Picker("Who", selection: $tradesmanId) {
              ForEach(people) { p in Text(p.name).tag(Optional(p.id)) }
            }
          }
        }
        Section("Detail") {
          TextField("Trade — plasterer", text: $trade)
          Picker("Type of work", selection: $category) {
            ForEach(WorkCategory.allCases) { c in Text(c.rawValue).tag(c) }
          }
          Picker("Priority", selection: $priority) {
            ForEach(Priority.allCases) { p in Text(p.rawValue).tag(p) }
          }
        }
        Section {
          DictationField(placeholder: "Anything else", text: $notes, lines: 1...4)
        } footer: {
          Text("You can drag this to 50% or mark it done from the job screen as you go.")
        }
      }
      .navigationTitle(existing == nil ? "Add a task" : "Edit task")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") { save() }.disabled(!canSave)
        }
      }
      .onAppear(perform: load)
    }
  }

  private func load() {
    guard let existing else {
      siteId = site?.id ?? sites.first?.id
      tradesmanId = store.currentUser?.id
      trade = store.profile(for: store.currentUser?.id ?? UUID())?.mainTrade ?? ""
      return
    }
    taskDescription = existing.taskDescription
    siteId = existing.siteId
    tradesmanId = existing.tradesmanId
    date = existing.date
    trade = existing.trade
    category = existing.category
    priority = existing.priority
    notes = existing.notes
  }

  private func save() {
    guard let siteId, let tradesmanId else { return }
    let text = taskDescription.trimmingCharacters(in: .whitespacesAndNewlines)
    var a =
      existing
      ?? WorkAllocation(
        id: UUID(), siteId: siteId, tradesmanId: tradesmanId, siteManagerId: nil,
        date: date, startTime: "", expectedFinish: "", trade: trade,
        taskDescription: text, category: category, priority: priority,
        requiredPhotos: false, requiredMaterials: "", notes: notes, status: .allocated)
    a.siteId = siteId
    a.tradesmanId = tradesmanId
    a.date = date
    a.trade = trade
    a.taskDescription = text
    a.category = category
    a.priority = priority
    a.notes = notes
    store.saveAllocation(a)
    dismiss()
  }
}
