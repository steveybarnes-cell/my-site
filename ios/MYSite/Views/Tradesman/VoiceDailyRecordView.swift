import SwiftUI

/// Full-screen "speak your daily record" flow. The tradesman taps the mic,
/// talks through their day, and the app transcribes on-device then shows the
/// structured fields it detected. Nothing is saved until they tap Apply — the
/// parsed values pre-fill the Daily Site Record form for review.
struct VoiceDailyRecordView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var voice = VoiceRecordService()
  let onApply: (DailyRecordParser.Result) -> Void

  private var parsed: DailyRecordParser.Result {
    DailyRecordParser.parse(voice.transcript)
  }

  private var hasTranscript: Bool {
    !voice.transcript.trimmingCharacters(in: .whitespaces).isEmpty
  }

  var body: some View {
    NavigationStack {
      ZStack {
        MPGBackground()
        ScrollView {
          VStack(spacing: 20) {
            prompt
            micStage
            if hasTranscript { transcriptCard }
            if voice.state == .finished && hasTranscript { detectedCard }
            permissionNotice
          }
          .padding(16)
        }
      }
      .navigationTitle("Speak your record")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            voice.reset()
            dismiss()
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Apply") {
            voice.stop()
            onApply(parsed)
            dismiss()
          }
          .fontWeight(.semibold)
          .disabled(!hasTranscript)
        }
      }
    }
    .onDisappear { voice.reset() }
    .__tenxTrackView("VoiceDailyRecordView")
  }

  // MARK: - Prompt

  private var prompt: some View {
    VStack(spacing: 8) {
      Image(systemName: "waveform.badge.mic")
        .font(.title)
        .foregroundStyle(Brand.olive)
      Text("Say what you did today")
        .font(.headline).foregroundStyle(Brand.ink)
      Text(
        "Talk naturally — start and finish times, the work you carried out, any break, and anything that held you up. We'll fill in the record for you to check."
      )
      .font(.footnote)
      .foregroundStyle(Brand.inkSoft)
      .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .mpgCard(padding: 18)
  }

  // MARK: - Mic

  private var micStage: some View {
    VStack(spacing: 16) {
      WaveformBars(level: voice.level, active: voice.isListening)
        .frame(height: 54)

      Button {
        if voice.isListening { voice.stop() } else { voice.start() }
      } label: {
        ZStack {
          Circle()
            .fill(voice.isListening ? Brand.red : Brand.olive)
            .frame(width: 84, height: 84)
            .shadow(color: (voice.isListening ? Brand.red : Brand.olive).opacity(0.35), radius: 12)
          Image(systemName: voice.isListening ? "stop.fill" : "mic.fill")
            .font(.system(size: 32, weight: .bold))
            .foregroundStyle(.white)
        }
      }
      .buttonStyle(.plain)

      Text(statusText)
        .font(.subheadline.weight(.medium))
        .foregroundStyle(Brand.inkSoft)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 8)
  }

  private var statusText: String {
    switch voice.state {
    case .idle: return "Tap to start recording"
    case .requestingPermission: return "Preparing…"
    case .listening: return "Listening — tap to stop"
    case .finished: return "Review below, then tap Apply"
    case .denied: return "Microphone or speech access is off"
    case .unavailable: return "Speech recognition unavailable"
    case .failed(let m): return m
    }
  }

  // MARK: - Transcript

  private var transcriptCard: some View {
    VStack(alignment: .leading, spacing: 8) {
      SectionHeader(title: "What we heard")
      Text(voice.transcript)
        .font(.body)
        .foregroundStyle(Brand.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .mpgFormSection()
  }

  // MARK: - Detected fields

  private var detectedCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      SectionHeader(title: "Detected details")
      detectedRow("clock", "Start", parsed.startTime ?? "—")
      detectedRow("clock.badge.checkmark", "Finish", parsed.finishTime ?? "—")
      if let b = parsed.breakMinutes {
        detectedRow("cup.and.saucer.fill", "Break", "\(b) min")
      }
      if let c = parsed.category {
        detectedRow("hammer.fill", "Category", c.rawValue)
      }
      if let d = parsed.delay, d != .none {
        detectedRow("exclamationmark.triangle.fill", "Delay", d.rawValue)
      }
      Text("Anything not detected is left for you to fill in on the next screen.")
        .font(.caption)
        .foregroundStyle(Brand.inkSoft)
        .padding(.top, 2)
    }
    .mpgFormSection()
  }

  private func detectedRow(_ symbol: String, _ label: String, _ value: String) -> some View {
    HStack(spacing: 10) {
      Image(systemName: symbol).foregroundStyle(Brand.olive).frame(width: 22)
      Text(label).font(.subheadline).foregroundStyle(Brand.inkSoft)
      Spacer()
      Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(Brand.ink)
    }
  }

  // MARK: - Permission notice

  @ViewBuilder private var permissionNotice: some View {
    if voice.state == .denied {
      WarningBanner(
        message:
          "Enable Microphone and Speech Recognition for MPG Site Records in Settings to speak your record.",
        symbol: "mic.slash.fill", tint: Brand.red)
    }
  }
}

// MARK: - Waveform

private struct WaveformBars: View {
  let level: Double
  let active: Bool
  private let count = 21

  var body: some View {
    HStack(spacing: 4) {
      ForEach(0..<count, id: \.self) { i in
        Capsule()
          .fill(active ? Brand.olive : Brand.olive.opacity(0.25))
          .frame(width: 4, height: barHeight(i))
      }
    }
    .animation(.easeOut(duration: 0.15), value: level)
  }

  private func barHeight(_ i: Int) -> CGFloat {
    let mid = Double(count - 1) / 2
    let dist = abs(Double(i) - mid) / mid
    let falloff = 1 - dist * 0.7
    let base = 6.0
    let peak = active ? (level * 48 * falloff) : 0
    return CGFloat(base + peak + (active ? Double.random(in: 0...6) * falloff : 0))
  }
}
