import PhotosUI
import SwiftUI

/// Compose a new company feed post: text, optional site tag, and real photos
/// taken on site or picked from the library, each of which can be drawn and
/// written on before posting.
struct FeedComposerView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss

  @State private var text = ""
  @State private var selectedSiteId: UUID?
  @State private var photos: [ComposerPhoto] = []

  @State private var pickerItems: [PhotosPickerItem] = []
  @State private var showCamera = false
  @State private var editTarget: EditTarget?
  @State private var loadError: String?

  /// A photo held in the composer. The original bytes and the markup stay
  /// separate until the moment of posting, so the user can keep editing,
  /// undoing or clearing annotations without ever degrading the source image.
  struct ComposerPhoto: Identifiable {
    let id = UUID()
    var image: UIImage
    var markup = PhotoMarkup()
  }

  /// Wrapper so `.sheet(item:)` can be driven by a photo id without
  /// retroactively conforming `UUID` to `Identifiable`.
  struct EditTarget: Identifiable { let id: UUID }

  /// Matches the feed card's carousel — more than this in one post stops being
  /// readable in a 300pt card.
  private let maxPhotos = 6

  var body: some View {
    Group {
      NavigationStack {
        ZStack {
          MPGBackground()
          ScrollView {
            VStack(spacing: 16) {
              updateCard
              photosCard
              siteCard

              PrimaryButton(title: "Post to team", symbol: "paperplane.fill") { post() }
                .disabled(!canPost)
                .opacity(canPost ? 1 : 0.5)
                .animation(.snappy(duration: 0.2), value: canPost)
                .padding(.top, 2)
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
        .sheet(isPresented: $showCamera) {
          CameraCaptureView { data in
            addPhoto(from: data)
          }
        }
        .sheet(item: $editTarget) { target in
          if let photo = photos.first(where: { $0.id == target.id }) {
            PhotoMarkupEditorView(image: photo.image, markup: photo.markup) { updated in
              if let i = photos.firstIndex(where: { $0.id == target.id }) {
                photos[i].markup = updated
              }
            }
          }
        }
        .onChange(of: pickerItems) { _, items in
          guard !items.isEmpty else { return }
          loadPicked(items)
        }
      }
    }
    .__tenxTrackView("FeedComposerView")
  }

  // MARK: - Update text

  private var updateCard: some View {
    VStack(alignment: .leading, spacing: 8) {
      SectionHeader(title: "Your update")
      TextEditor(text: $text)
        .frame(minHeight: 130)
        .scrollContentBackground(.hidden)
        .padding(10)
        .background(
          RoundedRectangle(cornerRadius: Brand.Radius.inner, style: .continuous)
            .fill(Brand.lightGreen.opacity(0.5))
        )
        .overlay(
          RoundedRectangle(cornerRadius: Brand.Radius.inner, style: .continuous)
            .stroke(Brand.hairline, lineWidth: 1)
        )
        .overlay(alignment: .topLeading) {
          if text.isEmpty {
            // Padding matches the editor's own text inset so the
            // placeholder sits exactly where typing begins.
            Text("Share an update with the team…")
              .font(.subheadline)
              .foregroundStyle(Brand.inkSoft)
              .padding(.horizontal, 15)
              .padding(.vertical, 18)
              .allowsHitTesting(false)
          }
        }
    }
    .mpgCard()
  }

  // MARK: - Photos

  private var photosCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(
        title: "Photos",
        subtitle: photos.isEmpty
          ? "Take a photo or pick one, then mark it up"
          : "\(photos.count) of \(maxPhotos) — tap a photo to draw or write on it")

      HStack(spacing: 10) {
        Button {
          showCamera = true
        } label: {
          sourceButton(symbol: "camera.fill", title: "Take photo")
        }
        .buttonStyle(.plain)
        .disabled(isFull)
        .opacity(isFull ? 0.45 : 1)

        PhotosPicker(
          selection: $pickerItems,
          maxSelectionCount: max(1, maxPhotos - photos.count),
          matching: .images,
          photoLibrary: .shared()
        ) {
          sourceButton(symbol: "photo.on.rectangle.angled", title: "Photo library")
        }
        .buttonStyle(.plain)
        .disabled(isFull)
        .opacity(isFull ? 0.45 : 1)
      }

      if isFull {
        Text("Maximum of \(maxPhotos) photos per post.")
          .font(.caption).foregroundStyle(Brand.inkSoft)
          .frame(maxWidth: .infinity, alignment: .leading)
      }

      if let loadError {
        Label(loadError, systemImage: "exclamationmark.triangle.fill")
          .font(.caption).foregroundStyle(Brand.red)
          .frame(maxWidth: .infinity, alignment: .leading)
      }

      if !photos.isEmpty {
        LazyVGrid(
          columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8
        ) {
          ForEach(photos) { photo in
            thumbnail(photo)
          }
        }
      }

      if !photos.isEmpty && selectedSiteId == nil {
        // Untagged photos still upload, but nothing links them to a job, so
        // they never reach the site manager's evidence trail.
        Label(
          "Tag a site so these photos are filed against the right job.",
          systemImage: "info.circle"
        )
        .font(.caption)
        .foregroundStyle(Brand.inkSoft)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .mpgCard()
  }

  private func sourceButton(symbol: String, title: String) -> some View {
    VStack(spacing: 7) {
      Image(systemName: symbol).font(.system(size: 24))
        .foregroundStyle(Brand.olive)
      Text(title).font(.caption.weight(.semibold)).foregroundStyle(Brand.ink)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 18)
    .background(
      RoundedRectangle(cornerRadius: Brand.Radius.inner, style: .continuous)
        .fill(Brand.lightGreen.opacity(0.6))
    )
    .overlay(
      RoundedRectangle(cornerRadius: Brand.Radius.inner, style: .continuous)
        .stroke(Brand.hairline, lineWidth: 1)
    )
  }

  private func thumbnail(_ photo: ComposerPhoto) -> some View {
    Button {
      editTarget = EditTarget(id: photo.id)
    } label: {
      Color.clear
        .frame(height: 84)
        .overlay {
          ZStack {
            Image(uiImage: photo.image)
              .resizable()
              .scaledToFill()
            // Annotations are normalised, so the live overlay previews the
            // markup at thumbnail size without flattening anything yet.
            PhotoMarkupOverlay(markup: photo.markup)
          }
        }
        .clipShape(RoundedRectangle(cornerRadius: Brand.Radius.chip, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: Brand.Radius.chip, style: .continuous)
            .stroke(Brand.hairline, lineWidth: 1)
        )
        .overlay(alignment: .bottomLeading) {
          Image(
            systemName: photo.markup.isEmpty
              ? "pencil.tip.crop.circle" : "checkmark.circle.fill"
          )
          .font(.system(size: 15))
          .foregroundStyle(.white, photo.markup.isEmpty ? Color.black.opacity(0.45) : Brand.olive)
          .padding(5)
        }
        .overlay(alignment: .topTrailing) {
          Button {
            photos.removeAll { $0.id == photo.id }
          } label: {
            Image(systemName: "xmark.circle.fill")
              .font(.system(size: 17))
              .foregroundStyle(.white, .black.opacity(0.55))
              .padding(4)
          }
          .buttonStyle(.plain)
        }
    }
    .buttonStyle(.plain)
    .accessibilityLabel(photo.markup.isEmpty ? "Photo, no markup" : "Photo with markup")
    .accessibilityHint("Opens the markup editor")
  }

  // MARK: - Site tag

  private var siteCard: some View {
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
          RoundedRectangle(cornerRadius: Brand.Radius.inner, style: .continuous)
            .fill(Brand.lightGreen.opacity(0.5))
        )
        .overlay(
          RoundedRectangle(cornerRadius: Brand.Radius.inner, style: .continuous)
            .stroke(Brand.hairline, lineWidth: 1)
        )
      }
    }
    .mpgCard()
  }

  // MARK: - Photo intake

  private var isFull: Bool { photos.count >= maxPhotos }

  private func addPhoto(from data: Data) {
    guard !isFull, let image = UIImage(data: data) else { return }
    // Downscale on intake: several full-resolution 12MP captures held at once
    // will exhaust memory long before the six-photo limit.
    photos.append(ComposerPhoto(image: FeedPhotoStore.resized(image)))
  }

  private func loadPicked(_ items: [PhotosPickerItem]) {
    Task { @MainActor in
      var failed = false
      for item in items {
        guard !isFull else { break }
        if let data = try? await item.loadTransferable(type: Data.self),
          let image = UIImage(data: data)
        {
          photos.append(ComposerPhoto(image: FeedPhotoStore.resized(image)))
        } else {
          failed = true
        }
      }
      loadError = failed ? "Some photos couldn't be opened. Try picking them again." : nil
      pickerItems = []
    }
  }

  // MARK: - Posting

  private var canPost: Bool {
    !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !photos.isEmpty
  }

  private func post() {
    // Flatten each photo's markup into its pixels at post time — from here on
    // the annotation travels with the evidence wherever the file goes.
    let images: [Data] = photos.compactMap { photo in
      let flattened = PhotoMarkupRenderer.flatten(image: photo.image, markup: photo.markup)
      return FeedPhotoStore.prepare(flattened)
    }
    _ = store.addFeedPost(text: text, images: images, siteId: selectedSiteId)
    dismiss()
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
