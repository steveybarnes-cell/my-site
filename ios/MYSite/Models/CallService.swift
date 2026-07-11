import Observation
import SwiftUI

/// A single participant in a call (a team member).
struct CallParticipant: Identifiable, Hashable {
  let id: UUID
  var name: String
  var role: UserRole
}

/// Drives the in-app calling experience. This is a modelled/mock VoIP screen:
/// it simulates ringing → connected → call timer for one-to-one and group
/// calls so the whole flow is demonstrable. A real backend (CallKit + a VoIP
/// provider) swaps in behind `start`/`end` without changing the UI.
@Observable
final class CallService {
  enum State: Equatable {
    case idle
    case ringing
    case connected
  }

  private(set) var state: State = .idle
  private(set) var participants: [CallParticipant] = []
  private(set) var isGroup = false
  /// Elapsed connected time in seconds.
  private(set) var elapsed = 0
  var muted = false
  var speaker = true

  private var timer: Timer?

  var isActive: Bool { state != .idle }

  var title: String {
    if isGroup { return "Group call" }
    return participants.first?.name ?? "Call"
  }

  var subtitle: String {
    switch state {
    case .idle: return ""
    case .ringing: return isGroup ? "Ringing \(participants.count) people…" : "Ringing…"
    case .connected: return elapsedString
    }
  }

  var elapsedString: String {
    let m = elapsed / 60
    let s = elapsed % 60
    return String(format: "%02d:%02d", m, s)
  }

  /// Start a call to one or more participants.
  func start(_ people: [CallParticipant], group: Bool) {
    guard !people.isEmpty else { return }
    participants = people
    isGroup = group || people.count > 1
    elapsed = 0
    muted = false
    speaker = true
    state = .ringing
    // Simulate the callee(s) answering after a short ring.
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { [weak self] in
      guard let self, self.state == .ringing else { return }
      self.connect()
    }
  }

  private func connect() {
    state = .connected
    timer?.invalidate()
    timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
      self?.elapsed += 1
    }
  }

  func end() {
    timer?.invalidate()
    timer = nil
    state = .idle
    participants = []
    isGroup = false
    elapsed = 0
  }
}
