import SwiftUI

/// Full detail for one site file: metadata, register row, open link, approval, handover.
struct SiteFileDetailView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  let file: SiteFile

  private var live: SiteFile { store.siteFiles.first { $0.id == file.id } ?? file }

  var body: some View {
    Group {
      ScrollView {
        VStack(spacing: 16) {
          thumbnail
          openCard
          if store.canManageFiles { approvalCard }
          detailsCard
          registerCard
          if store.role == .admin {
            Button(role: .destructive) {
              store.deleteSiteFile(file.id)
              dismiss()
            } label: {
              Label("Delete file", systemImage: "trash")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Brand.red)
          }
        }
        .padding(16)
      }
      .background(MPGBackground())
      .navigationTitle("File Details")
      .navigationBarTitleDisplayMode(.inline)
    }
    .__tenxTrackView("SiteFileDetailView")
  }

  private var thumbnail: some View {
    VStack(spacing: 8) {
      Image(systemName: live.category.symbol).font(.system(size: 52)).foregroundStyle(Brand.olive)
      Text(live.title).font(.headline).foregroundStyle(Brand.ink)
        .multilineTextAlignment(.center)
      Label(live.approval.rawValue, systemImage: live.approval.symbol)
        .font(.caption.weight(.semibold)).foregroundStyle(live.approval.color)
      if live.inHandoverPack {
        StatusChip(text: "In handover pack", color: Brand.olive)
      }
    }
    .frame(maxWidth: .infinity)
    .padding(26)
    .background(Brand.lightGreen, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  private var openCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: live.origin == .driveLink ? "Google Drive link" : "Stored file")
      InfoRow(label: "Folder", value: live.driveFolderPath, symbol: "folder")
      InfoRow(label: "Type", value: live.fileType, symbol: "doc")
      if let url = URL(string: live.driveURL), !live.driveURL.isEmpty {
        Link(destination: url) {
          Label("Open in Google Drive", systemImage: "arrow.up.forward.app")
            .font(.subheadline.weight(.semibold)).foregroundStyle(Brand.olive)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Brand.lightGreen, in: RoundedRectangle(cornerRadius: 12))
        }
      }
    }
    .mpgCard()
  }

  private var approvalCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Review & handover")
      HStack(spacing: 8) {
        ForEach(FileApproval.allCases) { a in
          Button {
            store.setFileApproval(live.id, to: a)
          } label: {
            Text(a.rawValue).font(.caption.weight(.semibold))
              .frame(maxWidth: .infinity)
              .padding(.vertical, 10)
              .foregroundStyle(live.approval == a ? .white : a.color)
              .background(
                live.approval == a ? a.color : a.color.opacity(0.14),
                in: RoundedRectangle(cornerRadius: 10))
          }
          .buttonStyle(.plain)
        }
      }
      Toggle(
        isOn: Binding(get: { live.inHandoverPack }, set: { _ in store.toggleHandover(live.id) })
      ) {
        Label("Include in site handover pack", systemImage: "shippingbox")
          .font(.subheadline).foregroundStyle(Brand.ink)
      }
      .tint(Brand.olive)
    }
    .mpgCard()
  }

  private var detailsCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Details")
      InfoRow(label: "Site", value: store.site(live.siteId)?.name ?? "—", symbol: "building.2")
      InfoRow(label: "Category", value: live.category.rawValue, symbol: live.category.symbol)
      InfoRow(label: "Uploaded by", value: live.uploadedByName, symbol: "person")
      InfoRow(
        label: "Uploaded", value: live.uploadedAt.formatted(date: .abbreviated, time: .shortened),
        symbol: "calendar")
      InfoRow(label: "Visibility", value: live.visibility.rawValue, symbol: live.visibility.symbol)
      if let tid = live.tradesmanId, let name = store.user(tid)?.name {
        InfoRow(label: "Related tradesman", value: name, symbol: "hammer")
      }
      if !live.notes.isEmpty {
        InfoRow(label: "Notes", value: live.notes, symbol: "text.alignleft")
      }
      if !live.tags.isEmpty {
        InfoRow(label: "Tags", value: live.tags.joined(separator: ", "), symbol: "tag")
      }
    }
    .mpgCard()
  }

  private var registerCard: some View {
    let row = store.registerRow(for: live)
    return VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Site Files Register row")
      InfoRow(label: "File ID", value: row.fileId, symbol: "number")
      InfoRow(
        label: "Related allocation", value: row.relatedAllocation, symbol: "list.bullet.rectangle")
      InfoRow(label: "Related daily record", value: row.relatedDailyRecord, symbol: "doc.plaintext")
      InfoRow(label: "Related submission", value: row.relatedSubmission, symbol: "doc.text")
      InfoRow(label: "Related material", value: row.relatedMaterial, symbol: "shippingbox")
      InfoRow(
        label: "Related variation", value: row.relatedVariation, symbol: "photo.badge.checkmark")
      InfoRow(label: "Approval", value: row.approval, symbol: "checkmark.seal")
    }
    .mpgCard()
  }
}

