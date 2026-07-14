import AVFoundation
import Foundation
import Speech

/// On-device voice capture + live transcription for the "speak your daily
/// record" flow. Uses `SFSpeechRecognizer` fed by an `AVAudioEngine` input tap
/// so the tradesman sees words appear as they talk. Audio is never persisted —
/// only the recognised text is kept, and it stays on-device.
@Observable
@MainActor
final class VoiceRecordService {

  enum State: Equatable {
    case idle
    case requestingPermission
    case listening
    case finished
    case denied
    case unavailable
    case failed(String)
  }

  private(set) var state: State = .idle
  /// Live transcript, updated as the person speaks.
  private(set) var transcript: String = ""
  /// Normalised input level 0…1 for the waveform.
  private(set) var level: Double = 0

  private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-GB"))
  private let engine = AVAudioEngine()
  private var request: SFSpeechAudioBufferRecognitionRequest?
  private var task: SFSpeechRecognitionTask?

  var isListening: Bool { state == .listening }

  // MARK: - Start / stop

  func start() {
    guard state != .listening else { return }
    transcript = ""
    level = 0
    state = .requestingPermission

    SFSpeechRecognizer.requestAuthorization { [weak self] auth in
      Task { @MainActor in
        guard let self else { return }
        guard auth == .authorized else {
          self.state = .denied
          return
        }
        AVAudioApplication.requestRecordPermission { granted in
          Task { @MainActor in
            guard granted else {
              self.state = .denied
              return
            }
            self.beginSession()
          }
        }
      }
    }
  }

  func stop() {
    engine.inputNode.removeTap(onBus: 0)
    if engine.isRunning { engine.stop() }
    request?.endAudio()
    task?.finish()
    request = nil
    task = nil
    level = 0
    try? AVAudioSession.sharedInstance().setActive(
      false, options: .notifyOthersOnDeactivation)
    if state == .listening { state = .finished }
  }

  func reset() {
    stop()
    transcript = ""
    state = .idle
  }

  // MARK: - Engine

  private func beginSession() {
    guard let recognizer, recognizer.isAvailable else {
      state = .unavailable
      return
    }

    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.record, mode: .measurement, options: .duckOthers)
      try session.setActive(true, options: .notifyOthersOnDeactivation)

      let request = SFSpeechAudioBufferRecognitionRequest()
      request.shouldReportPartialResults = true
      request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
      self.request = request

      let input = engine.inputNode
      let format = input.outputFormat(forBus: 0)
      input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
        request.append(buffer)
        self?.updateLevel(from: buffer)
      }

      engine.prepare()
      try engine.start()
      state = .listening

      task = recognizer.recognitionTask(with: request) { [weak self] result, error in
        Task { @MainActor in
          guard let self else { return }
          if let result {
            self.transcript = result.bestTranscription.formattedString
          }
          if error != nil, self.state == .listening {
            self.stop()
          }
        }
      }
    } catch {
      state = .failed(error.localizedDescription)
    }
  }

  private func updateLevel(from buffer: AVAudioPCMBuffer) {
    guard let channel = buffer.floatChannelData?[0] else { return }
    let frames = Int(buffer.frameLength)
    guard frames > 0 else { return }
    var sum: Float = 0
    for i in 0..<frames { sum += channel[i] * channel[i] }
    let rms = sqrt(sum / Float(frames))
    // Map RMS to a lively 0…1 range for the waveform.
    let scaled = min(1, Double(rms) * 12)
    Task { @MainActor in self.level = scaled }
  }
}
