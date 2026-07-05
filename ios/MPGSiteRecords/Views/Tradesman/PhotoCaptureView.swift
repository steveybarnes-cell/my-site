import SwiftUI

struct PhotoCaptureView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  let allocation: WorkAllocation

  @State private var type: PhotoType = .before
  @State private var description = ""

  private let symbolFor: [PhotoType: String] = [
    .before: "photo", .during: "photo.stack", .completed: "photo.fill",
    .variation: "photo.badge.checkmark", .snagging: "exclamationmark.triangle",
    .delay: "clock.badge.exclamationmark", .damage: "hammer", .materials: "shippingbox",
    .receipt: "doc.text.viewfinder", .other: "photo",
  ]

  var body: some View {
      Group {
              NavigationStack {
          ZStack {
            MPGBackground()
            ScrollView {
              VStack(spacing: 16) {
                cameraPlaceholder
                typeSection
                detailsSection
                PrimaryButton(title: "Save Photo", symbol: "checkmark") { save() }
              }
              .padding(16)
            }
          }
          .navigationTitle("Add Photo")
          .navigationBarTitleDisplayMode(.inline)
          .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
              }
      }
      .__tenxTrackView("PhotoCaptureView")
  }

  private var cameraPlaceholder: some View {
    VStack(spacing: 10) {
      Image(systemName: "camera.viewfinder").font(.system(size: 54)).foregroundStyle(Brand.olive)
      Text("Tap to capture").font(.subheadline.weight(.semibold)).foregroundStyle(Brand.ink)
      Text("Photos are timestamped and linked to this job automatically.")
        .font(.caption).foregroundStyle(Brand.inkSoft).multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(30)
    .background(Brand.lightGreen, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  private var typeSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Photo type")
      Picker("Type", selection: $type) {
        ForEach(PhotoType.allCases) { Text($0.rawValue).tag($0) }
      }
      .pickerStyle(.menu)
      .tint(Brand.olive)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .mpgFormSection()
  }

  private var detailsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Description")
      TextField("What does this photo show?", text: $description, axis: .vertical)
        .lineLimit(2...4)
        .font(.subheadline)
        .padding(12)
        .background(.white, in: RoundedRectangle(cornerRadius: 12))
    }
    .mpgFormSection()
  }

  private func save() {
    let photo = SitePhoto(
      id: UUID(), userId: store.currentUser?.id ?? allocation.tradesmanId,
      siteId: allocation.siteId, allocationId: allocation.id, type: type,
      description: description.isEmpty ? type.rawValue : description,
      symbol: symbolFor[type] ?? "photo", timestamp: Date())
    store.addPhoto(photo)
    dismiss()
  }
}

#Preview {
  PhotoCaptureView(allocation: AppStore().allocations[0]).environment(AppStore())
}
