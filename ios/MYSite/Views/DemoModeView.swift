import SwiftUI

/// Demo Mode entry: lets anyone explore the app as any role using the built-in
/// sample data, without a Supabase account or live session. Available in all
/// builds. Clearly labelled so it is never confused with a real login.
struct DemoModeView: View {
  @Environment(AppStore.self) private var store
  @Environment(AuthManager.self) private var auth
  @Environment(\.dismiss) private var dismiss

  @State private var selectedRole: UserRole = .tradesman

  private var roleUsers: [AppUser] {
    store.users.filter { $0.role == selectedRole && $0.active }
  }

  var body: some View {
    NavigationStack {
      ZStack {
        MPGBackground()
        ScrollView {
          VStack(spacing: 18) {
            banner
            statsRow
            photoStrip
            aiReceiptCard
            insideCard

            VStack(alignment: .leading, spacing: 14) {
              SectionHeader(
                title: "Choose a role",
                subtitle: "Explore the app from any team member's view")
              Picker("Role", selection: $selectedRole) {
                ForEach(UserRole.allCases) { Text($0.rawValue).tag($0) }
              }
              .pickerStyle(.segmented)

              VStack(spacing: 8) {
                ForEach(roleUsers) { user in
                  userRow(user)
                }
                if roleUsers.isEmpty {
                  Text("No sample \(selectedRole.rawValue.lowercased()) available.")
                    .font(.caption)
                    .foregroundStyle(Brand.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
              }
            }
            .mpgCard()

            Text("Demo data is local to this device and resets when you sign out.")
              .font(.caption2)
              .foregroundStyle(Brand.inkSoft)
              .multilineTextAlignment(.center)
          }
          .padding(16)
          .frame(maxWidth: .infinity)
        }
      }
      .navigationTitle("Demo Mode")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Close") { dismiss() }
        }
      }
    }
    .__tenxTrackView("DemoModeView")
  }

