import SwiftUI

/// Full comment thread for a feed post, with an inline composer at the bottom.
struct FeedCommentsView: View {
  @Environment(AppStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  let postId: UUID

  @State private var draft = ""

  private var post: FeedPost? { store.feedPosts.first { $0.id == postId } }

  var body: some View {
    Group {
      NavigationStack {
        ZStack {
          MPGBackground()
          VStack(spacing: 0) {
            ScrollView {
              VStack(alignment: .leading, spacing: 14) {
                if let post {
                  FeedAuthorHeader(
                    name: post.authorName, role: post.authorRole, timestamp: post.timestamp,
                    siteName: post.siteId.flatMap { store.site($0)?.name })
                  if !post.text.isEmpty {
                    Text(post.text).font(.subheadline).foregroundStyle(Brand.ink)
                      .frame(maxWidth: .infinity, alignment: .leading)
                  }
                  if !post.photos.isEmpty {
                    FeedPhotoGrid(photos: post.photos)
                      .clipShape(
                        RoundedRectangle(cornerRadius: Brand.Radius.inner, style: .continuous))
                  }

                  Divider().overlay(Brand.hairline)

                  if post.comments.isEmpty {
                    Text("No comments yet. Be the first to reply.")
                      .font(.footnote).foregroundStyle(Brand.inkSoft)
                      .frame(maxWidth: .infinity, alignment: .leading)
                  } else {
                    ForEach(post.comments) { comment in
                      FeedCommentRow(comment: comment)
                    }
                  }
                }
              }
              .padding(16)
              .mpgCard()
              .padding(16)
            }

            composer
          }
        }
        .navigationTitle("Comments")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .confirmationAction) {
            Button("Done") { dismiss() }
          }
        }
      }
    }
    .__tenxTrackView("FeedCommentsView")
  }

  private var composer: some View {
    HStack(spacing: 10) {
      TextField("Write a comment…", text: $draft, axis: .vertical)
        .lineLimit(1...4)
        .font(.subheadline)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Brand.lightGreen.opacity(0.6), in: Capsule())
        .overlay(Capsule().stroke(Brand.hairline, lineWidth: 1))

      Button {
        store.addComment(to: postId, text: draft)
        draft = ""
      } label: {
        Image(systemName: "arrow.up.circle.fill")
          .font(.system(size: 32))
          .foregroundStyle(canSend ? Brand.olive : Brand.inkSoft.opacity(0.4))
      }
      .buttonStyle(.plain)
      .disabled(!canSend)
      .animation(.snappy(duration: 0.2), value: canSend)
    }
    .padding(12)
    .background(.ultraThinMaterial)
    // Hairline keeps the composer visually docked rather than floating.
    .overlay(alignment: .top) {
      Rectangle().fill(Brand.hairline).frame(height: 1)
    }
  }

  private var canSend: Bool {
    !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
}

#Preview {
  FeedCommentsPreview()
}

private struct FeedCommentsPreview: View {
  @State private var store: AppStore = {
    let s = AppStore()
    s.login(as: s.users.first!)
    return s
  }()
  var body: some View {
    FeedCommentsView(postId: store.feed.first!.id).environment(store)
  }
}
