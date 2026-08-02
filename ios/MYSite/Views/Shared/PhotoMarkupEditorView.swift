import SwiftUI

/// Draw-and-write editor for a single photo before it is posted.
///
/// Everything is authored in normalised (0...1) coordinates against the photo's
/// aspect-fitted rect, so the same `PhotoMarkup` renders identically in the
/// editor, in a 300pt feed card, and burned into the exported JPEG.
struct PhotoMarkupEditorView: View {
  let image: UIImage
  @Environment(\.dismiss) private var dismiss

  /// Called with the finished markup when the user taps Done.
  var onDone: (PhotoMarkup) -> Void

  @State private var markup: PhotoMarkup
  @State private var tool: PhotoAnnotation.Kind = .pen
  @State private var colorHex: String = MarkupPalette.defaultColor
  @State private var weight: StrokeWeight = .medium

  /// The annotation currently under the finger, drawn but not yet committed.
  @State private var inProgress: PhotoAnnotation?

  /// Pending `.text` placement: the tapped point, held while the user types.
  @State private var pendingTextPoint: CGPoint?
  @State private var pendingText: String = ""
  @State private var showTextField = false

  init(image: UIImage, markup: PhotoMarkup = PhotoMarkup(), onDone: @escaping (PhotoMarkup) -> Void)
  {
    self.image = image
    self.onDone = onDone
    _markup = State(initialValue: markup)
  }

  // MARK: - Stroke weight

  enum StrokeWeight: String, CaseIterable, Identifiable {
    case thin, medium, thick
    var id: String { rawValue }

    var lineWidth: CGFloat {
      switch self {
      case .thin: return 2.5
      case .medium: return 5
      case .thick: return 9
      }
    }

    /// Text labels scale with the same control, so one size picker drives both.
    var fontScale: CGFloat {
      switch self {
      case .thin: return 0.038
      case .medium: return 0.055
      case .thick: return 0.085
      }
    }

    var dotSize: CGFloat {
      switch self {
      case .thin: return 7
      case .medium: return 12
      case .thick: return 18
      }
    }
  }

  // MARK: - Body