  private var aiReceiptCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 10) {
        Image(systemName: "doc.text.viewfinder")
          .font(.title3)
          .foregroundStyle(.white)
          .frame(width: 38, height: 38)
          .background(Brand.olive, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        VStack(alignment: .leading, spacing: 2) {
          Text("AI receipt scanning")
            .font(.subheadline.weight(.bold))
            .foregroundStyle(Brand.ink)
          Text("Photograph a receipt and it's read automatically.")
            .font(.caption)
            .foregroundStyle(Brand.inkSoft)
        }
        Spacer(minLength: 0)
      }
      HStack(spacing: 8) {
        Image(systemName: "sparkles").font(.caption2).foregroundStyle(Brand.olive)
        Text("Photograph").font(.caption2.weight(.medium)).foregroundStyle(Brand.ink)
        Image(systemName: "arrow.right").font(.caption2).foregroundStyle(Brand.inkSoft)
        Text("AI reads it").font(.caption2.weight(.medium)).foregroundStyle(Brand.ink)
        Image(systemName: "arrow.right").font(.caption2).foregroundStyle(Brand.inkSoft)
        Text("Hubdoc").font(.caption2.weight(.bold)).foregroundStyle(Brand.olive)
      }
      Text(
        "Approved receipts go straight through to Hubdoc — no lost paperwork or manual entry."
      )
      .font(.caption2)
      .foregroundStyle(Brand.inkSoft)
      .fixedSize(horizontal: false, vertical: true)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Brand.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(Brand.olive.opacity(0.3), lineWidth: 1)
    )
  }

  private var statsRow: some View {
    HStack(spacing: 10) {
      demoStat(value: "\(store.sites.count)", label: "Live sites", icon: "building.2.fill")
      demoStat(
        value: "\(store.users.filter { $0.active }.count)", label: "Team", icon: "person.2.fill")
      demoStat(
        value: "\(store.feedPosts.count)", label: "Feed posts",
        icon: "bubble.left.and.bubble.right.fill")
      demoStat(value: "\(store.photos.count)", label: "Site photos", icon: "photo.fill")
    }
  }

  private func demoStat(value: String, label: String, icon: String) -> some View {
    VStack(spacing: 5) {
      Image(systemName: icon)
        .font(.callout)
        .foregroundStyle(Brand.olive)
      Text(value)
        .font(.title3.weight(.bold))
        .foregroundStyle(Brand.ink)
      Text(label)
        .font(.caption2)
        .foregroundStyle(Brand.inkSoft)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 14)
    .background(Brand.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Brand.hairline, lineWidth: 1))
  }

  private var photoStrip: some View {
    VStack(alignment: .leading, spacing: 10) {
      SectionHeader(
        title: "Real site photos",
        subtitle: "The kind of evidence the team logs every day")
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 10) {
          ForEach(SiteScene.allCases, id: \.self) { scene in
            SiteSceneImage(scene: scene)
              .frame(width: 150, height: 104)
              .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
          }
        }
      }
    }
    .mpgCard()
  }

  private var insideCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(
        title: "What's inside the demo",
        subtitle: "Fully working with sample company data")
      insideRow(
        "bubble.left.and.bubble.right.fill", "Team feed",
        "Post updates, photos, comments and acknowledgements")
      insideRow(
        "list.clipboard.fill", "Daily site records", "Log allocated work, hours and materials")
      insideRow(
        "sterlingsign.circle.fill", "Weekly invoices",
        "Standard invoice + timesheet submission and approvals")
      insideRow(
        "folder.fill", "Site files hub", "Drawings, certificates, receipts and handover packs")
      insideRow(
        "chart.bar.fill", "Admin dashboard", "Company-wide stats, work by trade and sign-off")
    }
    .mpgCard()
  }

  private func insideRow(_ icon: String, _ title: String, _ subtitle: String) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: icon)
        .font(.callout)
        .foregroundStyle(Brand.olive)
        .frame(width: 30, height: 30)
        .background(Brand.lightGreen, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
      VStack(alignment: .leading, spacing: 2) {
        Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Brand.ink)
        Text(subtitle).font(.caption).foregroundStyle(Brand.inkSoft)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 0)
    }
  }

  private var banner: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: "play.circle.fill")
        .font(.title2)
        .foregroundStyle(Brand.olive)
      VStack(alignment: .leading, spacing: 3) {
        Text("You're about to explore a demo")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(Brand.ink)
        Text("Sample sites, records and invoices. Nothing is sent to the server.")
          .font(.caption)
          .foregroundStyle(Brand.inkSoft)
      }
      Spacer(minLength: 0)
    }
    .padding(14)
    .background(Brand.lightGreen, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  private func userRow(_ user: AppUser) -> some View {
    Button {
      auth.enterDemo(as: user)
      dismiss()
    } label: {
      HStack(spacing: 12) {
        Image(systemName: user.role.icon)
          .foregroundStyle(Brand.olive)
          .frame(width: 34, height: 34)
          .background(Brand.lightGreen, in: Circle())
        VStack(alignment: .leading, spacing: 1) {
          Text(user.name).font(.subheadline.weight(.semibold)).foregroundStyle(Brand.ink)
          Text(user.role.rawValue).font(.caption).foregroundStyle(Brand.inkSoft)
        }
        Spacer()
        Image(systemName: "chevron.right").font(.caption).foregroundStyle(Brand.inkSoft)
      }
      .padding(12)
      .background(Brand.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
      .overlay(RoundedRectangle(cornerRadius: 12).stroke(Brand.hairline, lineWidth: 1))
    }
    .buttonStyle(.plain)
  }
}

private struct DemoModePreview: View {
  @State private var store = AppStore()
  var body: some View {
    DemoModeView()
      .environment(store)
      .environment(AuthManager(store: store))
  }
}

#Preview { DemoModePreview() }
