import SwiftUI

/// Company-wide social feed / group chat. Every role shares the same wall:
/// text posts, photos (SF Symbol stand-ins), likes and comments.
struct CompanyFeedView: View {
  @Environment(AppStore.self) private var store
  @Environment(CallService.self) private var call
  @State private var showComposer = false
  @State private var showCall = false
  @State private var selectedSiteId: UUID?
  @State private var needsActionOnly = false
  /// Ticks every few seconds to keep relative timestamps fresh (live feel).
  @State private var liveTick = Date()

  private let liveTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

  private var visiblePosts: [FeedPost] {
    needsActionOnly
      ? store.needsActionFeed(siteId: selectedSiteId)
      : store.feed(siteId: selectedSiteId)
  }

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
                SiteFilterBar(selectedSiteId: $selectedSiteId)
                  .padding(.top, 0)

                if visiblePosts.isEmpty {
                  EmptyStateView(
                    symbol: needsActionOnly
                      ? "checkmark.circle" : "line.3.horizontal.decrease.circle",
                    title: needsActionOnly ? "You're all caught up" : "Nothing for this site yet",
                    message: needsActionOnly
                      ? "No posts are waiting on you. Turn off the filter to see the whole feed."
                      : "No posts have been tagged to this site. Switch to All to see everything."
                  )
                  .mpgCard()
                  .padding(.horizontal, 14)
                } else {
                  ForEach(visiblePosts) { post in
                    FeedPostCard(post: post)
                      .id("\(post.id)-\(liveTick.timeIntervalSince1970)")
                  }
                }
              }
              .padding(.top, 2)
              .padding(.bottom, 12)
            }
            .refreshable {
              if store.isLiveBackend { await store.loadLiveData() }
              liveTick = Date()
            }
          }
        }
      }
      .navigationTitle("Team")
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button {
            withAnimation(.snappy) { needsActionOnly.toggle() }
          } label: {
            Image(
              systemName: needsActionOnly
                ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
          }
          .tint(needsActionOnly ? Brand.olive : nil)
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            showCall = true
          } label: {
            Image(systemName: "phone.fill")
          }
        }
        ToolbarItem(placement: .topBarTrailing) {
          Menu {
            Button {
              showComposer = true
            } label: {
              Label("New post", systemImage: "square.and.pencil")
            }
            Button {
              showCall = true
            } label: {
              Label("Start a call", systemImage: "phone.fill")
            }
          } label: {
            Image(systemName: "plus")
          }
        }
      }
      .sheet(isPresented: $showComposer) {
        FeedComposerView()
      }
      .sheet(isPresented: $showCall) {
        StartCallView()
          .environment(call)
      }
      .onReceive(liveTimer) { _ in liveTick = Date() }
    }
    .__tenxTrackView("CompanyFeedView")
  }
}

// MARK: - Live indicator

struct LivePill: View {
  @State private var pulse = false

  var body: some View {
    HStack(spacing: 5) {
      Circle()
        .fill(Brand.paidGreen)
        .frame(width: 7, height: 7)
        .opacity(pulse ? 0.35 : 1)
      Text("LIVE")
        .font(.caption2.weight(.bold))
        .foregroundStyle(Brand.oliveDark)
    }
    .padding(.horizontal, 9)
    .padding(.vertical, 4)
    .background(Capsule().fill(Brand.lightGreen))
    .onAppear {
      withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
        pulse = true
      }
    }
  }
}

// MARK: - Site filter bar

struct SiteFilterBar: View {
  @Environment(AppStore.self) private var store
  @Binding var selectedSiteId: UUID?

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        FilterChip(title: "All sites", selected: selectedSiteId == nil) {
          selectedSiteId = nil
        }
        ForEach(store.sitesWithFeedActivity) { site in
          FilterChip(title: site.name, selected: selectedSiteId == site.id) {
            selectedSiteId = site.id
          }
        }
      }
      .padding(.horizontal, 14)
    }
  }
}

