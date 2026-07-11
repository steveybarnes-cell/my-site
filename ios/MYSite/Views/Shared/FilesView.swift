import SwiftUI

/// Site-first central document hub. Replaces the old flat file browser.
/// Flow: pick a Site → see folder groups → drill into a category → files.
struct FilesView: View {
  @Environment(AppStore.self) private var store
  @State private var search = ""
  @State private var showSearch = false

  private var mySites: [Site] { store.hubSites() }

  var body: some View {
    NavigationStack {
      ZStack {
        MPGBackground()
        Group {
          if showSearch && !search.isEmpty {
            searchResults
          } else {
            hubList
          }
        }
      }
      .navigationTitle("Site Files")
      .searchable(text: $search, isPresented: $showSearch, prompt: "Search all site files")
      .navigationDestination(for: Site.self) { SiteHubDetailView(site: $0) }
      .navigationDestination(for: SiteFileCategoryRoute.self) {
        SiteCategoryFilesView(site: $0.site, category: $0.category)
      }
      .navigationDestination(for: SiteFile.self) { SiteFileDetailView(file: $0) }
    }
    .__tenxTrackView("FilesView")
  }

  private var hubList: some View {
    ScrollView {
      VStack(spacing: 16) {
        scopeBanner
        if mySites.isEmpty {
          EmptyStateView(
            symbol: "folder.badge.questionmark", title: "No sites yet",
            message: "You have no sites allocated to you. Site files will appear here once you do."
          ).mpgCard()
        } else {
          ForEach(mySites) { site in
            NavigationLink(value: site) { siteCard(site) }
              .buttonStyle(.plain)
          }
        }
      }
      .padding(16)
    }
  }

  private var scopeBanner: some View {
    let scope: String
    switch store.role {
    case .admin: scope = "You can browse every site's file hub across the company."
    case .siteManager: scope = "You can see file hubs for the sites you manage."
    case .tradesman: scope = "You can see file hubs for the sites you are allocated to."
    }
    return WarningBanner(message: scope, symbol: "lock.shield", tint: Brand.blue)
  }

  private func siteCard(_ site: Site) -> some View {
    let count = store.files(forSite: site.id).count
    let awaiting = store.files(forSite: site.id).filter { $0.approval == .awaiting }.count
    return VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 12) {
        Image(systemName: "building.2.fill")
          .font(.title2).foregroundStyle(.white)
          .frame(width: 52, height: 52)
          .background(Brand.charcoal, in: RoundedRectangle(cornerRadius: 14))
        VStack(alignment: .leading, spacing: 3) {
          Text(site.name).font(.headline).foregroundStyle(Brand.ink)
          Text(site.client).font(.caption).foregroundStyle(Brand.inkSoft).lineLimit(1)
        }
        Spacer()
        Image(systemName: "chevron.right").font(.caption).foregroundStyle(Brand.inkSoft)
      }
      HStack(spacing: 8) {
        StatusChip(text: "\(count) files", color: Brand.olive)
        if awaiting > 0 { StatusChip(text: "\(awaiting) awaiting", color: Brand.amber) }
        if store.sitesMissingDrawings().contains(where: { $0.id == site.id }) {
          StatusChip(text: "No drawings", color: Brand.red)
        }
      }
    }
    .mpgCard()
  }

  private var searchResults: some View {
    let results = store.searchSiteFiles(search)
    return ScrollView {
      VStack(spacing: 12) {
        if results.isEmpty {
          EmptyStateView(
            symbol: "magnifyingglass", title: "No matches",
            message: "Try a site name, title, category, supplier, tag or note."
          ).mpgCard()
        } else {
          ForEach(results) { file in
            NavigationLink(value: file) { SiteFileRow(file: file) }
              .buttonStyle(.plain)
          }
        }
      }
      .padding(16)
    }
  }
}

/// Navigation route into a site's category file list.
struct SiteFileCategoryRoute: Hashable {
  let site: Site
  let category: FileCategory
}

#Preview {
  FilesView().environment(
    {
      let s = AppStore()
      s.login(as: s.users.first { $0.role == .admin }!)
      return s
    }())
}
