import PhotosUI
import SwiftUI

/// Scan an invoice or receipt from anywhere in the app.
///
/// The AI scan previously only existed inside `PhotoCaptureView`, which is
/// reachable from a single place — a tradesman opening one work allocation —
/// and only fired as a side effect of changing the file type to Receipt. Office
/// staff had no route to it at all. This is the same capture-and-scan pipeline
/// with no allocation required, so every role can reach it in one tap.
struct ScanReceiptView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss

  /// True when shown as a sheet: adds its own navigation chrome and a Cancel
  /// button. False when pushed from the More hub, which supplies both already.
  var presentedModally = true

  @State private var type: PhotoType = .receipt
  @State private var selectedSiteId: UUID?
  @State private var details = ""
  @State private var imageData: Data?
  @State private var showCamera = false
  @State private var pickerItem: PhotosPickerItem?

  @State private var isScanning = false
  @State private var scanError: String?
  @State private var scanNote: String?
  @State private var pendingScan: ReceiptScanService.ScannedReceipt?

  // MARK: - Scope

  /// Sites this user may file evidence against, matching the app's privacy
  /// rules so the picker never offers a site they can't see.
  private var availableSites: [Site] {
    guard let me = store.currentUser else { return store.sites }
    switch me.role {
    case .admin:
      return store.sites
    case .siteManager:
      let mine = store.sitesManaged(by: me.id)
      return mine.isEmpty ? store.sites : mine
    case .tradesman:
      let ids = Set(store.allocations.filter { $0.tradesmanId == me.id }.map(\.siteId))
      let mine = store.sites.filter { ids.contains($0.id) }
      return mine.isEmpty ? store.sites : mine
    }
  }

  private var site: Site? {
    selectedSiteId.flatMap { id in availableSites.first { $0.id == id } }
  }

  private var hasImage: Bool { imageData != nil }
  private var canSave: Bool { hasImage && site != nil && !isScanning }

  // MARK: - Body

  var body: some View {
    Group {
      if presentedModally {
        NavigationStack {
          content
            .navigationTitle("Scan Invoice / Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
              ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
              }
            }
        }
      } else {
        content
          .navigationTitle("Scan Invoice / Receipt")
          .navigationBarTitleDisplayMode(.inline)
      }
    }
    .__tenxTrackView("ScanReceiptView")
  }

  private var content: some View {
    ZStack {
      MPGBackground()
      ScrollView {
        VStack(spacing: 16) {
          captureCard
          typeCard
          siteCard
          detailsCard

          PrimaryButton(title: "Upload to Drive", symbol: "arrow.up.doc") { save() }
            .disabled(!canSave)
            .opacity(canSave ? 1 : 0.5)
            .animation(.snappy(duration: 0.2), value: canSave)
        }
        .padding(16)
      }
    }
    .sheet(isPresented: $showCamera) {
      CameraCaptureView { data in
        imageData = data
        scan()
      }
    }
    .sheet(item: $pendingScan) { scanned in
      ReceiptReviewSheet(scanned: scanned) { approved in
        apply(approved)
      }
    }
    .onChange(of: pickerItem) { _, item in
      guard let item else { return }
      Task {
        if let data = try? await item.loadTransferable(type: Data.self) {
          imageData = data
          scan()
        }
      }
    }
    .onAppear {
      if selectedSiteId == nil { selectedSiteId = availableSites.first?.id }
    }
  }

  // MARK: - Capture

  private var captureCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(
        title: "Capture",
        subtitle: hasImage
          ? "Captured — check the details below before uploading"
          : "Photograph the invoice or receipt, or pick one from your library")

      HStack(spacing: 10) {
        Button {
          showCamera = true
        } label: {
          sourceButton(
            symbol: hasImage ? "checkmark.circle.fill" : "doc.text.viewfinder",
            title: hasImage ? "Retake" : "Scan now",
            tint: hasImage ? Brand.paidGreen : Brand.olive)
        }
        .buttonStyle(.plain)

        PhotosPicker(selection: $pickerItem, matching: .images) {
          sourceButton(
            symbol: "photo.on.rectangle.angled", title: "From library", tint: Brand.olive)
        }
        .buttonStyle(.plain)
      }

      if isScanning {
        Label("Reading it with AI…", systemImage: "sparkles")
          .font(.caption).foregroundStyle(Brand.olive)
          .frame(maxWidth: .infinity, alignment: .leading)
      } else if let scanNote {
        Label(scanNote, systemImage: "checkmark.seal.fill")
          .font(.caption).foregroundStyle(Brand.paidGreen)
          .frame(maxWidth: .infinity, alignment: .leading)
      } else if let scanError {
        Label(scanError, systemImage: "exclamationmark.triangle.fill")
          .font(.caption).foregroundStyle(Brand.red)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .mpgCard()
  }

  private func sourceButton(symbol: String, title: String, tint: Color) -> some View {
    VStack(spacing: 7) {
      Image(systemName: symbol).font(.system(size: 26)).foregroundStyle(tint)
      Text(title).font(.caption.weight(.semibold)).foregroundStyle(Brand.ink)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 20)
    .background(
      RoundedRectangle(cornerRadius: Brand.Radius.inner, style: .continuous)
        .fill(Brand.lightGreen.opacity(0.6))
    )
    .overlay(
      RoundedRectangle(cornerRadius: Brand.Radius.inner, style: .continuous)
        .stroke(Brand.hairline, lineWidth: 1)
    )
  }

  // MARK: - Type / site / details

  private var typeCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      SectionHeader(title: "What is it?")
      Picker("Type", selection: $type) {
        Text("Receipt").tag(PhotoType.receipt)
        Text("Supplier invoice").tag(PhotoType.supplierInvoice)
      }
      .pickerStyle(.segmented)
      if let register = type.linkedRegister {
        WarningBanner(
          message: "This file will also be linked to the \(register).",
          symbol: "link", tint: Brand.blue)
      }
    }
    .mpgCard()
  }

  private var siteCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      SectionHeader(title: "Site", subtitle: "Which job is this spend against?")
      if availableSites.isEmpty {
        Text("No sites available to file against.")
          .font(.caption).foregroundStyle(Brand.inkSoft)
          .frame(maxWidth: .infinity, alignment: .leading)
      } else {
        Menu {
          ForEach(availableSites) { s in
            Button(s.name) { selectedSiteId = s.id }
          }
        } label: {
          HStack {
            Image(systemName: "mappin.and.ellipse").foregroundStyle(Brand.olive)
            Text(site?.name ?? "Choose a site").foregroundStyle(Brand.ink)
            Spacer()
            Image(systemName: "chevron.up.chevron.down").font(.caption)
              .foregroundStyle(Brand.inkSoft)
          }
          .font(.subheadline)
          .padding(.vertical, 12)
          .padding(.horizontal, 14)
          .background(
            RoundedRectangle(cornerRadius: Brand.Radius.inner, style: .continuous)
              .fill(Brand.lightGreen.opacity(0.5))
          )
          .overlay(
            RoundedRectangle(cornerRadius: Brand.Radius.inner, style: .continuous)
              .stroke(Brand.hairline, lineWidth: 1)
          )
        }
      }
    }
    .mpgCard()
  }

  private var detailsCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      SectionHeader(title: "Details", subtitle: "Filled in by the scan — check it")
      TextField("Supplier, what it was for, amount", text: $details, axis: .vertical)
        .lineLimit(2...4)
        .font(.subheadline)
        .padding(12)
        .background(.white, in: RoundedRectangle(cornerRadius: 12))
    }
    .mpgCard()
  }

  // MARK: - Scan

  private func scan() {
    guard let data = imageData else { return }
    guard let token = store.currentBackendToken else {
      scanError = "Sign in to your live account to auto-read receipts. You can still upload it."
      return
    }
    scanError = nil
    scanNote = nil
    isScanning = true
    Task { @MainActor in
      defer { isScanning = false }
      do {
        pendingScan = try await ReceiptScanService.scan(imageData: data, token: token)
      } catch {
        scanError = "Couldn't read it automatically. Enter the details manually."
      }
    }
  }

  private func apply(_ approved: ReceiptReviewSheet.ApprovedReceipt) {
    var parts: [String] = []
    if !approved.supplier.isEmpty { parts.append(approved.supplier) }
    if !approved.description.isEmpty { parts.append(approved.description) }
    let gross = approved.costExVat + approved.vatAmount
    if gross > 0 { parts.append(String(format: "£%.2f inc VAT", gross)) }
    details = parts.joined(separator: " — ")
    scanNote = "Details filled from the scan — please check them."
  }

  // MARK: - Save

  private func save() {
    guard let site else { return }
    store.uploadFile(
      type: type,
      description: details,
      source: .camera,
      ext: "jpg",
      site: site,
      imageData: imageData)
    dismiss()
  }
}

