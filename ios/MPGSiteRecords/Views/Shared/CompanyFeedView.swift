import SwiftUI

/// Company-wide social feed / group chat. Every role shares the same wall:
/// text posts, photos (SF Symbol stand-ins), likes and comments.
struct CompanyFeedView: View {
  @Environment(AppStore.self) private var store
  @State private var showComposer = false

  var body: some View {
    NavigationStack {
      ZStack {
        MPGBackground()
        Group {
          if store.feed.isEmpty {
            ScrollView {
              EmptyStateView(
                symbol: "bubble.left.and.bubble.right",
                title: "No posts yet",
                message: "Share an update, a photo from site, or a message for the whole team.",
                actionTitle: "Create the first post",
                action: { showComposer = true }
              )
              .mpgCard()
              .padding(16)
            }
          } else {
            ScrollView {
              LazyVStack(spacing: 14) {
                ForEach(store.feed) { post in
                  FeedPostCard(post: post)
                }
              }
              .padding(16)
            }
          }
        }
      }
      .navigationTitle("Team")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            showComposer = true
          } label: {
            Image(systemName: "square.and.pencil")
          }
        }
      }
      .sheet(isPresented: $showComposer) {
        FeedComposerView()
      }
    }
    .__tenxTrackView("CompanyFeedView")
  }
}

// MARK: - Post card

struct FeedPostCard: View {
  @Environment(AppStore.self) private var store
  let post: FeedPost
  @State private var showComments = false

  private var liked: Bool { store.isLiked(post) }
  private var siteName: String? { post.siteId.flatMap { store.site($0)?.name } }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      FeedAuthorHeader(
        name: post.authorName, role: post.authorRole, timestamp: post.timestamp,
        siteName: siteName,
        canDelete: canDelete,
        onDelete: { store.deleteFeedPost(post.id) })

      if !post.text.isEmpty {
        Text(post.text)
          .font(.subheadline)
          .foregroundStyle(Brand.ink)
          .frame(maxWidth: .infinity, alignment: .leading)
      }

      if !post.photoSymbols.isEmpty {
        FeedPhotoGrid(symbols: post.photoSymbols)
      }

      Divider().overlay(Brand.hairline)

      HStack(spacing: 22) {
        Button {
          withAnimation(.snappy) { store.toggleLike(post.id) }
        } label: {
          Label(
            post.likedBy.isEmpty ? "Like" : "\(post.likedBy.count)",
            systemImage: liked ? "hand.thumbsup.fill" : "hand.thumbsup")
        }
        .foregroundStyle(liked ? Brand.olive : Brand.inkSoft)

        Button {
          showComments = true
        } label: {
          Label(
            post.comments.isEmpty ? "Comment" : "\(post.comments.count)",
            systemImage: "bubble.left")
        }
        .foregroundStyle(Brand.inkSoft)

        Spacer()
      }
      .font(.footnote.weight(.semibold))
      .buttonStyle(.plain)

      if let last = post.comments.last {
        Button {
          showComments = true
        } label: {
          FeedCommentRow(comment: last, compact: true)
        }
        .buttonStyle(.plain)
        if post.comments.count > 1 {
          Button("View all \(post.comments.count) comments") { showComments = true }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Brand.olive)
        }
      }
    }
    .mpgCard()
    .sheet(isPresented: $showComments) {
      FeedCommentsView(postId: post.id)
    }
  }

  private var canDelete: Bool {
    guard let me = store.currentUser else { return false }
    return me.id == post.authorId || me.role == .admin
  }
}

// MARK: - Author header

struct FeedAuthorHeader: View {
  let name: String
  let role: UserRole
  let timestamp: Date
  var siteName: String? = nil
  var canDelete: Bool = false
  var onDelete: () -> Void = {}

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      ZStack {
        Circle().fill(Brand.lightGreen)
        Image(systemName: role.icon)
          .font(.subheadline)
          .foregroundStyle(Brand.oliveDark)
      }
      .frame(width: 40, height: 40)

      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 6) {
          Text(name).font(.subheadline.weight(.semibold)).foregroundStyle(Brand.ink)
          StatusChip(text: role.rawValue, color: Brand.olive)
        }
        HStack(spacing: 6) {
          Text(timestamp.relativeShort)
          if let siteName {
            Text("•")
            Label(siteName, systemImage: "mappin.and.ellipse").labelStyle(.titleAndIcon)
          }
        }
        .font(.caption)
        .foregroundStyle(Brand.inkSoft)
      }
      Spacer(minLength: 8)

      if canDelete {
        Menu {
          Button(role: .destructive, action: onDelete) {
            Label("Delete post", systemImage: "trash")
          }
        } label: {
          Image(systemName: "ellipsis")
            .font(.subheadline)
            .foregroundStyle(Brand.inkSoft)
            .frame(width: 28, height: 28)
        }
      }
    }
  }
}

// MARK: - Photo grid

struct FeedPhotoGrid: View {
  let symbols: [String]

  private var columns: [GridItem] {
    Array(repeating: GridItem(.flexible(), spacing: 8), count: symbols.count == 1 ? 1 : 2)
  }

  var body: some View {
    LazyVGrid(columns: columns, spacing: 8) {
      ForEach(Array(symbols.enumerated()), id: \.offset) { _, symbol in
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(Brand.charcoal.opacity(0.06))
          .aspectRatio(symbols.count == 1 ? 16.0 / 10.0 : 1, contentMode: .fit)
          .overlay(
            Image(systemName: symbol)
              .font(.system(size: 34))
              .foregroundStyle(Brand.olive.opacity(0.6))
          )
          .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
              .stroke(Brand.hairline, lineWidth: 1)
          )
      }
    }
  }
}

// MARK: - Comment row

struct FeedCommentRow: View {
  let comment: FeedComment
  var compact: Bool = false

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      HStack(spacing: 6) {
        Text(comment.authorName)
          .font(.caption.weight(.semibold))
          .foregroundStyle(Brand.ink)
        Text(comment.timestamp.relativeShort)
          .font(.caption2)
          .foregroundStyle(Brand.inkSoft)
      }
      Text(comment.text)
        .font(.footnote)
        .foregroundStyle(Brand.ink)
        .lineLimit(compact ? 2 : nil)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(10)
    .background(
      Brand.lightGreen.opacity(0.5), in: RoundedRectangle(cornerRadius: 10, style: .continuous)
    )
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

// MARK: - Relative time helper

extension Date {
  /// Short relative time like "5m", "3h", "2d" for feed timestamps.
  var relativeShort: String {
    let secs = Int(Date().timeIntervalSince(self))
    if secs < 60 { return "just now" }
    let mins = secs / 60
    if mins < 60 { return "\(mins)m ago" }
    let hrs = mins / 60
    if hrs < 24 { return "\(hrs)h ago" }
    let days = hrs / 24
    if days < 7 { return "\(days)d ago" }
    return formatted(.dateTime.day().month())
  }
}

#Preview {
  CompanyFeedView().environment(
    {
      let s = AppStore()
      s.login(as: s.users.first { $0.role == .admin }!)
      return s
    }())
}
