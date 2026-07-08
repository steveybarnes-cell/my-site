import PhotosUI
import SwiftUI

struct PhotoCaptureView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  let allocation: WorkAllocation

  @State private var type: PhotoType = .before
  @State private var description = ""
  @State private var source: CaptureSource = .camera
  @State private var pickerItem: PhotosPickerItem?
  @State private var hasImage = false
  @State private var showCamera = false
  @State private var savedName: String?
  @State private var imageData: Data?

  // AI receipt scan (only for receipt / supplier invoice types)
  @State private var isScanning = false
  @State private var scanNote: String?
  @State private var scanError: String?

  private var site: Site? { store.site(allocation.siteId) }

  private var isReceiptType: Bool {
    type == .receipt || type == .supplierInvoice
  }

  var body: some View {
    Group {
      NavigationStack {
        ZStack {
          MPGBackground()
          ScrollView {
            VStack(spacing: 16) {
              sourceSection
              captureArea
              typeSection
              detailsSection
              drivePreview
              PrimaryButton(title: "Upload to Drive", symbol: "arrow.up.doc") { save() }
                .disabled(!hasImage)
                .opacity(hasImage ? 1 : 0.5)
            }
            .padding(16)
          }
        }
        .navigationTitle("Add File")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        .sheet(isPresented: $showCamera) {
          CameraCaptureView { data in
            imageData = data
            hasImage = true
            scanIfReceipt()
          }
        }
        .onChange(of: pickerItem) { _, newValue in
          guard let newValue else {
            hasImage = false
            return
          }
          Task {
            if let data = try? await newValue.loadTransferable(type: Data.self) {
              imageData = data
              hasImage = true
              scanIfReceipt()
            }
          }
        }
        .onChange(of: type) { _, _ in
          scanNote = nil
          scanError = nil
        }
      }
    }
    .__tenxTrackView("PhotoCaptureView")
  }

  // MARK: - Source

  private var sourceSection: some View {
    Picker("Source", selection: $source) {
      ForEach(CaptureSource.allCases) { Label($0.rawValue, systemImage: $0.symbol).tag($0) }
    }
    .pickerStyle(.segmented)
  }

  @ViewBuilder private var captureArea: some View {
    if source == .camera {
      Button {
        showCamera = true
      } label: {
        captureCard(
          symbol: hasImage ? "checkmark.circle.fill" : "camera.viewfinder",
          title: hasImage ? "Photo captured" : "Take photo",
          note: "Photos are timestamped and linked to this job automatically.")
      }
      .buttonStyle(.plain)
    } else {
      PhotosPicker(selection: $pickerItem, matching: .images) {
        captureCard(
          symbol: hasImage ? "checkmark.circle.fill" : "photo.on.rectangle.angled",
          title: hasImage ? "File selected" : "Choose from gallery",
          note: "Pick an existing photo, receipt or supplier invoice from your library.")
      }
      .buttonStyle(.plain)
    }
  }

  private func captureCard(symbol: String, title: String, note: String) -> some View {
    VStack(spacing: 10) {
      Image(systemName: symbol).font(.system(size: 54))
        .foregroundStyle(hasImage ? Brand.paidGreen : Brand.olive)
      Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Brand.ink)
      Text(note).font(.caption).foregroundStyle(Brand.inkSoft).multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(30)
    .background(Brand.lightGreen, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  // MARK: - Type + details

  private var typeSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "File type")
      Picker("Type", selection: $type) {
        ForEach(PhotoType.allCases) { Label($0.rawValue, systemImage: $0.symbol).tag($0) }
      }
      .pickerStyle(.menu)
      .tint(Brand.olive)
      .frame(maxWidth: .infinity, alignment: .leading)
      if let register = type.linkedRegister {
        WarningBanner(
          message: "This file will also be linked to the \(register).",
          symbol: "link", tint: Brand.blue)
      }
    }
    .mpgFormSection()
  }

  private var detailsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Description / notes")
      TextField("What does this file show?", text: $description, axis: .vertical)
        .lineLimit(2...4)
        .font(.subheadline)
        .padding(12)
        .background(.white, in: RoundedRectangle(cornerRadius: 12))
    }
    .mpgFormSection()
  }

  // MARK: - Drive preview

  private var drivePreview: some View {
    let tradesman =
      store.user(allocation.tradesmanId)?.name ?? (store.currentUser?.name ?? "Tradesman")
    let siteName = site?.name ?? "Site"
    let weekEnding = FileStorage.weekEndingSunday(for: Date())
    let ref = FileStorage.taskRef(allocation: allocation, dailyRecordId: nil, submissionId: nil)
    let path = FileStorage.folderPath(
      type: type, siteName: siteName, weekEnding: weekEnding, tradesman: tradesman)
    let name = FileStorage.fileName(
      date: Date(), siteName: siteName, tradesman: tradesman, type: type, taskRef: ref, ext: "jpg")
    return VStack(alignment: .leading, spacing: 10) {
      SectionHeader(title: "Saves to Google Drive as")
      Label(path, systemImage: "folder")
        .font(.caption).foregroundStyle(Brand.inkSoft)
        .frame(maxWidth: .infinity, alignment: .leading)
      Label(name, systemImage: "doc.text")
        .font(.caption.weight(.semibold)).foregroundStyle(Brand.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .mpgCard()
  }

  private func save() {
    guard let site else { return }
    let uploaded = store.uploadFile(
      type: type, description: description, source: source, ext: "jpg",
      site: site, allocation: allocation, dailyRecordId: nil, submissionId: nil,
      imageData: imageData)
    savedName = uploaded.driveFileName
    dismiss()
  }
}

// MARK: - Camera capture (simulator-safe)

/// Wraps `UIImagePickerController` for camera capture. On the Simulator (no camera hardware)
/// it falls back to a demo capture so the flow stays testable end to end.
struct CameraCaptureView: UIViewControllerRepresentable {
  var onCapture: (Data) -> Void
  @Environment(\.dismiss) private var dismiss

  func makeUIViewController(context: Context) -> UIViewController {
    #if targetEnvironment(simulator)
      return SimulatedCameraController(onCapture: onCapture, onDismiss: { dismiss() })
    #else
      let picker = UIImagePickerController()
      picker.sourceType =
        UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
      picker.delegate = context.coordinator
      return picker
    #endif
  }

  func updateUIViewController(_ vc: UIViewController, context: Context) {}

  func makeCoordinator() -> Coordinator { Coordinator(self) }

  final class Coordinator: NSObject, UINavigationControllerDelegate,
    UIImagePickerControllerDelegate
  {
    let parent: CameraCaptureView
    init(_ parent: CameraCaptureView) { self.parent = parent }

    func imagePickerController(
      _ picker: UIImagePickerController,
      didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
      if let image = info[.originalImage] as? UIImage,
        let data = image.jpegData(compressionQuality: 0.8)
      {
        parent.onCapture(data)
      }
      parent.dismiss()
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
      parent.dismiss()
    }
  }
}

/// Simple simulator stand-in that confirms a "capture" so the pipeline is demonstrable in preview.
final class SimulatedCameraController: UIViewController {
  let onCapture: (Data) -> Void
  let onDismiss: () -> Void
  init(onCapture: @escaping (Data) -> Void, onDismiss: @escaping () -> Void) {
    self.onCapture = onCapture
    self.onDismiss = onDismiss
    super.init(nibName: nil, bundle: nil)
  }
  required init?(coder: NSCoder) { fatalError() }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = UIColor(white: 0.08, alpha: 1)

    let label = UILabel()
    label.text = "Simulator camera\nTap to capture a demo photo"
    label.numberOfLines = 0
    label.textAlignment = .center
    label.textColor = .white
    label.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(label)

    NSLayoutConstraint.activate([
      label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
    ])

    view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(capture)))
  }

  @objc private func capture() {
    onCapture(Self.demoImageData())
    onDismiss()
  }

  private static func demoImageData() -> Data {
    let size = CGSize(width: 1024, height: 1024)
    let renderer = UIGraphicsImageRenderer(size: size)
    let image = renderer.image { ctx in
      UIColor(white: 0.12, alpha: 1).setFill()
      ctx.fill(CGRect(origin: .zero, size: size))
      let text = "MPG demo capture\n\(Date().formatted())"
      let style = NSMutableParagraphStyle()
      style.alignment = .center
      let attrs: [NSAttributedString.Key: Any] = [
        .foregroundColor: UIColor.white,
        .font: UIFont.systemFont(ofSize: 48, weight: .semibold),
        .paragraphStyle: style,
      ]
      text.draw(
        in: CGRect(x: 40, y: 460, width: size.width - 80, height: 200),
        withAttributes: attrs)
    }
    return image.jpegData(compressionQuality: 0.8) ?? Data()
  }
}

#Preview {
  PhotoCaptureView(allocation: AppStore().allocations[0]).environment(AppStore())
}