/// Lets `ScannedReceipt` drive `.sheet(item:)`.
extension ReceiptScanService.ScannedReceipt: Identifiable {
  var id: String { "\(supplier ?? "")|\(total ?? 0)|\(date ?? "")" }
}

// MARK: - Entry point card

/// Prominent "Scan invoice / receipt" action for a role's home screen.
struct ScanReceiptCard: View {
  @State private var show = false

  var body: some View {
    Button {
      show = true
    } label: {
      HStack(spacing: 14) {
        Image(systemName: "doc.text.viewfinder")
          .font(.title2)
          .foregroundStyle(.white)
          .frame(width: 46, height: 46)
          .background(Brand.olive, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        VStack(alignment: .leading, spacing: 3) {
          Text("Scan invoice / receipt")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Brand.ink)
          Text("Photograph it — the details are read for you")
            .font(.caption)
            .foregroundStyle(Brand.inkSoft)
        }
        Spacer()
        Image(systemName: "chevron.right")
          .font(.caption.weight(.semibold))
          .foregroundStyle(Brand.inkSoft)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .mpgCard()
    }
    .buttonStyle(.plain)
    .sheet(isPresented: $show) {
      ScanReceiptView()
    }
  }
}

#Preview {
  ScanReceiptView().environment(
    {
      let s = AppStore()
      s.login(as: s.users.first!)
      return s
    }())
}
