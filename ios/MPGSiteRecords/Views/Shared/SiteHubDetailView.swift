import SwiftUI

/// A single site's Files Hub: folder groups, each expandable to its categories.
struct SiteHubDetailView: View {
  @Environment(AppStore.self) private var store
  let site: Site
  @State private var showAdd = false
  @State private var showHandover = false

  private var canUpload: Bool { store.canUpload(to: site) }

  var body: some View {
      Group {
              ScrollView {
          VStack(spacing: 16) {
            headerCard
            prompts
            ForEach(FileGroup.allCases) { group in
              groupCard(group)
            }
          }
          .padding(16)
              }
              .background(MPGBackground())
              .navigationTitle(site.name)
              .navigationBarTitleDisplayMode(.inline)
              .toolbar {
          ToolbarItem(placement: .topBarTrailing) {
            Menu {
              if canUpload {
                Button {
                  showAdd = true
                } label: {
                  Label("Add file / link", systemImage: "plus")
                }
              }
              Button {
                showHandover = true
              } label: {
                Label("Handover pack", systemImage: "shippingbox")
              }
            } label: {
              Image(systemName: "ellipsis.circle")
            }
          }
              }
              .sheet(isPresented: $showAdd) {
          AddSiteFileView(site: site)
              }
              .sheet(isPresented: $showHandover) {
          HandoverPackView(site: site)
              }
      }
      .__tenxTrackView("SiteHubDetailView")
  }

  private var headerCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 12) {
        Image(systemName: "building.2.fill")
          .font(.title2).foregroundStyle(.white)
          .frame(width: 46, height: 46)
          .background(Brand.charcoal, in: RoundedRectangle(cornerRadius: 12))
        VStack(alignment: .leading, spacing: 2) {
          Text(site.client).font(.subheadline.weight(.semibold)).foregroundStyle(Brand.ink)
          Text(site.address).font(.caption).foregroundStyle(Brand.inkSoft)
        }
        Spacer()
      }
      HStack(spacing: 8) {
        StatusChip(text: "\(store.files(forSite: site.id).count) files", color: Brand.olive)
        StatusChip(text: site.status.rawValue, color: Brand.blue)
      }
      if canUpload {
        PrimaryButton(title: "Add file or Google Drive link", symbol: "plus.circle.fill") {
          showAdd = true
        }
      }
    }
    .mpgCard()
  }

  @ViewBuilder private var prompts: some View {
    let missing = missingPrompts
    if !missing.isEmpty {
      VStack(spacing: 8) {
        ForEach(missing, id: \.self) { msg in
          WarningBanner(message: msg, symbol: "exclamationmark.triangle.fill", tint: Brand.amber)
        }
      }
    }
  }

  private var missingPrompts: [String] {
    var out: [String] = []
    if store.sitesMissingDrawings().contains(where: { $0.id == site.id }) {
      out.append("This site has no current drawings uploaded.")
    }
    if store.sitesMissingHealthSafety().contains(where: { $0.id == site.id }) {
      out.append("This site is missing RAMS / health & safety documents.")
    }
    let unreceipted = store.materials.filter { $0.siteId == site.id && !$0.receiptUploaded }.count
    if unreceipted > 0 {
      out.append("\(unreceipted) material claim(s) have no VAT receipt uploaded.")
    }
    return out
  }

  private func groupCard(_ group: FileGroup) -> some View {
    let cats = group.categories.filter {
      store.fileCount(forSite: site.id, category: $0) > 0 || store.canUpload(to: site)
    }
    return VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        Image(systemName: group.symbol).foregroundStyle(Brand.olive)
        Text(group.rawValue).font(.subheadline.weight(.bold)).foregroundStyle(Brand.ink)
        Spacer()
        Text("\(store.fileCount(forSite: site.id, group: group))")
          .font(.caption.weight(.semibold)).foregroundStyle(Brand.inkSoft)
      }
      Divider().overlay(Brand.hairline)
      ForEach(cats) { cat in
        NavigationLink(value: SiteFileCategoryRoute(site: site, category: cat)) {
          categoryRow(cat)
        }
        .buttonStyle(.plain)
      }
    }
    .mpgCard()
  }

  private func categoryRow(_ cat: FileCategory) -> some View {
    let count = store.fileCount(forSite: site.id, category: cat)
    return HStack(spacing: 12) {
      Image(systemName: cat.symbol)
        .font(.footnote).foregroundStyle(Brand.olive)
        .frame(width: 30, height: 30)
        .background(Brand.lightGreen, in: RoundedRectangle(cornerRadius: 8))
      Text(cat.rawValue).font(.subheadline).foregroundStyle(Brand.ink)
      Spacer()
      if count > 0 {
        Text("\(count)").font(.caption.weight(.semibold)).foregroundStyle(Brand.inkSoft)
      }
      Image(systemName: "chevron.right").font(.caption2).foregroundStyle(Brand.inkSoft)
    }
    .padding(.vertical, 3)
  }
}

/// Files within one site + category.
struct SiteCategoryFilesView: View {
  @Environment(AppStore.self) private var store
  let site: Site
  let category: FileCategory
  @State private var showAdd = false

  private var files: [SiteFile] { store.files(forSite: site.id, category: category) }

  var body: some View {
    ScrollView {
      VStack(spacing: 12) {
        if files.isEmpty {
          EmptyStateView(
            symbol: category.symbol, title: "No \(category.rawValue.lowercased())",
            message: "Files added to this category will appear here.",
            actionTitle: store.canUpload(to: site) ? "Add file or link" : nil,
            action: store.canUpload(to: site) ? { showAdd = true } : nil
          ).mpgCard()
        } else {
          ForEach(files) { file in
            NavigationLink(value: file) { SiteFileRow(file: file) }
              .buttonStyle(.plain)
          }
        }
      }
      .padding(16)
    }
    .background(MPGBackground())
    .navigationTitle(category.rawValue)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      if store.canUpload(to: site) {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            showAdd = true
          } label: {
            Image(systemName: "plus")
          }
        }
      }
    }
    .sheet(isPresented: $showAdd) {
      AddSiteFileView(site: site, presetCategory: category)
    }
  }
}

/// Compact file list row used in category lists and search.
struct SiteFileRow: View {
  @Environment(AppStore.self) private var store
  let file: SiteFile

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: file.category.symbol)
        .font(.title3).foregroundStyle(Brand.olive)
        .frame(width: 48, height: 48)
        .background(Brand.lightGreen, in: RoundedRectangle(cornerRadius: 12))
      VStack(alignment: .leading, spacing: 4) {
        Text(file.title).font(.subheadline.weight(.semibold)).foregroundStyle(Brand.ink)
          .lineLimit(1)
        Text("\(store.site(file.siteId)?.name ?? "Site") · \(file.uploadedByName)")
          .font(.caption).foregroundStyle(Brand.inkSoft).lineLimit(1)
        HStack(spacing: 6) {
          Label(file.approval.rawValue, systemImage: file.approval.symbol)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(file.approval.color)
          StatusChip(text: file.origin == .driveLink ? "Drive" : file.fileType, color: Brand.blue)
          if file.inHandoverPack {
            Image(systemName: "shippingbox.fill").font(.caption2).foregroundStyle(Brand.olive)
          }
        }
      }
      Spacer()
      Image(systemName: "chevron.right").font(.caption).foregroundStyle(Brand.inkSoft)
    }
    .mpgCard()
  }
}
