import SwiftUI

struct AllocationDetailView: View {
  @Environment(AppStore.self) private var store
  let allocation: WorkAllocation

  @State private var showRecord = false
  @State private var showMaterials = false
  @State private var showPhotos = false
  @State private var showRequest = false

  private var live: WorkAllocation {
    store.allocations.first { $0.id == allocation.id } ?? allocation
  }

  var body: some View {
    Group {
      ZStack {
        MPGBackground()
        ScrollView {
          VStack(spacing: 16) {
            detailCard
            JobProgressControl(allocation: live).mpgCard()
            if live.requiredPhotos {
              WarningBanner(
                message: "Before and after photos are required for this task.",
                symbol: "camera.fill", tint: Brand.amber)
            }
            actionButtons
          }
          .padding(16)
        }
      }
      .navigationTitle("Job Details")
      .navigationBarTitleDisplayMode(.inline)
      .sheet(isPresented: $showRecord) { DailyRecordFormView(allocation: live) }
      .sheet(isPresented: $showMaterials) { MaterialFormView(allocation: live) }
      .sheet(isPresented: $showPhotos) { PhotoCaptureView(allocation: live) }
      .sheet(isPresented: $showRequest) { MaterialRequestForm(allocation: live) }
    }
    .__tenxTrackView("AllocationDetailView")
  }

  private var detailCard: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        StatusChip(text: live.status.rawValue, color: live.status.color, filled: true)
        Spacer()
        StatusChip(text: live.priority.rawValue, color: live.priority.color)
      }
      VStack(alignment: .leading, spacing: 3) {
        Text(store.site(live.siteId)?.name ?? "Site").font(.title3.bold()).foregroundStyle(
          Brand.ink)
        Text(store.site(live.siteId)?.address ?? "").font(.footnote).foregroundStyle(Brand.inkSoft)
      }
      Text(live.taskDescription).font(.subheadline).foregroundStyle(Brand.ink)

      VStack(spacing: 10) {
        InfoRow(label: "Date", value: Fmt.date(live.date), symbol: "calendar")
        InfoRow(label: "Start", value: live.startTime, symbol: "clock")
        InfoRow(
          label: "Expected finish", value: live.expectedFinish, symbol: "clock.badge.checkmark")
        InfoRow(label: "Trade", value: live.trade, symbol: "hammer")
        InfoRow(label: "Category", value: live.category.rawValue, symbol: "square.grid.2x2")
        if let sm = live.siteManagerId.flatMap(store.user) {
          InfoRow(label: "Site manager", value: sm.name, symbol: "person.bust")
        }
        if !live.requiredMaterials.isEmpty {
          InfoRow(label: "Materials", value: live.requiredMaterials, symbol: "shippingbox")
        }
      }
      .padding(.top, 2)

      if !live.notes.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
          Text("NOTES FROM ADMIN").font(.caption2.bold()).foregroundStyle(Brand.olive)
          Text(live.notes).font(.footnote).foregroundStyle(Brand.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .mpgFormSection(padding: 12)
      }
    }
    .mpgCard()
  }

  @ViewBuilder private var actionButtons: some View {
    VStack(spacing: 10) {
      if live.status == .allocated {
        PrimaryButton(title: "Accept Work", symbol: "checkmark.circle.fill") {
          store.updateAllocationStatus(live.id, to: .accepted)
        }
      } else if live.status == .accepted {
        PrimaryButton(title: "Start Day", symbol: "play.circle.fill", tint: Brand.amber) {
          store.updateAllocationStatus(live.id, to: .started)
        }
      }

      HStack(spacing: 10) {
        actionTile("Take Photo", "camera.fill") { showPhotos = true }
        actionTile("Add Materials", "shippingbox.fill") { showMaterials = true }
      }
      HStack(spacing: 10) {
        actionTile("Ask for Materials", "cart.badge.plus") { showRequest = true }
        actionTile("Log What I Did", "square.and.pencil") { showRecord = true }
      }
      PrimaryButton(
        title: "Add / Submit Daily Record", symbol: "square.and.pencil", tint: Brand.charcoal
      ) {
        showRecord = true
      }
    }
  }

  private func actionTile(_ title: String, _ symbol: String, action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) {
      VStack(spacing: 8) {
        Image(systemName: symbol).font(.title2)
        Text(title).font(.subheadline.weight(.semibold))
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 18)
      .foregroundStyle(Brand.olive)
      .background(Brand.lightGreen, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    .buttonStyle(.plain)
  }
}
