import SwiftUI

/// Add a file (upload) or a Google Drive link to a site's Files Hub.
struct AddSiteFileView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss

  let site: Site
  var presetCategory: FileCategory? = nil

  @State private var origin: FileOrigin = .upload
  @State private var title = ""
  @State private var category: FileCategory = .drawings
  @State private var fileType = "PDF"
  @State private var driveURL = ""
  @State private var notes = ""
  @State private var visibility: FileVisibility = .everyone
  @State private var tagText = ""
  @State private var uploadedSource: CaptureSource = .camera

  private let fileTypes = ["PDF", "Word", "Excel", "JPG", "PNG", "Video", "Drawing", "Other"]

  private var canSave: Bool {
    if origin == .driveLink {
      return !title.isEmpty && driveURL.lowercased().contains("http")
    }
    return !title.isEmpty
  }

  var body: some View {
    Group {
      NavigationStack {
        ScrollView {
          VStack(spacing: 16) {
            methodCard
            detailsCard
            if origin == .driveLink { driveCard } else { uploadCard }
            metaCard
            PrimaryButton(title: "Add to \(site.name)", symbol: "checkmark.circle.fill") {
              save()
            }
            .opacity(canSave ? 1 : 0.5)
            .disabled(!canSave)
          }
          .padding(16)
        }
        .background(MPGBackground())
        .navigationTitle("Add File")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .topBarLeading) {
            Button("Cancel") { dismiss() }
          }
        }
        .onAppear {
          if let c = presetCategory { category = c }
        }
      }
    }
    .__tenxTrackView("AddSiteFileView")
  }

  private var methodCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Add method")
      Picker("Method", selection: $origin) {
        ForEach(FileOrigin.allCases) { Text($0.rawValue).tag($0) }
      }
      .pickerStyle(.segmented)
    }
    .mpgCard()
  }

  private var detailsCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "File details")
      labeledField("File title", text: $title, placeholder: "e.g. Structural Drawing Rev C")
      VStack(alignment: .leading, spacing: 6) {
        Text("Category").font(.caption.weight(.semibold)).foregroundStyle(Brand.inkSoft)
        Picker("Category", selection: $category) {
          ForEach(FileCategory.allCases) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.menu)
        .tint(Brand.olive)
      }
    }
    .mpgCard()
  }

  private var uploadCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Upload file")
      Picker("Source", selection: $uploadedSource) {
        Text("Camera").tag(CaptureSource.camera)
        Text("Gallery / Files").tag(CaptureSource.gallery)
      }
      .pickerStyle(.segmented)
      VStack(alignment: .leading, spacing: 6) {
        Text("File type").font(.caption.weight(.semibold)).foregroundStyle(Brand.inkSoft)
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 8) {
            ForEach(fileTypes, id: \.self) { t in
              Button {
                fileType = t
              } label: {
                Text(t).font(.caption.weight(.semibold))
                  .padding(.horizontal, 12).padding(.vertical, 7)
                  .foregroundStyle(fileType == t ? .white : Brand.ink)
                  .background(fileType == t ? Brand.olive : Color.white, in: Capsule())
                  .overlay(Capsule().stroke(Brand.hairline, lineWidth: fileType == t ? 0 : 1))
              }
              .buttonStyle(.plain)
            }
          }
        }
      }
      HStack(spacing: 8) {
        Image(systemName: uploadedSource.symbol).foregroundStyle(Brand.olive)
        Text("File will be filed into Google Drive under the site's category folder.")
          .font(.caption).foregroundStyle(Brand.inkSoft)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(10)
      .background(Brand.lightGreen, in: RoundedRectangle(cornerRadius: 10))
    }
    .mpgCard()
  }

  private var driveCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Google Drive link")
      labeledField(
        "Google Drive URL", text: $driveURL,
        placeholder: "https://drive.google.com/…")
      Text("Tapping the file later opens this Google Drive link in a new window.")
        .font(.caption).foregroundStyle(Brand.inkSoft)
    }
    .mpgCard()
  }

  private var metaCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Notes & permissions")
      labeledField("Description / notes", text: $notes, placeholder: "Optional notes")
      labeledField("Tags (comma separated)", text: $tagText, placeholder: "e.g. rev-c, architect")
      VStack(alignment: .leading, spacing: 6) {
        Text("Visibility").font(.caption.weight(.semibold)).foregroundStyle(Brand.inkSoft)
        Picker("Visibility", selection: $visibility) {
          ForEach(FileVisibility.allCases) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.menu)
        .tint(Brand.olive)
      }
    }
    .mpgCard()
  }

  private func labeledField(_ label: String, text: Binding<String>, placeholder: String)
    -> some View
  {
    VStack(alignment: .leading, spacing: 6) {
      Text(label).font(.caption.weight(.semibold)).foregroundStyle(Brand.inkSoft)
      TextField(placeholder, text: text)
        .textInputAutocapitalization(.sentences)
        .padding(12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Brand.hairline, lineWidth: 1))
    }
  }

  private func save() {
    let tags =
      tagText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }
    let url =
      origin == .driveLink
      ? driveURL
      : "https://drive.google.com/file/d/drv_\(UUID().uuidString.prefix(16))/view"
    store.addSiteFile(
      site: site, title: title, category: category, origin: origin,
      fileType: origin == .driveLink ? "Drive link" : fileType, driveURL: url,
      notes: notes, visibility: visibility, tags: tags)
    dismiss()
  }
}
