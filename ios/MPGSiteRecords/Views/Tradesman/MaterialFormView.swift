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

  private var cost: Double { Double(costExVat) ?? 0 }
  private var vat: Double { cost * 0.20 }
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
          CameraCaptureView { hasReceipt = true }
        }
        .onChange(of: pickerItem) { _, newValue in hasReceipt = newValue != nil }
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
      }
      InfoRow(label: "VAT (20%)", value: Fmt.gbp(vat))
      InfoRow(label: "Total", value: Fmt.gbp(cost + vat))
    }
    .mpgFormSection()
  }

  // MARK: - Receipt capture

  private var receiptSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Receipt / supplier invoice")

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

  private func save() {
    guard let me = store.currentUser else { return }
    let materialId = UUID()
    let m = MaterialItem(
      id: materialId, userId: me.id, siteId: allocation.siteId, dailyRecordId: nil,
      date: Date(), supplier: supplier, description: description, reason: reason,
      costExVat: cost, vatAmount: vat, receiptUploaded: hasReceipt,
      chargeable: chargeable, approved: false, notes: "")
    store.addMaterial(m)

    if hasReceipt, let site {
      let receiptDesc = "Receipt — \(supplier)"
      let uploaded = store.uploadFile(
        type: receiptType, description: receiptDesc, source: source, ext: "jpg",
        site: site, allocation: allocation, dailyRecordId: nil, submissionId: nil,
        materialId: materialId)
      // Auto-push to Hubdoc / Xero + central cost tracker when connected.
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
