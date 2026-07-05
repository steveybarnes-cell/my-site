import SwiftUI

struct NotificationsView: View {
  @Environment(AppStore.self) private var store
  private var me: AppUser? { store.currentUser }

  var body: some View {
    NavigationStack {
      ZStack {
        MPGBackground()
        ScrollView {
          VStack(spacing: 12) {
            let notes = me.map { store.notifications(for: $0.id) } ?? []
            if notes.isEmpty {
              EmptyStateView(
                symbol: "bell.slash", title: "No notifications",
                message: "Allocations, queries and payment updates will appear here."
              ).mpgCard()
            } else {
              ForEach(notes) { n in
                NotificationRow(note: n)
              }
            }
          }
          .padding(16)
        }
      }
      .navigationTitle("Notifications")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Mark read") { store.markAllNotificationsRead() }
            .disabled(store.unreadCount == 0)
        }
      }
    }
  }
}

struct NotificationRow: View {
  let note: AppNotification

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: note.symbol)
        .font(.title3)
        .foregroundStyle(note.read ? Brand.inkSoft : Brand.olive)
        .frame(width: 38, height: 38)
        .background(note.read ? Brand.hairline.opacity(0.4) : Brand.lightGreen, in: Circle())
      VStack(alignment: .leading, spacing: 3) {
        HStack {
          Text(note.type).font(.subheadline.weight(.semibold)).foregroundStyle(Brand.ink)
          Spacer()
          if !note.read { Circle().fill(Brand.olive).frame(width: 8, height: 8) }
        }
        Text(note.message).font(.footnote).foregroundStyle(Brand.inkSoft)
        Text(note.timestamp.formatted(.relative(presentation: .named)))
          .font(.caption2).foregroundStyle(Brand.inkSoft)
      }
    }
    .mpgCard(padding: 12)
  }
}

#Preview {
  NotificationsView().environment(
    {
      let s = AppStore()
      s.login(as: s.tradesmen().first!)
      return s
    }())
}
