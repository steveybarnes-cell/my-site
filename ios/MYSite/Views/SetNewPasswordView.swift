import SwiftUI

/// Shown when the app is opened from a password-reset email.
///
/// The recovery link carries a short-lived session in its URL fragment. That
/// session is held but deliberately not adopted until a new password is set —
/// otherwise tapping the link would sign someone straight in, which turns a
/// forwarded email into a way past the password entirely.
struct SetNewPasswordView: View {
  @Environment(AuthManager.self) private var auth
  @Environment(\.dismiss) private var dismiss

  @State private var password = ""
  @State private var confirmation = ""

  /// Supabase rejects anything under 6 by default; 8 is a more sensible floor
  /// for an app holding payroll and bank details.
  private let minimumLength = 8

  private var tooShort: Bool { password.count < minimumLength }
  private var mismatched: Bool { !confirmation.isEmpty && confirmation != password }
  private var canSubmit: Bool {
    !tooShort && password == confirmation && !auth.isWorking
  }

  var body: some View {
    NavigationStack {
      ZStack {
        Brand.charcoal.ignoresSafeArea()
        ScrollView {
          VStack(spacing: 18) {
            header
            card
          }
          .padding(16)
        }
      }
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            auth.cancelPasswordReset()
            dismiss()
          }
          .foregroundStyle(.white.opacity(0.8))
        }
      }
    }
    .__tenxTrackView("SetNewPasswordView")
  }

  private var header: some View {
    VStack(spacing: 8) {
      MPGLogo(height: 100).padding(.top, 10)
      Text("Choose a new password")
        .font(.title3.bold())
        .foregroundStyle(.white)
      Text(auth.recoveryEmail.map { "for \($0)" } ?? "Your reset link has been verified.")
        .font(.subheadline)
        .foregroundStyle(.white.opacity(0.65))
        .multilineTextAlignment(.center)
    }
  }

  private var card: some View {
    VStack(alignment: .leading, spacing: 14) {
      SectionHeader(title: "New password")

      secureField("New password", text: $password)
      secureField("Confirm new password", text: $confirmation)

      // Requirements are stated up front rather than only on failure, so
      // nobody discovers the rule by being rejected by it.
      Label(
        tooShort
          ? "At least \(minimumLength) characters."
          : "Long enough.",
        systemImage: tooShort ? "circle" : "checkmark.circle.fill"
      )
      .font(.caption)
      .foregroundStyle(tooShort ? Brand.inkSoft : Brand.paidGreen)

      if mismatched {
        Label("Those two don't match.", systemImage: "exclamationmark.circle.fill")
          .font(.caption)
          .foregroundStyle(Brand.red)
      }

      if let message = auth.errorMessage {
        Label(message, systemImage: "exclamationmark.triangle.fill")
          .font(.caption)
          .foregroundStyle(Brand.red)
          .frame(maxWidth: .infinity, alignment: .leading)
      }

      PrimaryButton(
        title: auth.isWorking ? "Saving…" : "Save and sign in",
        symbol: auth.isWorking ? "hourglass" : "checkmark"
      ) {
        Task {
          if await auth.updatePassword(password) { dismiss() }
        }
      }
      .disabled(!canSubmit)
      .opacity(canSubmit ? 1 : 0.6)
    }
    .padding(18)
    .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
  }

  private func secureField(_ placeholder: String, text: Binding<String>) -> some View {
    HStack(spacing: 10) {
      Image(systemName: "lock").foregroundStyle(Brand.olive).frame(width: 20)
      SecureField(placeholder, text: text)
        .textContentType(.newPassword)
        .font(.subheadline)
    }
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

/// Asks for an email address and sends the recovery link.
///
/// Always reports the same thing whether or not the address is registered —
/// the auth server behaves that way too, and it stops this screen being used
/// to work out who has an account.
struct ForgotPasswordSheet: View {
  @Environment(AuthManager.self) private var auth
  @Environment(\.dismiss) private var dismiss

  /// Pre-filled from whatever they'd already typed on the login screen.
  let initialEmail: String
  @State private var email: String
  @State private var sent = false

  init(initialEmail: String = "") {
    self.initialEmail = initialEmail
    _email = State(initialValue: initialEmail)
  }

  private var canSend: Bool {
    email.contains("@") && email.contains(".") && !auth.isWorking
  }

  var body: some View {
    NavigationStack {
      ZStack {
        MPGBackground()
        ScrollView {
          VStack(alignment: .leading, spacing: 14) {
            if sent {
              Label(
                auth.resetNotice ?? "Check your inbox.",
                systemImage: "envelope.badge.fill"
              )
              .font(.subheadline)
              .foregroundStyle(Brand.ink)
              .frame(maxWidth: .infinity, alignment: .leading)

              Text(
                "The link opens straight back into this app. It expires after an hour, "
                  + "and only the most recent one works."
              )
              .font(.caption)
              .foregroundStyle(Brand.inkSoft)
            } else {
              SectionHeader(
                title: "Reset your password",
                subtitle: "We'll email you a link that opens back in the app")

              HStack(spacing: 10) {
                Image(systemName: "envelope").foregroundStyle(Brand.olive).frame(width: 20)
                TextField("Email address", text: $email)
                  .keyboardType(.emailAddress)
                  .textContentType(.emailAddress)
                  .autocorrectionDisabled()
                  .textInputAutocapitalization(.never)
                  .font(.subheadline)
              }
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

              if let message = auth.errorMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                  .font(.caption).foregroundStyle(Brand.red)
              }

              PrimaryButton(
                title: auth.isWorking ? "Sending…" : "Send reset link",
                symbol: auth.isWorking ? "hourglass" : "paperplane.fill"
              ) {
                Task {
                  await auth.sendPasswordReset(email: email)
                  if auth.errorMessage == nil { sent = true }
                }
              }
              .disabled(!canSend)
              .opacity(canSend ? 1 : 0.6)
            }
          }
          .mpgCard()
          .padding(16)
        }
      }
      .navigationTitle("Forgotten password")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button(sent ? "Done" : "Cancel") { dismiss() }
        }
      }
    }
    .__tenxTrackView("ForgotPasswordSheet")
  }
}
