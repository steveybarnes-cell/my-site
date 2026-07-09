import SwiftUI

/// Shows exactly what the AI read from a receipt so the tradesman can check and
/// adjust every value before it is applied to the material form. Nothing is
/// written to the form until they tap "Use these details".
struct ReceiptReviewSheet: View {
  @Environment(\.dismiss) private var dismiss

  let scanned: ReceiptScanService.ScannedReceipt
  /// Called with the approved (possibly edited) values.
  let onApprove: (ApprovedReceipt) -> Void

  struct ApprovedReceipt {
    var supplier: String
    var description: String
    var costExVat: Double
    var vatAmount: Double
    var purchaseDate: Date
  }

  @State private var supplier: String
  @State private var description: String
  @State private var costExVat: String
  @State private var vatAmount: String
  @State private var purchaseDate: Date

  init(
    scanned: ReceiptScanService.ScannedReceipt,
    onApprove: @escaping (ApprovedReceipt) -> Void
  ) {
    self.scanned = scanned
    self.onApprove = onApprove

    _supplier = State(initialValue: scanned.supplier ?? "")
    _description = State(initialValue: scanned.description ?? "")

    let net: Double
    if let n = scanned.costExVat, n > 0 {
      net = n
    } else if let total = scanned.total, total > 0 {
      net = total / 1.20
    } else {
      net = 0
    }
    _costExVat = State(initialValue: net > 0 ? String(format: "%.2f", net) : "")

    let vat = scanned.vatAmount ?? (net > 0 ? net * 0.20 : 0)
    _vatAmount = State(initialValue: vat > 0 ? String(format: "%.2f", vat) : "")
    _purchaseDate = State(initialValue: scanned.purchaseDate ?? Date())
  }

  private var net: Double { Double(costExVat) ?? 0 }
  private var vat: Double { Double(vatAmount) ?? 0 }

  var body: some View {
    NavigationStack {
      ZStack {
        MPGBackground()
        ScrollView {
          VStack(spacing: 16) {
            header
            fieldsSection
            totalSection
            actions
          }
          .padding(16)
        }
      }
      .navigationTitle("Check AI take-off")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Discard") { dismiss() }
        }
      }
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("Read from your receipt", systemImage: "sparkles")
        .font(.subheadline.weight(.semibold)).foregroundStyle(Brand.olive)
      Text(
        "Please check every figure against the paper receipt before you use it. Tap any field to correct it."
      )
      .font(.caption).foregroundStyle(Brand.inkSoft)
      if let c = scanned.confidence {
        Text("AI confidence: \(Int((c * 100).rounded()))%")
          .font(.caption2.weight(.medium)).foregroundStyle(Brand.inkSoft)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .mpgFormSection()
  }

  private var fieldsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Details")
      labelledField("Supplier", "e.g. Screwfix", $supplier)
      labelledField("Description", "What was bought", $description)
      amountRow("Cost ex VAT (£)", $costExVat)
      amountRow("VAT (£)", $vatAmount)
      HStack {
        Text("Purchase date").font(.subheadline).foregroundStyle(Brand.ink)
        Spacer()
        DatePicker("", selection: $purchaseDate, displayedComponents: .date)
          .labelsHidden()
      }
    }
    .mpgFormSection()
  }

  private var totalSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      InfoRow(label: "Total (inc VAT)", value: Fmt.gbp(net + vat))
    }
    .mpgFormSection()
  }

  private var actions: some View {
    VStack(spacing: 10) {
      PrimaryButton(title: "Use these details", symbol: "checkmark") {
        onApprove(
          ApprovedReceipt(
            supplier: supplier, description: description,
            costExVat: net, vatAmount: vat, purchaseDate: purchaseDate))
        dismiss()
      }
      Button("Enter manually instead") { dismiss() }
        .font(.subheadline).foregroundStyle(Brand.inkSoft)
    }
  }

  private func labelledField(_ label: String, _ placeholder: String, _ binding: Binding<String>)
    -> some View
  {
    VStack(alignment: .leading, spacing: 4) {
      Text(label).font(.caption).foregroundStyle(Brand.inkSoft)
      TextField(placeholder, text: binding)
        .font(.subheadline).padding(11)
        .background(.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
  }

  private func amountRow(_ label: String, _ binding: Binding<String>) -> some View {
    HStack {
      Text(label).font(.subheadline).foregroundStyle(Brand.ink)
      Spacer()
      TextField("0.00", text: binding)
        .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
        .frame(width: 100).padding(8)
        .background(.white, in: RoundedRectangle(cornerRadius: 10))
    }
  }
}
