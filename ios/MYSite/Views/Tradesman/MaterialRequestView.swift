import SwiftUI

/// Asking the office for materials.
///
/// The point is that it lands somewhere the office actually looks, rather than
/// in a text message at ten at night that gets read on the way to another job
/// and forgotten by the time anyone is near a supplier.
struct MaterialRequestView: View {
  @Environment(AppStore.self) private var store

  var allocation: WorkAllocation? = nil
  @State private var showForm = false

  private var me: AppUser? { store.currentUser }
  private var mine: [MaterialRequest] {
    me.map { store.materialRequests(for: $0.id) } ?? []
  }

  var body: some View {
    Group {
      NavigationStack {
        ZStack {
          MPGBackground()
          ScrollView {
            VStack(spacing: 16) {
              PrimaryButton(title: "Ask for materials", symbol: "plus.circle.fill") {
                showForm = true
              }
              if mine.isEmpty {
                EmptyStateView(
                  symbol: "shippingbox",
                  title: "Nothing asked for yet",
                  message: "Tell the office what you're short of and it lands on their screen "
                    + "straight away."
                ).mpgCard()
              } else {
                ForEach(mine) { req in
                  requestCard(req)
                }
              }
            }
            .padding(16)
          }
        }
        .navigationTitle("Materials")
        .sheet(isPresented: $showForm) {
          MaterialRequestForm(allocation: allocation)
        }
      }
    }
    .__tenxTrackView("MaterialRequestView")
  }

  private func requestCard(_ r: MaterialRequest) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 3) {
          Text(r.description)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Brand.ink)
          if !r.quantity.isEmpty {
            Text(r.quantity).font(.caption).foregroundStyle(Brand.inkSoft)
          }
        }
        Spacer(minLength: 8)
        StatusChip(text: r.status.rawValue, color: colour(r.status), filled: r.status == .requested)
      }
      HStack(spacing: 10) {
        Label(store.site(r.siteId)?.name ?? "Site", systemImage: "mappin.and.ellipse")
        if let by = r.neededBy {
          Label("by \(Fmt.date(by))", systemImage: "calendar")
        }
      }
      .font(.caption)
      .foregroundStyle(Brand.inkSoft)

      if !r.officeNote.isEmpty {
        Text(r.officeNote)
          .font(.caption)
          .foregroundStyle(Brand.inkSoft)
          .padding(10)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(Brand.lightGreen, in: RoundedRectangle(cornerRadius: 10))
      }
    }
    .mpgCard()
  }

  private func colour(_ s: MaterialRequestStatus) -> Color {
    switch s {
    case .requested: return Brand.amber
    case .ordered: return Brand.blue
    case .delivered: return Brand.olive
    case .declined: return Brand.red
    }
  }
}

/// One trip to the merchant is rarely one item.
///
/// The first version took a single line and made you send the whole form again
/// for the second thing you needed, which is how a list of eight becomes a list
/// of three and a phone call. Now it's a list with a plus button.
///
/// Each line is still saved as its own request, because the office actions them
/// one at a time — the plasterboard arrives Tuesday and the beads are on back
/// order, and one shared status could not say that.
struct MaterialRequestForm: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss

  var allocation: WorkAllocation?

  /// A line being typed. Identifiable so `ForEach` can track rows through
  /// insertion and deletion — indices alone lose their place the moment a row
  /// in the middle goes.
  struct Line: Identifiable {
    let id = UUID()
    var what = ""
    var howMuch = ""
  }

  @State private var lines: [Line] = [Line()]
  @State private var siteId: UUID?
  @State private var neededBy = Date()
  @State private var hasDeadline = true

  private var sites: [Site] {
    let active = store.sites.filter { $0.status == .active }
    return active.isEmpty ? store.sites : active
  }
  private var filled: [Line] {
    lines.filter { !$0.what.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
  }
  private var canSave: Bool { !filled.isEmpty && siteId != nil }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          ForEach($lines) { $line in
            VStack(spacing: 6) {
              DictationField(placeholder: "12.5mm plasterboard", text: $line.what, lines: 1...2)
              TextField("How much — 20 sheets", text: $line.howMuch)
                .font(.subheadline)
                .foregroundStyle(Brand.inkSoft)
            }
            .padding(.vertical, 2)
          }
          .onDelete { idx in
            lines.remove(atOffsets: idx)
            if lines.isEmpty { lines = [Line()] }
          }

          Button {
            lines.append(Line())
          } label: {
            Label("Add another", systemImage: "plus.circle.fill")
          }
        } header: {
          Text("What do you need?")
        } footer: {
          Text(filled.count > 1
            ? "\(filled.count) items. Swipe a line to remove it."
            : "Swipe a line to remove it.")
        }

        Section("Where") {
          Picker("Site", selection: $siteId) {
            ForEach(sites) { s in Text(s.name).tag(Optional(s.id)) }
          }
        }
        Section {
          Toggle("Needed by a date", isOn: $hasDeadline)
          if hasDeadline {
            DatePicker("Date", selection: $neededBy, displayedComponents: .date)
          }
        } footer: {
          Text("The office sees these the moment you send them, and each one can be marked "
            + "ordered on its own.")
        }
      }
      .navigationTitle("Ask for materials")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button(filled.count > 1 ? "Send \(filled.count)" : "Send") { save() }
            .disabled(!canSave)
        }
      }
      .onAppear { siteId = allocation?.siteId ?? sites.first?.id }
    }
  }

  private func save() {
    guard let userId = store.currentUser?.id, let siteId else { return }
    for line in filled {
      store.addMaterialRequest(
        MaterialRequest(
          userId: userId, siteId: siteId, allocationId: allocation?.id,
          description: line.what.trimmingCharacters(in: .whitespacesAndNewlines),
          quantity: line.howMuch.trimmingCharacters(in: .whitespacesAndNewlines),
          neededBy: hasDeadline ? neededBy : nil))
    }
    dismiss()
  }
}
