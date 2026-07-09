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
              LazyVStack(spacing: 22) {
                ForEach(store.feed) { post in
                  FeedPostCard(post: post)
                }
              }
              .padding(.vertical, 12)
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
    VStack(alignment: .leading, spacing: 0) {
      FeedAuthorHeader(
        name: post.authorName, role: post.authorRole, timestamp: post.timestamp,
        siteName: siteName,
        canDelete: canDelete,
        onDelete: { store.deleteFeedPost(post.id) }
      )
      .padding(.horizontal, 16)
      .padding(.bottom, 12)

      if !post.photoSymbols.isEmpty {
        FeedPhotoGrid(symbols: post.photoSymbols)
          .onTapGesture(count: 2) {
            if !liked { withAnimation(.snappy) { store.toggleLike(post.id) } }
          }
      }

      // Instagram-style action bar
      HStack(spacing: 18) {
        Button {
          withAnimation(.snappy) { store.toggleLike(post.id) }
        } label: {
          Image(systemName: liked ? "heart.fill" : "heart")
            .foregroundStyle(liked ? Brand.red : Brand.ink)
            .symbolEffect(.bounce, value: liked)
        }

        Button {
          showComments = true
        } label: {
          Image(systemName: "bubble.right")
            .foregroundStyle(Brand.ink)
        }

        Spacer()
      }
      .font(.system(size: 22))
      .buttonStyle(.plain)
      .padding(.horizontal, 16)
      .padding(.top, 12)

      VStack(alignment: .leading, spacing: 6) {
        if !post.likedBy.isEmpty {
          Text("\(post.likedBy.count) \(post.likedBy.count == 1 ? "like" : "likes")")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Brand.ink)
        }

        if !post.text.isEmpty {
          Text(
            "\(Text(post.authorName).font(.subheadline.weight(.semibold)))  \(Text(post.text).font(.subheadline))"
          )
          .foregroundStyle(Brand.ink)
          .frame(maxWidth: .infinity, alignment: .leading)
        }

        if !post.comments.isEmpty {
          Button {
            showComments = true
          } label: {
            Text(
              post.comments.count == 1
                ? "View 1 comment" : "View all \(post.comments.count) comments"
            )
            .font(.subheadline)
            .foregroundStyle(Brand.inkSoft)
          }
          .buttonStyle(.plain)

          if let last = post.comments.last {
            Text(
              "\(Text(last.authorName).font(.subheadline.weight(.semibold)))  \(Text(last.text).font(.subheadline))"
            )
            .foregroundStyle(Brand.ink)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
          }
        }

        Text(post.timestamp.relativeShort.uppercased())
          .font(.caption2)
          .foregroundStyle(Brand.inkSoft)
          .padding(.top, 2)
      }
      .padding(.horizontal, 16)
      .padding(.top, 8)
    }
    .padding(.vertical, 14)
    .background(Brand.surface)
    .overlay(alignment: .top) { Divider().overlay(Brand.hairline) }
    .overlay(alignment: .bottom) { Divider().overlay(Brand.hairline) }
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

  var body: some View {
    if symbols.count == 1, let symbol = symbols.first {
      photoTile(symbol)
        .aspectRatio(1, contentMode: .fit)
    } else {
      TabView {
        ForEach(Array(symbols.enumerated()), id: \.offset) { _, symbol in
          photoTile(symbol)
        }
      }
      .tabViewStyle(.page(indexDisplayMode: .automatic))
      .aspectRatio(1, contentMode: .fit)
    }
  }

  private func photoTile(_ symbol: String) -> some View {
    ZStack {
      LinearGradient(
        colors: [Brand.lightGreen, Brand.charcoal.opacity(0.08)],
        startPoint: .topLeading, endPoint: .bottomTrailing)
      Image(systemName: symbol)
        .font(.system(size: 46))
        .foregroundStyle(Brand.olive.opacity(0.7))
    }
    .frame(maxWidth: .infinity)
    .clipped()
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
