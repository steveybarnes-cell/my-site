import SwiftUI

/// A text field you can talk into.
///
/// Typing is the wrong input for this app. The person using it is standing on a
/// board with cold hands, often in gloves, often holding something else — and
/// the alternative to speaking is not careful typing, it is not writing
/// anything down at all. So every field that takes words gets a microphone.
///
/// Transcription is Apple's, on-device where the phone supports it, so what is
/// said on site does not leave the phone to become text. The AI tidy-up is a
/// separate, opt-in step afterwards.
struct DictationField: View {
  let placeholder: String
  @Binding var text: String
  /// Multi-line fields grow; a one-line field like "20 sheets" should not.
  var lines: ClosedRange<Int> = 1...4
  /// Offer the AI tidy-up under the field. Worth it for a day's work; noise
  /// for "12.5mm plasterboard".
  var tidyable: Bool = false

  @Environment(AppStore.self) private var store
  @State private var voice = VoiceRecordService()
  @State private var textBeforeDictation = ""
  @State private var tidying = false
  @State private var suggestion: String?
  @State private var note: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .bottom, spacing: 10) {
        TextField(placeholder, text: $text, axis: .vertical)
          .lineLimit(lines)
        micButton
      }

      if voice.isListening {
        HStack(spacing: 8) {
          // A level meter, not a spinner: it proves the microphone is actually
          // hearing you, which is the only question you have while talking.
          ForEach(0..<12, id: \.self) { i in
            Capsule()
              .fill(Brand.olive)
              .frame(width: 3, height: barHeight(i))
          }
          Text("Listening — tap the mic to stop")
            .font(.caption)
            .foregroundStyle(Brand.inkSoft)
        }
        .animation(.easeOut(duration: 0.12), value: voice.level)
      }

      if let message = permissionMessage {
        Text(message).font(.caption).foregroundStyle(Brand.amber)
      }

      if tidyable {
        tidyRow
      }
      if let note {
        Text(note).font(.caption).foregroundStyle(Brand.inkSoft)
      }
      if let suggestion {
        suggestionBox(suggestion)
      }
    }
    .onChange(of: voice.transcript) { _, latest in
      guard voice.isListening else { return }
      // Rebuilt from the snapshot each time rather than appended to. The
      // recogniser revises what it thought you said as you keep talking, so
      // appending each partial result gives "put the pb put the plasterboard".
      let spoken = latest.trimmingCharacters(in: .whitespaces)
      text = textBeforeDictation.isEmpty
        ? spoken
        : (spoken.isEmpty ? textBeforeDictation : textBeforeDictation + " " + spoken)
    }
  }

  // MARK: - Microphone

  private var micButton: some View {
    Button {
      if voice.isListening {
        voice.stop()
      } else {
        textBeforeDictation = text.trimmingCharacters(in: .whitespaces)
        voice.start()
      }
    } label: {
      Image(systemName: voice.isListening ? "stop.circle.fill" : "mic.fill")
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(voice.isListening ? .white : Brand.oliveDark)
        .frame(width: 38, height: 38)
        .background(
          voice.isListening ? Brand.olive : Brand.lightGreen,
          in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
    .buttonStyle(.plain)
    .accessibilityLabel(voice.isListening ? "Stop dictating" : "Dictate")
  }

  private func barHeight(_ i: Int) -> CGFloat {
    // Middle bars react most, so it reads as a voice rather than a bar chart.
    let centre = 1 - abs(Double(i) - 5.5) / 6.5
    return 4 + CGFloat(voice.level * centre * 18)
  }

  private var permissionMessage: String? {
    switch voice.state {
    case .denied:
      return "Microphone or speech access is off. Turn it on in Settings to dictate."
    case .unavailable:
      return "Dictation isn't available on this device right now."
    case .failed(let why):
      return "Dictation stopped: \(why)"
    default:
      return nil
    }
  }

  // MARK: - Tidy up

  private var tidyRow: some View {
    HStack {
      Button {
        Task { await tidy() }
      } label: {
        if tidying {
          HStack(spacing: 6) {
            ProgressView().controlSize(.small)
            Text("Tidying…")
          }
        } else {
          Label("Tidy up for the log", systemImage: "wand.and.sparkles")
        }
      }
      .font(.footnote.weight(.medium))
      .disabled(tidying || voice.isListening
        || text.trimmingCharacters(in: .whitespacesAndNewlines).count < 15)
      Spacer()
    }
  }

  private func suggestionBox(_ suggestion: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Suggested").font(.caption.weight(.semibold)).foregroundStyle(Brand.oliveDark)
      Text(suggestion).font(.subheadline).foregroundStyle(Brand.ink)
      HStack(spacing: 8) {
        Button("Use this") {
          text = suggestion
          self.suggestion = nil
        }
        .font(.footnote.weight(.semibold))
        Button("Keep mine") { self.suggestion = nil }
          .font(.footnote)
          .foregroundStyle(Brand.inkSoft)
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Brand.lightGreen, in: RoundedRectangle(cornerRadius: 10))
  }

  private func tidy() async {
    guard let token = store.backendToken else {
      note = "You need to be signed in for this."
      return
    }
    tidying = true
    note = nil
    let result = await TidyNoteService.tidy(text, token: token)
    tidying = false
    if result.changed, result.text != text {
      suggestion = result.text
    } else {
      note = TidyNoteService.message(for: result.reason) ?? "Nothing to change — it reads fine."
    }
  }
}