  var body: some View {
    NavigationStack {
      ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: 0) {
          canvas
            .frame(maxWidth: .infinity, maxHeight: .infinity)
          toolbar
        }
      }
      .navigationTitle("Mark up photo")
      .navigationBarTitleDisplayMode(.inline)
      .toolbarBackground(.black, for: .navigationBar)
      .toolbarBackground(.visible, for: .navigationBar)
      .toolbarColorScheme(.dark, for: .navigationBar)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") {
            onDone(markup)
            dismiss()
          }
          .fontWeight(.semibold)
        }
      }
      .alert("Add label", isPresented: $showTextField) {
        TextField("e.g. Crack in render", text: $pendingText)
        Button("Cancel", role: .cancel) { clearPendingText() }
        Button("Add") { commitPendingText() }
      } message: {
        Text("This writes on the photo where you tapped.")
      }
    }
    .__tenxTrackView("PhotoMarkupEditorView")
  }

  // MARK: - Canvas

  private var canvas: some View {
    GeometryReader { geo in
      let fitted = Self.fittedSize(for: image.size, in: geo.size)
      ZStack {
        Image(uiImage: image)
          .resizable()
          .scaledToFit()

        PhotoMarkupOverlay(markup: liveMarkup)
      }
      .frame(width: fitted.width, height: fitted.height)
      .contentShape(Rectangle())
      .gesture(drawGesture(in: fitted))
      .position(x: geo.size.width / 2, y: geo.size.height / 2)
    }
    .padding(8)
  }

  /// The committed markup plus whatever is currently under the finger, so the
  /// stroke appears live rather than only on release.
  private var liveMarkup: PhotoMarkup {
    guard let inProgress else { return markup }
    var m = markup
    m.annotations.append(inProgress)
    return m
  }

  // MARK: - Drawing

  private func drawGesture(in fitted: CGSize) -> some Gesture {
    DragGesture(minimumDistance: 0)
      .onChanged { value in
        let point = Self.normalise(value.location, in: fitted)

        // Text is placed by tap, not dragged — handled on release.
        guard tool != .text else { return }

        if var current = inProgress {
          switch tool {
          case .pen:
            // Skip near-duplicate samples: a freehand stroke otherwise
            // accumulates hundreds of points and slows the overlay down.
            if let last = current.points.last,
              abs(last.x - point.x) < 0.004, abs(last.y - point.y) < 0.004
            {
              return
            }
            current.points.append(point)
          case .arrow, .highlight, .circle:
            current.points = [current.points.first ?? point, point]
          case .text:
            return
          }
          inProgress = current
        } else {
          let start = Self.normalise(value.startLocation, in: fitted)
          inProgress = PhotoAnnotation(
            kind: tool,
            colorHex: colorHex,
            lineWidth: weight.lineWidth,
            points: tool == .pen ? [start, point] : [start, point],
            fontScale: weight.fontScale)
        }
      }
      .onEnded { value in
        if tool == .text {
          pendingTextPoint = Self.normalise(value.location, in: fitted)
          pendingText = ""
          showTextField = true
          return
        }
        if let finished = inProgress, isMeaningful(finished) {
          markup.annotations.append(finished)
        }
        inProgress = nil
      }
  }

  /// Discards accidental taps that would leave an invisible zero-length mark.
  private func isMeaningful(_ ann: PhotoAnnotation) -> Bool {
    guard let first = ann.points.first, let last = ann.points.last else { return false }
    if ann.kind == .pen { return ann.points.count > 2 }
    return abs(last.x - first.x) > 0.01 || abs(last.y - first.y) > 0.01
  }

  private func commitPendingText() {
    let trimmed = pendingText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let point = pendingTextPoint, !trimmed.isEmpty else {
      clearPendingText()
      return
    }
    markup.annotations.append(
      PhotoAnnotation(
        kind: .text,
        colorHex: colorHex,
        lineWidth: weight.lineWidth,
        points: [point],
        text: trimmed,
        fontScale: weight.fontScale))
    clearPendingText()
  }

  private func clearPendingText() {
    pendingTextPoint = nil
    pendingText = ""
  }

  // MARK: - Toolbar

  private var toolbar: some View {
    VStack(spacing: 14) {
      HStack(spacing: 8) {
        ForEach(Self.tools, id: \.kind) { entry in
          toolButton(entry.kind, symbol: entry.symbol, label: entry.label)
        }
      }

      HStack(spacing: 14) {
        ForEach(MarkupPalette.colors, id: \.self) { hex in
          Button {
            colorHex = hex
          } label: {
            Circle()
              .fill(Color.markup(hex))
              .frame(width: 26, height: 26)
              .overlay(
                Circle().stroke(.white, lineWidth: colorHex == hex ? 3 : 1)
              )
              .shadow(color: .black.opacity(0.4), radius: 1)
          }
          .buttonStyle(.plain)
          .accessibilityLabel(Self.colorName(hex))
        }
      }

      HStack(spacing: 18) {
        ForEach(StrokeWeight.allCases) { w in
          Button {
            weight = w
          } label: {
            Circle()
              .fill(Color.markup(colorHex))
              .frame(width: w.dotSize, height: w.dotSize)
              .frame(width: 34, height: 34)
              .background(
                Circle().fill(weight == w ? Color.white.opacity(0.22) : Color.clear)
              )
          }
          .buttonStyle(.plain)
          .accessibilityLabel("\(w.rawValue.capitalized) stroke")
        }

        Spacer()

        Button {
          if !markup.annotations.isEmpty { markup.annotations.removeLast() }
        } label: {
          Label("Undo", systemImage: "arrow.uturn.backward")
            .labelStyle(.iconOnly)
            .font(.system(size: 17, weight: .semibold))
            .frame(width: 38, height: 38)
            .background(Circle().fill(Color.white.opacity(0.14)))
        }
        .buttonStyle(.plain)
        .disabled(markup.annotations.isEmpty)
        .opacity(markup.annotations.isEmpty ? 0.35 : 1)

        Button {
          markup.annotations.removeAll()
        } label: {
          Label("Clear", systemImage: "trash")
            .labelStyle(.iconOnly)
            .font(.system(size: 17, weight: .semibold))
            .frame(width: 38, height: 38)
            .background(Circle().fill(Color.white.opacity(0.14)))
        }
        .buttonStyle(.plain)
        .disabled(markup.annotations.isEmpty)
        .opacity(markup.annotations.isEmpty ? 0.35 : 1)
      }
      .foregroundStyle(.white)
    }
    .padding(.horizontal, 16)
    .padding(.top, 14)
    .padding(.bottom, 8)
    .background(.black)
  }

  private func toolButton(_ kind: PhotoAnnotation.Kind, symbol: String, label: String) -> some View {
    let active = tool == kind
    return Button {
      tool = kind
    } label: {
      VStack(spacing: 3) {
        Image(systemName: symbol).font(.system(size: 17, weight: .semibold))
        Text(label).font(.system(size: 10, weight: .medium))
      }
      .foregroundStyle(active ? .black : .white)
      .frame(maxWidth: .infinity)
      .frame(height: 48)
      .background(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(active ? Brand.olive.opacity(0.95) : Color.white.opacity(0.14))
      )
    }
    .buttonStyle(.plain)
    .accessibilityLabel(label)
    .accessibilityAddTraits(active ? [.isSelected] : [])
  }

  private static let tools:
    [(kind: PhotoAnnotation.Kind, symbol: String, label: String)] = [
      (.pen, "scribble", "Draw"),
      (.arrow, "arrow.up.right", "Arrow"),
      (.highlight, "rectangle", "Box"),
      (.circle, "circle", "Circle"),
      (.text, "textformat", "Text"),
    ]

  private static func colorName(_ hex: String) -> String {
    switch hex {
    case "#FF3B30": return "Red"
    case "#FF9500": return "Orange"
    case "#FFCC00": return "Yellow"
    case "#34C759": return "Green"
    case "#0A84FF": return "Blue"
    default: return "White"
    }
  }

  // MARK: - Geometry

  /// The aspect-fitted rect the photo actually occupies inside `available`.
  /// Gestures are measured against this, never the container, so a tap lands on
  /// the same pixel the user sees regardless of letterboxing.
  static func fittedSize(for imageSize: CGSize, in available: CGSize) -> CGSize {
    guard imageSize.width > 0, imageSize.height > 0,
      available.width > 0, available.height > 0
    else { return available }
    let scale = min(available.width / imageSize.width, available.height / imageSize.height)
    return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
  }

  static func normalise(_ point: CGPoint, in size: CGSize) -> CGPoint {
    guard size.width > 0, size.height > 0 else { return .zero }
    return CGPoint(
      x: min(max(point.x / size.width, 0), 1),
      y: min(max(point.y / size.height, 0), 1))
  }
}
