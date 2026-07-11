import SwiftUI

/// Full-screen in-app call UI shown whenever a call is active. Placed as a
/// top-level overlay so a call stays visible across tab switches.
struct CallOverlay: View {
  @Environment(CallService.self) private var call

  var body: some View {
    if call.isActive {
      CallScreen()
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .zIndex(1000)
    }
  }
}

private struct CallScreen: View {
  @Environment(CallService.self) private var call

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [Brand.charcoal, Brand.charcoalDeep],
        startPoint: .top, endPoint: .bottom
      )
      .ignoresSafeArea()

      VStack(spacing: 0) {
        Spacer(minLength: 40)

        // Avatars
        if call.isGroup {
          groupAvatars
        } else {
          singleAvatar
        }

        VStack(spacing: 6) {
          Text(call.title)
            .font(.title.bold())
            .foregroundStyle(.white)
          Text(call.subtitle)
            .font(.headline)
            .foregroundStyle(.white.opacity(0.7))
            .contentTransition(.numericText())
            .monospacedDigit()
        }
        .padding(.top, 26)

        if call.isGroup {
          Text(call.participants.map(\.name).joined(separator: ", "))
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.55))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)
            .padding(.top, 10)
        }

        Spacer()

        controls
          .padding(.bottom, 50)
      }
    }
    .animation(.snappy, value: call.state)
  }

  private var singleAvatar: some View {
    ZStack {
      Circle().fill(Brand.olive)
      Image(systemName: call.participants.first?.role.icon ?? "person.fill")
        .font(.system(size: 52))
        .foregroundStyle(.white)
    }
    .frame(width: 132, height: 132)
    .overlay(
      Circle().stroke(.white.opacity(0.18), lineWidth: 6)
        .scaleEffect(call.state == .ringing ? 1.25 : 1)
        .opacity(call.state == .ringing ? 0 : 1)
        .animation(
          call.state == .ringing
            ? .easeOut(duration: 1.4).repeatForever(autoreverses: false) : .default,
          value: call.state)
    )
  }

  private var groupAvatars: some View {
    let shown = Array(call.participants.prefix(4))
    return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
      ForEach(shown) { p in
        VStack(spacing: 8) {
          ZStack {
            Circle().fill(Brand.olive)
            Image(systemName: p.role.icon).font(.title2).foregroundStyle(.white)
          }
          .frame(width: 74, height: 74)
          Text(p.name.split(separator: " ").first.map(String.init) ?? p.name)
            .font(.caption).foregroundStyle(.white.opacity(0.8)).lineLimit(1)
        }
      }
    }
    .frame(maxWidth: 260)
  }

  private var controls: some View {
    @Bindable var call = call
    return HStack(spacing: 28) {
      CallCircleButton(
        symbol: call.muted ? "mic.slash.fill" : "mic.fill",
        active: call.muted, label: "Mute"
      ) { call.muted.toggle() }

      Button {
        withAnimation(.snappy) { call.end() }
      } label: {
        ZStack {
          Circle().fill(Brand.red)
          Image(systemName: "phone.down.fill").font(.title).foregroundStyle(.white)
        }
        .frame(width: 76, height: 76)
      }
      .buttonStyle(.plain)

      CallCircleButton(
        symbol: call.speaker ? "speaker.wave.2.fill" : "speaker.fill",
        active: call.speaker, label: "Speaker"
      ) { call.speaker.toggle() }
    }
  }
}

private struct CallCircleButton: View {
  let symbol: String
  var active: Bool
  let label: String
  let action: () -> Void

  var body: some View {
    VStack(spacing: 6) {
      Button(action: action) {
        ZStack {
          Circle().fill(active ? .white : .white.opacity(0.16))
          Image(systemName: symbol)
            .font(.title3)
            .foregroundStyle(active ? Brand.charcoal : .white)
        }
        .frame(width: 60, height: 60)
      }
      .buttonStyle(.plain)
      Text(label).font(.caption2).foregroundStyle(.white.opacity(0.6))
    }
  }
}

// MARK: - Start-call picker

/// Sheet to choose who to call: tap a person for a 1:1 call, or select several
/// and start a group call.
struct StartCallView: View {
  @Environment(AppStore.self) private var store
  @Environment(CallService.self) private var call
  @Environment(\.dismiss) private var dismiss

  @State private var selection: Set<UUID> = []

  private var teammates: [AppUser] {
    store.users.filter { $0.active && $0.id != store.currentUser?.id }
      .sorted { $0.name < $1.name }
  }

  var body: some View {
    NavigationStack {
      ZStack {
        MPGBackground()
        ScrollView {
          VStack(spacing: 10) {
            Text("Tap a teammate to call them, or select several for a group call.")
              .font(.footnote)
              .foregroundStyle(Brand.inkSoft)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.bottom, 4)

            ForEach(teammates) { u in
              let on = selection.contains(u.id)
              Button {
                if selection.isEmpty {
                  // Immediate 1:1 call
                  startCall(with: [u], group: false)
                } else {
                  if on { selection.remove(u.id) } else { selection.insert(u.id) }
                }
              } label: {
                HStack(spacing: 12) {
                  ZStack {
                    Circle().fill(Brand.lightGreen)
                    Image(systemName: u.role.icon).foregroundStyle(Brand.oliveDark)
                  }
                  .frame(width: 42, height: 42)
                  VStack(alignment: .leading, spacing: 1) {
                    Text(u.name).font(.subheadline.weight(.semibold)).foregroundStyle(Brand.ink)
                    Text(u.role.rawValue).font(.caption).foregroundStyle(Brand.inkSoft)
                  }
                  Spacer()
                  Image(systemName: on ? "checkmark.circle.fill" : "phone.circle")
                    .font(.title3)
                    .foregroundStyle(on ? Brand.olive : Brand.inkSoft)
                }
                .mpgCard(padding: 12)
              }
              .buttonStyle(.plain)
              .onLongPressGesture {
                if on { selection.remove(u.id) } else { selection.insert(u.id) }
              }
            }
          }
          .padding(16)
        }
      }
      .navigationTitle("New Call")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            let people = teammates.filter { selection.contains($0.id) }
            startCall(with: people, group: true)
          } label: {
            Label("Call \(selection.count)", systemImage: "phone.fill")
          }
          .disabled(selection.count < 2)
        }
      }
    }
    .__tenxTrackView("StartCallView")
  }

  private func startCall(with users: [AppUser], group: Bool) {
    let people = users.map { CallParticipant(id: $0.id, name: $0.name, role: $0.role) }
    dismiss()
    withAnimation(.snappy) {
      call.start(people, group: group)
    }
  }
}

#Preview {
  StartCallView()
    .environment(
      {
        let s = AppStore()
        s.login(as: s.users.first!)
        return s
      }()
    )
    .environment(CallService())
}
