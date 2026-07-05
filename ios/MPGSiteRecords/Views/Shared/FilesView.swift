import SwiftUI

/// Role-aware file browser backed by Google Drive metadata.
/// Tradesman sees only their own files, site managers see their assigned sites, admin sees all.
struct FilesView: View {
  @Environment(AppStore.self) private var store
  @State private var typeFilter: PhotoType?

  private var files: [SitePhoto] {
    let all = store.visibleFiles()
    guard let t = typeFilter else { return all }
    return all.filter { $0.type == t }
  }

  var body: some View {
    Group {
      NavigationStack {
        ZStack {
          MPGBackground()
          ScrollView {
            VStack(spacing: 16) {
              scopeBanner
              filterBar
              if files.isEmpty {
                EmptyStateView(
                  symbol: "folder", title: "No files yet",
                  message:
                    "Photos, receipts and evidence uploaded to Google Drive will appear here."
                ).mpgCard()
              } else {
                ForEach(files) { file in
                  NavigationLink(value: file) { fileCard(file) }
                    .buttonStyle(.plain)
                }
              }
            }
            .padding(16)
          }
        }
        .navigationTitle("Files")
        .navigationDestination(for: SitePhoto.self) { FileDetailView(file: $0) }
      }
    }
    .__tenxTrackView("FilesView")
  }

  private var scopeBanner: some View {
    let scope: String
    switch store.role {
    case .admin: scope = "You can see all uploaded files across every site."
    case .siteManager: scope = "You can see files for the sites you manage."
    case .tradesman: scope = "You can see the files you have uploaded."
    }
    return WarningBanner(message: scope, symbol: "lock.shield", tint: Brand.blue)
  }

  private var filterBar: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        chip(title: "All", active: typeFilter == nil) { typeFilter = nil }
        ForEach(PhotoType.allCases) { t in
          chip(title: t.rawValue, active: typeFilter == t) { typeFilter = t }
        }
      }
    }
  }

  private func syncLabel(_ s: SyncStatus) -> String {
    switch s {
    case .notSynced: return "Not synced"
    case .pending: return "Pending sync"
    case .synced: return "In Xero"
    case .failed: return "Sync failed"
    }
  }

  private func syncColor(_ s: SyncStatus) -> Color {
    switch s {
    case .notSynced: return Brand.inkSoft
    case .pending: return Brand.amber
    case .synced: return Brand.paidGreen
    case .failed: return Brand.red
    }
  }

  private func chip(title: String, active: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(title)
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 12).padding(.vertical, 7)
        .foregroundStyle(active ? .white : Brand.ink)
        .background(active ? Brand.olive : Color.white, in: Capsule())
        .overlay(Capsule().stroke(Brand.hairline, lineWidth: active ? 0 : 1))
    }
    .buttonStyle(.plain)
  }

  private func fileCard(_ file: SitePhoto) -> some View {
    HStack(spacing: 12) {
      Image(systemName: file.symbol)
        .font(.title2).foregroundStyle(Brand.olive)
        .frame(width: 52, height: 52)
        .background(Brand.lightGreen, in: RoundedRectangle(cornerRadius: 12))
      VStack(alignment: .leading, spacing: 4) {
        Text(file.driveFileName.isEmpty ? file.type.rawValue : file.driveFileName)
          .font(.subheadline.weight(.semibold)).foregroundStyle(Brand.ink).lineLimit(1)
        Text("\(store.site(file.siteId)?.name ?? "Site") · \(store.user(file.userId)?.name ?? "")")
          .font(.caption).foregroundStyle(Brand.inkSoft).lineLimit(1)
        HStack(spacing: 6) {
          StatusChip(text: file.type.rawValue, color: Brand.blue)
          if let reg = file.type.linkedRegister {
            StatusChip(text: reg, color: Brand.amber)
          }
          if store.canSyncToXero(file), file.syncStatus != .notSynced {
            StatusChip(text: syncLabel(file.syncStatus), color: syncColor(file.syncStatus))
          }
        }
      }
      Spacer()
      Image(systemName: "chevron.right").font(.caption).foregroundStyle(Brand.inkSoft)
    }
    .mpgCard()
  }
}

/// Shows the full "Photos & Files" sheet row for one uploaded file.
struct FileDetailView: View {
  @Environment(AppStore.self) private var store
  let file: SitePhoto

  var body: some View {
    let live = store.photos.first(where: { $0.id == file.id }) ?? file
    let row = store.sheetRow(for: live)
    ScrollView {
      VStack(spacing: 16) {
        thumbnail
        driveCard
        if store.canSyncToXero(live) { xeroCard(live) }
        sheetCard(row)
      }
      .padding(16)
    }
    .background(MPGBackground())
    .navigationTitle("File Details")
    .navigationBarTitleDisplayMode(.inline)
  }