struct FilterChip: View {
  let title: String
  let selected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(title)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(selected ? .white : Brand.ink)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
          Capsule().fill(selected ? Brand.olive : Brand.surface)
            .overlay(Capsule().stroke(Brand.hairline, lineWidth: selected ? 0 : 1))
        )
    }
    .buttonStyle(.plain)
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
          .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
          .padding(.horizontal, 16)
          .onTapGesture(count: 2) {
            if !liked { withAnimation(.snappy) { store.toggleLike(post.id) } }
          }
      }

      // Work-team action bar: acknowledge (tick) + reply, styled as pill buttons
      HStack(spacing: 10) {
        Button {
          withAnimation(.snappy) { store.toggleLike(post.id) }
        } label: {
          HStack(spacing: 6) {
            Image(systemName: liked ? "checkmark.seal.fill" : "checkmark.seal")
              .symbolEffect(.bounce, value: liked)
            Text(liked ? "Acknowledged" : "Acknowledge")
          }
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(liked ? .white : Brand.olive)
          .padding(.horizontal, 14)
          .padding(.vertical, 8)
          .background(Capsule().fill(liked ? Brand.olive : Brand.lightGreen))
        }

        Button {
          showComments = true
        } label: {
          HStack(spacing: 6) {
            Image(systemName: "text.bubble")
            Text("Reply")
          }
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(Brand.ink)
          .padding(.horizontal, 14)
          .padding(.vertical, 8)
          .background(Capsule().fill(Brand.hairline.opacity(0.4)))
        }

        Spacer()
      }
      .buttonStyle(.plain)
      .padding(.horizontal, 16)
      .padding(.top, 12)

      VStack(alignment: .leading, spacing: 6) {
        if !post.likedBy.isEmpty {
          Label(
            "\(post.likedBy.count) \(post.likedBy.count == 1 ? "person" : "people") acknowledged",
            systemImage: "checkmark.seal.fill"
          )
          .font(.caption.weight(.semibold))
          .foregroundStyle(Brand.olive)
          .padding(.top, 4)
        }

        if !post.text.isEmpty {
          Text(
            "\(Text(post.authorName).font(.subheadline.weight(.semibold)))  \(Text(post.text).font(.subheadline))"
          )
          .foregroundStyle(Brand.ink)
          .multilineTextAlignment(.leading)
          .fixedSize(horizontal: false, vertical: true)
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
            .multilineTextAlignment(.leading)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
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
    .padding(.vertical, 16)
    .background(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .fill(Brand.surface)
        .overlay(
          RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(Brand.hairline, lineWidth: 1)
        )
    )
    .padding(.horizontal, 14)
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
          Text(name)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Brand.ink)
            .lineLimit(1)
            .truncationMode(.tail)
          StatusChip(text: role.rawValue, color: Brand.olive)
            .layoutPriority(1)
        }
        HStack(spacing: 6) {
          Text(timestamp.relativeShort)
          if let siteName {
            Text("•")
            Label(siteName, systemImage: "mappin.and.ellipse")
              .labelStyle(.titleAndIcon)
              .lineLimit(1)
              .truncationMode(.tail)
          }
        }
        .font(.caption)
        .foregroundStyle(Brand.inkSoft)
        .lineLimit(1)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
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

  /// Every feed photo renders at this fixed height so all posts are uniform and
  /// nothing overflows the card, regardless of the source image dimensions.
  private let photoHeight: CGFloat = 300

  private var scenes: [SiteScene] { symbols.map { SiteScene(key: $0) } }

  var body: some View {
    if scenes.count == 1, let scene = scenes.first {
      SitePhotoImage(scene: scene)
        .frame(maxWidth: .infinity)
        .frame(height: photoHeight)
        .clipped()
    } else {
      TabView {
        ForEach(Array(scenes.enumerated()), id: \.offset) { _, scene in
          SitePhotoImage(scene: scene)
            .frame(maxWidth: .infinity)
            .clipped()
        }
      }
      .tabViewStyle(.page(indexDisplayMode: .automatic))
      .frame(height: photoHeight)
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
