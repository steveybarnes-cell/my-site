import SwiftUI

struct MaterialFormView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let allocation: WorkAllocation

    @State private var supplier = ""
    @State private var description = ""
    @State private var reason = ""
    @State private var costExVat = ""
    @State private var receiptUploaded = false
    @State private var chargeable: Chargeable = .tbc

    private var cost: Double { Double(costExVat) ?? 0 }
    private var vat: Double { cost * 0.20 }

    var body: some View {
        Group {
            NavigationStack {
                ZStack {
                    MPGBackground()
                    ScrollView {
                        VStack(spacing: 16) {
                            if !receiptUploaded && cost > 0 {
                                WarningBanner(message: "Receipt missing — this cost may not be reimbursed. No VAT receipt or supplier invoice means the material cost may be rejected, deducted or recharged.",
                                              symbol: "exclamationmark.triangle.fill", tint: Brand.red)
                            }
                            detailsSection
                            costSection
                            chargeSection
                            PrimaryButton(title: "Add Material", symbol: "plus") { save() }
                                .disabled(supplier.isEmpty || cost <= 0)
                                .opacity(supplier.isEmpty || cost <= 0 ? 0.5 : 1)
                        }
                        .padding(16)
                    }
                }
                .navigationTitle("Add Materials")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
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
            Toggle(isOn: $receiptUploaded) {
                Label("Receipt / supplier invoice uploaded", systemImage: "doc.text.viewfinder")
                    .font(.subheadline).foregroundStyle(Brand.ink)
            }
            .tint(Brand.olive)
        }
        .mpgFormSection()
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
        let m = MaterialItem(id: UUID(), userId: me.id, siteId: allocation.siteId, dailyRecordId: nil,
                             date: Date(), supplier: supplier, description: description, reason: reason,
                             costExVat: cost, vatAmount: vat, receiptUploaded: receiptUploaded,
                             chargeable: chargeable, approved: false, notes: "")
        store.addMaterial(m)
        if !receiptUploaded {
            store.notify(me.id, type: "Receipt", message: "Receipt missing for \(supplier) purchase.", symbol: "exclamationmark.triangle.fill")
        }
        dismiss()
    }
}
