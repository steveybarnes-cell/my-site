import PhotosUI
import SwiftUI

struct MaterialFormView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  let allocation: WorkAllocation

  @State private var supplier = ""
  @State private var description = ""
  @State private var reason = ""
  @State private var costExVat = ""
  @State private var chargeable: Chargeable = .tbc

  // Receipt capture
  @State private var receiptType: PhotoType = .receipt
  @State private var source: CaptureSource = .camera
  @State private var pickerItem: PhotosPickerItem?
  @State private var hasReceipt = false
  @State private var showCamera = false

  // AI receipt scan
  @State private var receiptData: Data?
  @State private var purchaseDate = Date()
  @State private var vatOverride: Double?
  @State private var isScanning = false
  @State private var scanError: String?
  @State private var scanNote: String?
  @State private var pendingScan: ReceiptScanService.ScannedReceipt?
  @State private var showReview = false

  private var cost: Double { Double(costExVat) ?? 0 }
  private var vat: Double { vatOverride ?? (cost * 0.20) }
  private var site: Site? { store.site(allocation.siteId) }
  private var isInvalid: Bool { supplier.isEmpty || cost <= 0 }

  var body: some View {
    Group {
      NavigationStack {
        ZStack {
          MPGBackground()
          ScrollView {
            VStack(spacing: 16) {
              if !hasReceipt && cost > 0 {
                WarningBanner(
                  message:
                    "Receipt missing — this cost may not be reimbursed. No VAT receipt or supplier invoice means the material cost may be rejected, deducted or recharged.",
                  symbol: "exclamationmark.triangle.fill", tint: Brand.red)
              }
              detailsSection
              costSection
              receiptSection
              chargeSection
              PrimaryButton(title: "Add Material", symbol: "plus") { save() }
                .disabled(isInvalid)
                .opacity(isInvalid ? 0.5 : 1)
            }
            .padding(16)
          }
        }
        .navigationTitle("Add Materials")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        .sheet(isPresented: $showCamera) {
          CameraCaptureView { data in
            receiptData = data
            hasReceipt = true
            scan()
          }
        }
        .onChange(of: pickerItem) { _, newValue in
          guard let newValue else {
            hasReceipt = false
            return
          }
          Task {
            if let data = try? await newValue.loadTransferable(type: Data.self) {
              receiptData = data
              hasReceipt = true
              scan()
            }
          }
        }
        .sheet(isPresented: $showReview) {
          if let pendingScan {
            ReceiptReviewSheet(scanned: pendingScan) { approved in
              supplier = approved.supplier
              if !approved.description.isEmpty { description = approved.description }
              if approved.costExVat > 0 {
                costExVat = String(format: "%.2f", approved.costExVat)
              }
              vatOverride = approved.vatAmount > 0 ? approved.vatAmount : nil
              purchaseDate = approved.purchaseDate
              scanNote = "Approved from receipt take-off."
            }
          }
        }
      }
    }
    .__tenxTrackView("MaterialFormView")
  }

  private var detailsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Purchase details")
      field("Supplier (e.g. Screwfix)", $supplier)
      field("Description", $description)
      field("Reason for purchase", $reason)
    }
    .mpgFormSection()
  }

  private var costSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Cost")
      HStack {
        Text("Cost ex VAT (£)").font(.subheadline).foregroundStyle(Brand.ink)
        Spacer()
        TextField("0.00", text: $costExVat)
          .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
          .frame(width: 100).padding(8)
          .background(.white, in: RoundedRectangle(cornerRadius: 10))
          .onChange(of: costExVat) { _, _ in vatOverride = nil }
      }
      InfoRow(label: "VAT (20%)", value: Fmt.gbp(vat))
      InfoRow(label: "Total", value: Fmt.gbp(cost + vat))
      HStack {
        Text("Purchase date").font(.subheadline).foregroundStyle(Brand.ink)
        Spacer()
        DatePicker("", selection: $purchaseDate, displayedComponents: .date)
          .labelsHidden()
      }
    }
    .mpgFormSection()
  }

  // MARK: - Receipt capture

  private var receiptSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(
        title: "Receipt / supplier invoice",
        subtitle:
          "Photograph it — AI reads the details and it uploads to Hubdoc / Xero automatically")

      if isScanning {
        Label("Reading receipt with AI…", systemImage: "sparkles")
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

      Picker("Type", selection: $receiptType) {
        Text("Receipt").tag(PhotoType.receipt)
        Text("Supplier invoice").tag(PhotoType.supplierInvoice)
      }
      .pickerStyle(.segmented)

      Picker("Source", selection: $source) {
        ForEach(CaptureSource.allCases) { Label($0.rawValue, systemImage: $0.symbol).tag($0) }
      }
      .pickerStyle(.segmented)

      if source == .camera {
        Button {
          showCamera = true
        } label: {
          captureCard
        }
        .buttonStyle(.plain)
      } else {
        PhotosPicker(selection: $pickerItem, matching: .images) { captureCard }
          .buttonStyle(.plain)
      }

      if store.xeroConnected {
        Label(
          "Receipt will be sent to Hubdoc / Xero and the central cost tracker automatically.",
          systemImage: "arrow.up.doc.on.clipboard"
        )
        .font(.caption).foregroundStyle(Brand.olive)
        .frame(maxWidth: .infinity, alignment: .leading)
      } else {
        Label(
          "Connect Xero in Admin → Profile → Integrations to auto-send receipts to Hubdoc / Xero.",
          systemImage: "info.circle"
        )
        .font(.caption).foregroundStyle(Brand.inkSoft)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .mpgFormSection()
  }

  private var captureCard: some View {
    VStack(spacing: 10) {
      Image(
        systemName: hasReceipt
          ? "checkmark.circle.fill"
          : (source == .camera ? "camera.viewfinder" : "photo.on.rectangle.angled")
      )
      .font(.system(size: 46))
      .foregroundStyle(hasReceipt ? Brand.paidGreen : Brand.olive)
      Text(
        hasReceipt
          ? "Receipt captured"
          : (source == .camera ? "Photograph receipt" : "Choose from gallery")
      )
      .font(.subheadline.weight(.semibold)).foregroundStyle(Brand.ink)
      Text("Timestamped and linked to this purchase automatically.")
        .font(.caption).foregroundStyle(Brand.inkSoft).multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(24)
    .background(Brand.lightGreen, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  private var chargeSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Chargeable to client")
      Picker("Chargeable", selection: $chargeable) {
        ForEach(Chargeable.allCases) { Text($0.rawValue).tag($0) }
      }
      .pickerStyle(.segmented)
    }
    .mpgFormSection()
  }

  private func field(_ placeholder: String, _ binding: Binding<String>) -> some View {
    TextField(placeholder, text: binding)
      .font(.subheadline).padding(11)
      .background(.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
  }

  private func scan() {
    guard let data = receiptData else { return }
    guard let token = store.currentBackendToken else {
      scanError = "Sign in to your live account to auto-read receipts."
      return
    }
    scanError = nil
    scanNote = nil
    isScanning = true
    Task { @MainActor in
      defer { isScanning = false }
      do {
        let r = try await ReceiptScanService.scan(imageData: data, token: token)
        pendingScan = r
        showReview = true
        scanNote = "Check the AI take-off before it fills the form."
      } catch {
        // See ScanReceiptView — a generic message here hid an OpenAI billing
        // failure behind what looked like a bad photo.
        let reason = (error as? SupabaseError)?.errorDescription ?? error.localizedDescription
        scanError = "Couldn't read the receipt — \(reason) Enter the details manually."
      }
    }
  }

  private func save() {
    guard let me = store.currentUser else { return }
    let materialId = UUID()
    let m = MaterialItem(
      id: materialId, userId: me.id, siteId: allocation.siteId, dailyRecordId: nil,
      date: purchaseDate, supplier: supplier, description: description, reason: reason,
      costExVat: cost, vatAmount: vat, receiptUploaded: hasReceipt,
      chargeable: chargeable, approved: false, notes: "")
    store.addMaterial(m)

    if hasReceipt, let site {
      let receiptDesc = "Receipt — \(supplier)"
      // receiptData is the photographed receipt. It was being dropped here,
      // so the row was created but the bucket stayed empty — the evidence the
      // whole screen exists to capture never actually left the phone.
      let uploaded = store.uploadFile(
        type: receiptType, description: receiptDesc, source: source, ext: "jpg",
        site: site, allocation: allocation, dailyRecordId: nil, submissionId: nil,
        materialId: materialId, imageData: receiptData)
      // Auto-push to Hubdoc / Xero + central cost tracker when connected.
      // Hubdoc is independent of Xero: the receipt is emailed to the company's
      // Hubdoc inbox whether or not Xero has been connected, and does nothing
      // quietly if no Hubdoc address has been set.
      store.sendToHubdoc(uploaded.id)
      if store.xeroConnected {
        store.sendToXero(uploaded.id)
      }
    } else {
      store.notify(
        me.id, type: "Receipt", message: "Receipt missing for \(supplier) purchase.",
        symbol: "exclamationmark.triangle.fill")
    }
    dismiss()
  }
}

#Preview {
  MaterialFormView(allocation: AppStore().allocations[0]).environment(AppStore())
}

// =====================================================================
// MARK: - Correcting a logged cost
// =====================================================================

/// Edit a material that has already been logged.
///
/// There is no approval queue in this app — a cost counts from the moment it
/// is logged, so site spend and the weekly totals are always current rather
/// than current-as-of-whenever somebody last signed things off.
///
/// That only works if mistakes are cheap to fix, which is what this is for. An
/// AI reading a crumpled receipt will occasionally put the VAT in the wrong
/// box; correcting it here moves every total that derives from it, because
/// nothing caches spend — it's all computed from `materials` on read.
struct MaterialEditSheet: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss

  let material: MaterialItem

  @State private var supplier = ""
  @State private var description = ""
  @State private var reason = ""
  @State private var costText = ""
  @State private var vatText = ""
  @State private var date = Date()
  @State private var chargeable: Chargeable = .tbc
  @State private var siteId: UUID?

  private var cost: Double { Double(costText) ?? 0 }
  private var vat: Double { Double(vatText) ?? 0 }
  private var isInvalid: Bool { supplier.trimmingCharacters(in: .whitespaces).isEmpty || cost <= 0 }

  /// Only sites this person can already see, so an edit can't quietly move a
  /// cost onto a job they have no business touching.
  private var availableSites: [Site] {
    guard let me = store.currentUser else { return store.sites }
    switch me.role {
    case .admin: return store.sites
    case .siteManager:
      let mine = store.sitesManaged(by: me.id)
      return mine.isEmpty ? store.sites : mine
    case .tradesman:
      let ids = Set(store.allocations.filter { $0.tradesmanId == me.id }.map(\.siteId))
      let mine = store.sites.filter { ids.contains($0.id) }
      return mine.isEmpty ? store.sites : mine
    }
  }

  var body: some View {
    NavigationStack {
      ZStack {
        MPGBackground()
        ScrollView {
          VStack(spacing: 16) {
            details
            money
            allocation
            PrimaryButton(title: "Save Changes", symbol: "checkmark") { save() }
              .disabled(isInvalid)
              .opacity(isInvalid ? 0.5 : 1)
          }
          .padding(16)
        }
      }
      .navigationTitle("Edit Cost")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
      }
      .onAppear(perform: load)
    }
    .__tenxTrackView("MaterialEditSheet")
  }

  private var details: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Purchase")
      Field(label: "Supplier", text: $supplier)
      Field(label: "What it was for", text: $description)
      Field(label: "Reason (optional)", text: $reason)
      HStack {
        Text("Purchase date").font(.subheadline).foregroundStyle(Brand.ink)
        Spacer()
        DatePicker("", selection: $date, displayedComponents: .date).labelsHidden()
      }
    }
    .mpgFormSection()
  }

  private var money: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(
        title: "Cost",
        subtitle: "Net and VAT separately — this is what feeds the spend tracker")

      amountRow("Net (ex VAT)", $costText)
      amountRow("VAT", $vatText)

      // Shown because the gross is what's printed on the receipt, and it's the
      // fastest way to spot a misread: if this doesn't match the paper, one of
      // the two boxes above is wrong.
      InfoRow(label: "Total (inc VAT)", value: Fmt.gbp(cost + vat))
    }
    .mpgFormSection()
  }

  private func amountRow(_ label: String, _ text: Binding<String>) -> some View {
    HStack {
      Text(label).font(.subheadline).foregroundStyle(Brand.ink)
      Spacer()
      Text("£").foregroundStyle(Brand.inkSoft)
      TextField("0.00", text: text)
        .keyboardType(.decimalPad)
        .multilineTextAlignment(.trailing)
        .frame(width: 100)
        .padding(8)
        .background(.white, in: RoundedRectangle(cornerRadius: 10))
    }
  }

  private var allocation: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Allocation", subtitle: "Which job this cost lands against")
      Picker("Site", selection: $siteId) {
        ForEach(availableSites) { Text($0.name).tag(Optional($0.id)) }
      }
      .pickerStyle(.menu)
      .tint(Brand.olive)

      Picker("Chargeable", selection: $chargeable) {
        ForEach(Chargeable.allCases) { Text($0.rawValue).tag($0) }
      }
      .pickerStyle(.segmented)
    }
    .mpgFormSection()
  }

  private func load() {
    supplier = material.supplier
    description = material.description
    reason = material.reason
    costText = String(format: "%.2f", material.costExVat)
    vatText = String(format: "%.2f", material.vatAmount)
    date = material.date
    chargeable = material.chargeable
    siteId = material.siteId
  }

  private func save() {
    var updated = material
    updated.supplier = supplier.trimmingCharacters(in: .whitespaces)
    updated.description = description.trimmingCharacters(in: .whitespaces)
    updated.reason = reason.trimmingCharacters(in: .whitespaces)
    updated.costExVat = cost
    updated.vatAmount = vat
    updated.date = date
    updated.chargeable = chargeable
    updated.siteId = siteId ?? material.siteId
    store.updateMaterial(updated)
    dismiss()
  }
}
