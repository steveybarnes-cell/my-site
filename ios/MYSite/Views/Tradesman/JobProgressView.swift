import SwiftUI

/// How far along a job is, moved by the man doing it.
///
/// Buttons rather than a slider. A slider is precise, and precision is exactly
/// what nobody has here — "about half the room" is the honest answer, and a
/// control that invites 47% invites a false one. Five taps also survive gloves,
/// one hand, and a phone held at arm's length in the rain.
struct JobProgressControl: View {
  @Environment(AppStore.self) private var store
  let allocation: WorkAllocation

  /// The step being confirmed.
  ///
  /// A wrapper struct rather than a bare `Int?` so this can drive
  /// `.sheet(item:)`. The previous version set `pending` and a separate
  /// `showNote` flag in the same tap and unwrapped the optional inside
  /// `.sheet(isPresented:)` — SwiftUI can evaluate that content before the
  /// state change lands, the `if let` fails, and you get a blank white sheet.
  /// With `.sheet(item:)` the value IS the trigger, so there is nothing to
  /// race: no item, no sheet; item present, content guaranteed.
  private struct PendingStep: Identifiable {
    let id = UUID()
    let percent: Int
  }
  @State private var pending: PendingStep?

  private var live: WorkAllocation {
    store.allocations.first { $0.id == allocation.id } ?? allocation
  }
  private var percent: Int { live.percentComplete }

  private let steps = [0, 25, 50, 75, 100]

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .firstTextBaseline) {
        Text("How far along?")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(Brand.ink)
        Spacer()
        Text("\(percent)%")
          .font(.title3.bold())
          .monospacedDigit()
          .foregroundStyle(percent >= 100 ? Brand.oliveDark : Brand.ink)
      }

      GeometryReader { geo in
        ZStack(alignment: .leading) {
          Capsule().fill(Brand.lightGreen)
          Capsule().fill(Brand.olive)
            .frame(width: max(0, geo.size.width * CGFloat(percent) / 100))
        }
      }
      .frame(height: 10)
      .animation(.easeOut(duration: 0.25), value: percent)

      HStack(spacing: 6) {
        ForEach(steps, id: \.self) { step in
          Button {
            pending = PendingStep(percent: step)
          } label: {
            Text(step == 100 ? "Done" : "\(step)%")
              .font(.footnote.weight(percent == step ? .bold : .medium))
              .frame(maxWidth: .infinity)
              .padding(.vertical, 9)
              .background(
                percent == step ? Brand.olive : Brand.surface,
                in: Capsule())
              .foregroundStyle(percent == step ? .white : Brand.inkSoft)
              .overlay(Capsule().stroke(Brand.hairline, lineWidth: percent == step ? 0 : 1))
          }
          .buttonStyle(.plain)
        }
      }

      if !live.progressNote.isEmpty {
        Text(live.progressNote)
          .font(.caption)
          .foregroundStyle(Brand.inkSoft)
      }
      if let when = live.progressUpdatedAt {
        Text("Updated \(Fmt.time(when))")
          .font(.caption2)
          .foregroundStyle(Brand.inkSoft)
      }
    }
    .sheet(item: $pending) { step in
      ProgressNoteSheet(allocation: live, percent: step.percent)
    }
  }
}

/// Confirms a change and takes an optional note.
///
/// A note is asked for, never required. Forcing one on every tap means the tap
/// stops happening, and a progress bar nobody moves is worse than a bare number.
struct ProgressNoteSheet: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss

  let allocation: WorkAllocation
  let percent: Int

  @State private var note = ""

  var body: some View {
    NavigationStack {
      Form {
        Section {
          HStack {
            Text(allocation.taskDescription.isEmpty ? "This job" : allocation.taskDescription)
              .font(.subheadline.weight(.medium))
            Spacer()
            Text(percent == 100 ? "Done" : "\(percent)%")
              .font(.headline)
              .foregroundStyle(Brand.oliveDark)
          }
        }
        // `Section(title) { } footer: { }` does not exist in SwiftUI — there is
        // a title+content form and a content+header+footer form, and nothing
        // that mixes the two. Spelling the header out is the only version that
        // compiles.
        Section {
          DictationField(
            placeholder: "Optional — held up waiting on the sparks",
            text: $note, lines: 2...4)
        } header: {
          Text("Anything worth saying?")
        } footer: {
          Text("Goes to the office with your name and the time, so nobody has to ring you to ask.")
        }
      }
      .navigationTitle(percent == 100 ? "Mark it done" : "Update progress")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            store.setProgress(
              allocation.id, to: percent,
              note: note.trimmingCharacters(in: .whitespacesAndNewlines))
            dismiss()
          }
        }
      }
    }
  }
}
