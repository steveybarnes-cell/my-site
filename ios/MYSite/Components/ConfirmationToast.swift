import SwiftUI

/// A brief "that landed" message after anything is saved or sent.
///
/// Everything in this app is fire-and-forget: the row goes into the local
/// store, the screen dismisses, and the upload happens behind you. That is the
/// right design on a site with two bars of signal — but from the outside it is
/// indistinguishable from nothing having happened, so people tap Save twice and
/// then ring the office to check.
///
/// Deliberately not a modal. An alert you have to dismiss after every single
/// action is worse than no feedback at all; this appears, is legible for two
/// seconds, and goes.
struct ConfirmationToast: View {
  @Environment(AppStore.self) private var store

  var body: some View {
    VStack {
      if let text = store.confirmation {
        HStack(spacing: 9) {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 15, weight: .semibold))
          Text(text)
            .font(.subheadline.weight(.medium))
            .lineLimit(2)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(Brand.charcoal.opacity(0.96), in: Capsule())
        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
        .accessibilityAddTraits(.isStaticText)
      }
      Spacer()
    }
    .animation(.spring(response: 0.32, dampingFraction: 0.85), value: store.confirmation)
    // Never intercept a tap. The toast sits over the screen the person is
    // still using, and a save confirmation that swallows the next button
    // press is worse than the silence it replaced.
    .allowsHitTesting(false)
  }
}

extension View {
  /// Shows save confirmations over this view. Applied once per root.
  func mpgConfirmations() -> some View {
    overlay(alignment: .top) { ConfirmationToast() }
  }
}