  private func xeroCard(_ live: SitePhoto) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Xero / Company Hub")
      HStack(spacing: 10) {
        Image(systemName: live.syncStatus.symbol)
          .font(.title3).foregroundStyle(syncTint(live.syncStatus))
          .symbolEffect(.pulse, isActive: live.syncStatus == .pending)
        VStack(alignment: .leading, spacing: 2) {
          Text(live.syncStatus.rawValue)
            .font(.subheadline.weight(.semibold)).foregroundStyle(Brand.ink)
          Text("Pushes this receipt to Google Drive/Sheets and creates an expense in Xero.")
            .font(.caption).foregroundStyle(Brand.inkSoft)
        }
        Spacer()
      }
      if live.syncStatus == .synced {
        Divider().overlay(Brand.hairline)
        InfoRow(label: "Xero reference", value: live.xeroReference, symbol: "number")
        if let at = live.syncedAt {
          InfoRow(
            label: "Synced", value: at.formatted(date: .abbreviated, time: .shortened),
            symbol: "checkmark.circle")
        }
      }
      if live.syncStatus != .synced {
        if store.xeroConnected {
          PrimaryButton(
            title: live.syncStatus == .pending ? "Sending…" : "Send to Xero / Hub",
            symbol: "arrow.up.forward.app"
          ) {
            store.sendToXero(live.id)
          }
          .disabled(live.syncStatus == .pending)
        } else {
          HStack(spacing: 8) {
            Image(systemName: "link.badge.plus").foregroundStyle(Brand.amber)
            Text("Connect Xero in Admin → Profile → Integrations to enable sync.")
              .font(.caption).foregroundStyle(Brand.inkSoft)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(12)
          .background(
            Brand.amber.opacity(0.12),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
      }
    }
    .mpgCard()
  }

  private func syncTint(_ s: SyncStatus) -> Color {
    switch s {
    case .notSynced: return Brand.inkSoft
    case .pending: return Brand.amber
    case .synced: return Brand.paidGreen
    case .failed: return Brand.red
    }
  }

  private var thumbnail: some View {
    VStack(spacing: 8) {
      Image(systemName: file.symbol).font(.system(size: 54)).foregroundStyle(Brand.olive)
      Text(file.type.rawValue).font(.headline).foregroundStyle(Brand.ink)
      Text(file.description).font(.subheadline).foregroundStyle(Brand.inkSoft)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(26)
    .background(Brand.lightGreen, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  private var driveCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Google Drive")
      InfoRow(label: "File name", value: file.driveFileName, symbol: "doc.text")
      InfoRow(label: "Folder", value: file.driveFolderPath, symbol: "folder")
      InfoRow(label: "File ID", value: file.driveFileId, symbol: "number")
      InfoRow(label: "Source", value: file.source.rawValue, symbol: file.source.symbol)
      if let url = URL(string: file.driveURL), !file.driveURL.isEmpty {
        Link(destination: url) {
          Label("Open in Google Drive", systemImage: "arrow.up.forward.app")
            .font(.subheadline.weight(.semibold)).foregroundStyle(Brand.olive)
        }
      }
    }
    .mpgCard()
  }

  private func sheetCard(_ row: FileSheetRow) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Photos & Files sheet row")
      InfoRow(label: "Uploaded by", value: row.uploadedBy, symbol: "person")
      InfoRow(label: "Tradesman", value: row.tradesmanName, symbol: "hammer")
      InfoRow(label: "Site", value: row.site, symbol: "mappin")
      InfoRow(label: "Date", value: Fmt.fullDate(row.date), symbol: "calendar")
      if let we = row.weekEnding {
        InfoRow(label: "Week ending", value: Fmt.fullDate(we), symbol: "calendar.badge.clock")
      }
      InfoRow(label: "Allocation", value: row.linkedAllocation, symbol: "list.bullet.rectangle")
      InfoRow(label: "Daily record", value: row.linkedDailyRecord, symbol: "doc.plaintext")
      InfoRow(label: "Weekly submission", value: row.linkedSubmission, symbol: "doc.text")
      InfoRow(label: "File type", value: row.fileType, symbol: "tag")
      if let reg = row.linkedRegister {
        InfoRow(label: "Linked register", value: reg, symbol: "link")
      }
      InfoRow(
        label: "Timestamp", value: row.timestamp.formatted(date: .abbreviated, time: .shortened),
        symbol: "clock")
    }
    .mpgCard()
  }
}

#Preview {
  FilesView().environment(
    {
      let s = AppStore()
      s.login(as: s.tradesmen().first!)
      return s
    }())
}
