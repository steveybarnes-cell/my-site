import SwiftUI

/// Company-wide social feed / group chat. Every role shares the same wall:
/// text posts, photos (SF Symbol stand-ins), acknowledgements and comments.
///
/// The whole feed is constrained to a single readable phone-width column that
/// stays centred on any device, so it never stretches too wide on iPad or in
/// landscape. Cards are framed edge-to-edge (Instagram-style) but wear MPG's
/// own identity: an olive accent rail, a site "location" ribbon and a
/// square-tick acknowledgement action instead of a heart.
struct CompanyFeedView: View {
  @Environment(AppStore.self) private var store
  @State private var showComposer = false
  @State private var showCall = false
  @State private var selectedSiteId: UUID?
  @State private var needsActionOnly = false
  /// Ticks every few seconds to keep relative timestamps fresh (live feel).
  @State private var liveTick = Date()

  /// Maximum content width. Keeps the feed a comfortable single column even on
  /// wide iPad / landscape layouts rather than stretching full-bleed.
  private let columnWidth: CGFloat = 500

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
        content
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
      }
      .onReceive(liveTimer) { _ in liveTick = Date() }
    }
    .__tenxTrackView("CompanyFeedView")
  }

  @ViewBuilder private var content: some View {
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
        .frame(maxWidth: columnWidth)
        .frame(maxWidth: .infinity)
        .padding(16)
      }
    } else {
      ScrollView {
        LazyVStack(spacing: 14) {
          FeedPulseHeader(postCount: visiblePosts.count, needsActionOnly: needsActionOnly)
          SiteFilterBar(selectedSiteId: $selectedSiteId)

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
        .frame(maxWidth: columnWidth)
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
        .padding(.bottom, 16)
      }
      .refreshable {
        if store.isLiveBackend { await store.loadLiveData() }
        liveTick = Date()
      }
    }
  }
}

// MARK: - Feed pulse header

/// Sits above the filter bar and gives the wall a sense of live momentum:
/// what you are looking at, how much of it there is, and whether it is moving.
struct FeedPulseHeader: View {
  let postCount: Int
  let needsActionOnly: Bool

  private var title: String {
    needsActionOnly ? "Your action queue" : "Work happening now"
  }

  private var subtitle: String {
    needsActionOnly
      ? "Updates waiting for your acknowledgement"
      : "\(postCount) update\(postCount == 1 ? "" : "s") from sites and the team"
  }

  var body: some View {
    HStack(alignment: .center, spacing: 14) {
      ZStack {
        Circle().fill(Brand.charcoal)
        Image(systemName: needsActionOnly ? "checkmark.seal.fill" : "bolt.fill")
          .font(.headline)
          .foregroundStyle(needsActionOnly ? Brand.lime : .white)
      }
      .frame(width: 48, height: 48)

      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.headline.weight(.bold))
          .foregroundStyle(Brand.ink)
        Text(subtitle)
          .font(.caption)
          .foregroundStyle(Brand.inkSoft)
          .lineLimit(2)
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer(minLength: 4)
      LivePill()
    }
    .padding(14)
    .background(
      Brand.surface.opacity(0.92),
      in: RoundedRectangle(cornerRadius: Brand.Radius.feature, style: .continuous)
    )
    .overlay {
      RoundedRectangle(cornerRadius: Brand.Radius.feature, style: .continuous)
        .stroke(Brand.hairline.opacity(0.85), lineWidth: 1)
    }
    .shadow(color: Brand.cardShadow, radius: 12, x: 0, y: 5)
    .padding(.horizontal, 12)
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
    .background(Capsule().fill(Brand.lime.opacity(0.34)))
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
        .lineLimit(1)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
          Capsule().fill(selected ? Brand.olive : Brand.surface)
            .overlay(Capsule().stroke(Brand.hairline, lineWidth: selected ? 0 : 1))
        )
        .shadow(color: selected ? Brand.olive.opacity(0.25) : .clear, radius: 6, x: 0, y: 3)
    }
    .buttonStyle(.plain)
    .animation(.snappy(duration: 0.2), value: selected)
  }
}

// MARK: - Post card

struct FeedPostCard: View {
  @Environment(AppStore.self) private var store
  let post: FeedPost
  @State private var showComments = false
  @State private var burst = false

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
      .padding(.horizontal, 14)
      .padding(.top, 14)
      .padding(.bottom, 12)

      if !post.photoSymbols.isEmpty {
        ZStack {
          FeedPhotoGrid(symbols: post.photoSymbols)
          // Double-tap acknowledge burst, Instagram-style.
          Image(systemName: "checkmark.seal.fill")
            .font(.system(size: 84, weight: .bold))
            .foregroundStyle(.white)
            .shadow(radius: 8)
            .scaleEffect(burst ? 1 : 0.4)
            .opacity(burst ? 0.9 : 0)
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
          if !liked { store.toggleLike(post.id) }
          withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) { burst = true }
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.25)) { burst = false }
          }
        }
      }

      // Work-team action bar: acknowledge (tick) + reply.
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
          // Secondary action: outlined rather than filled, so the
          // acknowledge button stays the obvious primary.
          .background(Capsule().fill(Brand.surface))
          .overlay(Capsule().stroke(Brand.hairline, lineWidth: 1))
        }

        Spacer()
      }
      .buttonStyle(.plain)
      .padding(.horizontal, 14)
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
          .font(.caption2.weight(.medium))
          .tracking(0.5)
          .foregroundStyle(Brand.inkSoft.opacity(0.8))
          .padding(.top, 2)
      }
      .padding(.horizontal, 14)
      .padding(.top, 8)
      .padding(.bottom, 16)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Brand.surface)
    // MPG identity: an olive accent rail down the leading edge of every card.
    .overlay(alignment: .leading) {
      Rectangle()
        .fill(liked ? Brand.olive : Brand.hairline)
        .frame(width: 4)
    }
    .clipShape(RoundedRectangle(cornerRadius: Brand.Radius.card, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: Brand.Radius.card, style: .continuous)
        .stroke(Brand.hairline.opacity(0.8), lineWidth: 1)
    )
    .shadow(color: Brand.cardShadow, radius: 10, x: 0, y: 4)
    .padding(.horizontal, 12)
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

      VStack(alignment: .leading, spacing: 3) {
        HStack(spacing: 6) {
          Text(name)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Brand.ink)
            .lineLimit(1)
            .truncationMode(.tail)
          StatusChip(text: role.rawValue, color: Brand.olive)
            .layoutPriority(1)
        }
        if let siteName {
          Label(siteName, systemImage: "mappin.and.ellipse")
            .labelStyle(.titleAndIcon)
            .font(.caption.weight(.medium))
            .foregroundStyle(Brand.oliveDark)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(Brand.lightGreen))
        }
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
