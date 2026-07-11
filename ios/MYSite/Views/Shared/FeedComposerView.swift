import SwiftUI

/// Compose a new company feed post: text, optional site tag, and demo photo
/// attachments (SF Symbol stand-ins, matching the app's photo convention).
struct FeedComposerView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss

  @State private var text = ""
  @State private var selectedSiteId: UUID?
  @State private var photoSymbols: [String] = []

  private let demoPhotos = [
    "digOut", "hallwayPaint", "brickwork", "screed", "scaffold", "kitchenFit",
  ]

  var body: some View {
    Group {
      NavigationStack {
        ZStack {
          MPGBackground()
          ScrollView {
            VStack(spacing: 16) {
              VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Your update")
                TextEditor(text: $text)
                  .frame(minHeight: 130)
                  .scrollContentBackground(.hidden)
                  .padding(10)
                  .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                      .fill(Brand.lightGreen.opacity(0.5))
                  )
                  .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                      Text("Share an update with the team…")
                        .font(.subheadline)
                        .foregroundStyle(Brand.inkSoft)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                    }
                  }
              }
              .mpgCard()

              VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Attach photos", subtitle: "Add site photos to your post")
                LazyVGrid(
                  columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8
                ) {
                  ForEach(demoPhotos, id: \.self) { key in
                    let on = photoSymbols.contains(key)
                    Button {
                      if on {
                        photoSymbols.removeAll { $0 == key }
                      } else {
                        photoSymbols.append(key)
                      }
                    } label: {
                      SitePhotoImage(scene: SiteScene(key: key))
                        .frame(height: 66)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                          RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(on ? Brand.olive : Brand.hairline, lineWidth: on ? 3 : 1)
                        )
                        .overlay(alignment: .topTrailing) {
                          if on {
                            Image(systemName: "checkmark.circle.fill")
                              .foregroundStyle(.white, Brand.olive)
                              .padding(5)
                          }
                        }
                    }
                    .buttonStyle(.plain)
                  }
                }
              }
              .mpgCard()

              VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Tag a site", subtitle: "Optional")
                Menu {
                  Button("No site") { selectedSiteId = nil }
                  ForEach(store.sites) { site in
                    Button(site.name) { selectedSiteId = site.id }
                  }
                } label: {
                  HStack {
                    Image(systemName: "mappin.and.ellipse").foregroundStyle(Brand.olive)
                    Text(selectedSiteId.flatMap { store.site($0)?.name } ?? "No site")
                      .foregroundStyle(Brand.ink)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").font(.caption)
                      .foregroundStyle(Brand.inkSoft)
                  }
                  .font(.subheadline)
                  .padding(.vertical, 12)
                  .padding(.horizontal, 14)
                  .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                      .fill(Brand.lightGreen.opacity(0.5)))
                }
              }
              .mpgCard()

              PrimaryButton(title: "Post to team", symbol: "paperplane.fill") {
                store.addFeedPost(text: text, photoSymbols: photoSymbols, siteId: selectedSiteId)
                dismiss()
              }
              .disabled(!canPost)
              .opacity(canPost ? 1 : 0.5)
            }
            .padding(16)
          }
        }
        .navigationTitle("New Post")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
          }
        }
      }
    }
    .__tenxTrackView("FeedComposerView")
  }

  private var canPost: Bool {
    !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !photoSymbols.isEmpty
  }
}

#Preview {
  FeedComposerView().environment(
    {
      let s = AppStore()
      s.login(as: s.users.first!)
      return s
    }())
}