/// Site handover pack builder + exportable index.
struct HandoverPackView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  let site: Site
  @State private var showIndex = false

  private var packFiles: [SiteFile] { store.handoverFiles(forSite: site.id) }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 16) {
          WarningBanner(
            message: "Mark files into the handover pack from each file's detail screen.",
            symbol: "shippingbox", tint: Brand.blue)
          if packFiles.isEmpty {
            EmptyStateView(
              symbol: "shippingbox", title: "No handover files yet",
              message:
                "Building control docs, certificates, warranties, drawings and completion evidence added to the pack will appear here."
            ).mpgCard()
          } else {
            VStack(alignment: .leading, spacing: 10) {
              SectionHeader(title: "\(packFiles.count) files in pack")
              ForEach(packFiles) { f in
                HStack(spacing: 10) {
                  Image(systemName: f.category.symbol).foregroundStyle(Brand.olive)
                    .frame(width: 26)
                  VStack(alignment: .leading, spacing: 2) {
                    Text(f.title).font(.subheadline.weight(.semibold)).foregroundStyle(Brand.ink)
                    Text(f.category.rawValue).font(.caption).foregroundStyle(Brand.inkSoft)
                  }
                  Spacer()
                  Label(f.approval.rawValue, systemImage: f.approval.symbol)
                    .labelStyle(.iconOnly).foregroundStyle(f.approval.color)
                }
                .padding(.vertical, 4)
              }
            }
            .mpgCard()
            if store.role == .admin {
              PrimaryButton(title: "Export handover index", symbol: "square.and.arrow.up") {
                showIndex = true
              }
            }
          }
        }
        .padding(16)
      }
      .background(MPGBackground())
      .navigationTitle("Handover Pack")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
      }
      .sheet(isPresented: $showIndex) {
        HandoverIndexView(site: site, files: packFiles)
      }
    }
  }
}

/// A simple exportable text index of the handover pack.
struct HandoverIndexView: View {
  @Environment(\.dismiss) private var dismiss
  let site: Site
  let files: [SiteFile]

  private var indexText: String {
    var lines = ["My Project Group Ltd — Site Handover Index", site.name, ""]
    for (i, f) in files.enumerated() {
      lines.append("\(i + 1). [\(f.category.rawValue)] \(f.title) — \(f.approval.rawValue)")
    }
    return lines.joined(separator: "\n")
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        Text(indexText)
          .font(.system(.footnote, design: .monospaced))
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(16)
          .mpgCard()
          .padding(16)
      }
      .background(MPGBackground())
      .navigationTitle("Handover Index")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          ShareLink(item: indexText) { Image(systemName: "square.and.arrow.up") }
        }
        ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } }
      }
    }
  }
}
