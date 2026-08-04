import SwiftUI

// MARK: - Records (daily records + materials + photos)

struct TradesmanRecordsView: View {
  @Environment(AppStore.self) private var store
  @State private var tab = 0
  @State private var draftStore = DraftStore.shared
  @State private var resumeAllocation: WorkAllocation?
  @State private var editingMaterial: MaterialItem?

  private var me: AppUser? { store.currentUser }

  var body: some View {
    Group {
      NavigationStack {
        ZStack {
          MPGBackground()
          ScrollView {
            VStack(spacing: 16) {
              Picker("View", selection: $tab) {
                Text("Site Records").tag(0)
                Text("Materials").tag(1)
                Text("Photos").tag(2)
              }
              .pickerStyle(.segmented)

              if tab == 0 {
                draftsSection
                recordsList
              } else if tab == 1 {
                materialsList
              } else {
                photosList
              }
            }
            .padding(16)
          }
        }
        .navigationTitle("My Records")
        .sheet(item: $editingMaterial) { MaterialEditSheet(material: $0) }
        .sheet(item: $resumeAllocation) { DailyRecordFormView(allocation: $0) }
      }
    }
    .__tenxTrackView("TradesmanRecordsView")
  }

  @ViewBuilder private var draftsSection: some View {
    let drafts = me.map { draftStore.drafts(for: $0.id) } ?? []
    if !drafts.isEmpty {
      VStack(alignment: .leading, spacing: 10) {
        Label("Saved drafts", systemImage: "tray.full.fill")
          .font(.subheadline.weight(.semibold)).foregroundStyle(Brand.olive)
        Text("Unfinished records saved on this device. Resume to complete and submit.")
          .font(.caption).foregroundStyle(Brand.inkSoft)
        ForEach(drafts) { d in
          HStack(spacing: 12) {
            Image(systemName: "square.and.pencil")
              .font(.headline).foregroundStyle(Brand.olive)
              .frame(width: 40, height: 40)
              .background(Brand.lightGreen, in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
              Text(d.siteName).font(.subheadline.weight(.semibold)).foregroundStyle(Brand.ink)
              Text(d.description.isEmpty ? "No description yet" : d.description)
                .font(.caption).foregroundStyle(Brand.inkSoft).lineLimit(1)
              Text("Saved \(Fmt.date(d.updatedAt))")
                .font(.caption2).foregroundStyle(Brand.inkSoft)
            }
            Spacer()
            Button {
              resume(d)
            } label: {
              Text("Resume").font(.caption.weight(.bold)).foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Brand.olive, in: Capsule())
            }
            .buttonStyle(.plain)
            Button {
              draftStore.delete(d.id)
            } label: {
              Image(systemName: "trash").font(.subheadline).foregroundStyle(Brand.red)
            }
            .buttonStyle(.plain)
          }
          .padding(.vertical, 4)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .mpgCard()
    }
  }

  private func resume(_ draft: RecordDraft) {
    guard let allocationId = draft.allocationId,
      let alloc = store.allocations.first(where: { $0.id == allocationId })
    else { return }
    resumeAllocation = alloc
  }

  @ViewBuilder private var recordsList: some View {
    let records = me.map { store.records(for: $0.id) } ?? []
    if records.isEmpty {
      EmptyStateView(
        symbol: "list.clipboard", title: "No records yet",
        message: "Daily site records you submit will appear here."
      ).mpgCard()
    } else {
      ForEach(records) { r in
        VStack(alignment: .leading, spacing: 10) {
          HStack {
            StatusChip(text: r.category.rawValue, color: Brand.olive)
            Spacer()
            Text(Fmt.date(r.date)).font(.caption).foregroundStyle(Brand.inkSoft)
          }
          Text(store.site(r.siteId)?.name ?? "Site")
            .font(.headline).foregroundStyle(Brand.ink)
          Text(r.description).font(.subheadline).foregroundStyle(Brand.inkSoft).lineLimit(3)
          Divider().overlay(Brand.hairline)
          HStack(spacing: 14) {
            Label("\(r.startTime)–\(r.finishTime)", systemImage: "clock")
            Label(Fmt.hours(r.totalHours), systemImage: "hourglass")
            if r.delayReason != .none {
              Label(r.delayReason.rawValue, systemImage: "exclamationmark.triangle")
                .foregroundStyle(Brand.amber)
            }
          }
          .font(.caption).foregroundStyle(Brand.inkSoft)
        }
        .mpgCard()
      }
    }
  }

  @ViewBuilder private var materialsList: some View {
    let mats = me.map { store.materials(for: $0.id) } ?? []
    if mats.isEmpty {
      EmptyStateView(
        symbol: "shippingbox", title: "No materials logged",
        message: "Materials you purchase for jobs will appear here."
      ).mpgCard()
    } else {
      ForEach(mats) { m in
        Button {
          editingMaterial = m
        } label: {
        VStack(alignment: .leading, spacing: 8) {
          if !m.receiptUploaded {
            WarningBanner(
              message: "Receipt missing — this cost may be rejected or recharged.",
              symbol: "exclamationmark.triangle.fill", tint: Brand.red)
          }
          HStack {
            Text(m.supplier).font(.headline).foregroundStyle(Brand.ink)
            Spacer()
            Text(Fmt.gbp(m.total)).font(.headline).foregroundStyle(Brand.olive)
          }
          Text(m.description).font(.subheadline).foregroundStyle(Brand.inkSoft)
          HStack(spacing: 10) {
            StatusChip(text: "Chargeable: \(m.chargeable.rawValue)", color: Brand.blue)
            StatusChip(
              text: m.receiptUploaded ? "Receipt ✓" : "No receipt",
              color: m.receiptUploaded ? Brand.paidGreen : Brand.red)
          }
          HStack {
            Text(Fmt.date(m.date)).font(.caption).foregroundStyle(Brand.inkSoft)
            Spacer()
            // Costs count from the moment they're logged, so a misread figure
            // is live. Making the row obviously tappable is the whole safety
            // net — there's no approval queue to catch it later.
            Label("Edit", systemImage: "pencil")
              .font(.caption.weight(.semibold)).foregroundStyle(Brand.olive)
          }
        }
        .mpgCard()
        }
        .buttonStyle(.plain)
      }
    }
  }

  @ViewBuilder private var photosList: some View {
    let pics = (me.map { u in store.photos.filter { $0.userId == u.id } } ?? [])
      .sorted { $0.timestamp > $1.timestamp }
    if pics.isEmpty {
      EmptyStateView(
        symbol: "camera", title: "No photos yet",
        message: "Before, during and completed photos will appear here."
      ).mpgCard()
    } else {
      LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
        ForEach(pics) { p in
          VStack(spacing: 8) {
            Image(systemName: p.symbol)
              .font(.system(size: 34))
              .foregroundStyle(Brand.olive)
              .frame(maxWidth: .infinity)
              .frame(height: 90)
              .background(Brand.lightGreen, in: RoundedRectangle(cornerRadius: 12))
            Text(p.type.rawValue).font(.caption.weight(.semibold))
              .foregroundStyle(Brand.ink).lineLimit(1)
            Text(p.description).font(.caption2).foregroundStyle(Brand.inkSoft)
              .lineLimit(2).multilineTextAlignment(.center)
          }
          .padding(10)
          .frame(maxWidth: .infinity)
          .mpgCard(padding: 8)
        }
      }
    }
  }
}

#Preview {
  TradesmanRecordsView().environment(
    {
      let s = AppStore()
      s.login(as: s.tradesmen().first!)
      return s
    }())
}
