import SwiftUI

// MARK: - Records (daily records + materials + photos)

struct TradesmanRecordsView: View {
  @Environment(AppStore.self) private var store
  @State private var tab = 0

  private var me: AppUser? { store.currentUser }

  var body: some View {
      Group {
              NavigationStack {
          ZStack {
            MPGBackground()
            ScrollView {
              VStack(spacing: 16) {
                Picker("View", selection: $tab) {
                  Text("Site Records").tag(0)
                  Text("Materials").tag(1)
                  Text("Photos").tag(2)
                }
                .pickerStyle(.segmented)
          
                if tab == 0 { recordsList } else if tab == 1 { materialsList } else { photosList }
              }
              .padding(16)
            }
          }
          .navigationTitle("My Records")
              }
      }
      .__tenxTrackView("TradesmanRecordsView")
  }

  @ViewBuilder private var recordsList: some View {
    let records = me.map { store.records(for: $0.id) } ?? []
    if records.isEmpty {
      EmptyStateView(
        symbol: "list.clipboard", title: "No records yet",
        message: "Daily site records you submit will appear here."
      ).mpgCard()
    } else {
      ForEach(records) { r in
        VStack(alignment: .leading, spacing: 10) {
          HStack {
            StatusChip(text: r.category.rawValue, color: Brand.olive)
            Spacer()
            Text(Fmt.date(r.date)).font(.caption).foregroundStyle(Brand.inkSoft)
          }
          Text(store.site(r.siteId)?.name ?? "Site")
            .font(.headline).foregroundStyle(Brand.ink)
          Text(r.description).font(.subheadline).foregroundStyle(Brand.inkSoft).lineLimit(3)
          Divider().overlay(Brand.hairline)
          HStack(spacing: 14) {
            Label("\(r.startTime)–\(r.finishTime)", systemImage: "clock")
            Label(Fmt.hours(r.totalHours), systemImage: "hourglass")
            if r.delayReason != .none {
              Label(r.delayReason.rawValue, systemImage: "exclamationmark.triangle")
                .foregroundStyle(Brand.amber)
            }
          }
          .font(.caption).foregroundStyle(Brand.inkSoft)
        }
        .mpgCard()
      }
    }
  }

  @ViewBuilder private var materialsList: some View {
    let mats = me.map { store.materials(for: $0.id) } ?? []
    if mats.isEmpty {
      EmptyStateView(
        symbol: "shippingbox", title: "No materials logged",
        message: "Materials you purchase for jobs will appear here."
      ).mpgCard()
    } else {
      ForEach(mats) { m in
        VStack(alignment: .leading, spacing: 8) {
          if !m.receiptUploaded {
            WarningBanner(
              message: "Receipt missing — this cost may be rejected or recharged.",
              symbol: "exclamationmark.triangle.fill", tint: Brand.red)
          }
          HStack {
            Text(m.supplier).font(.headline).foregroundStyle(Brand.ink)
            Spacer()
            Text(Fmt.gbp(m.total)).font(.headline).foregroundStyle(Brand.olive)
          }
          Text(m.description).font(.subheadline).foregroundStyle(Brand.inkSoft)
          HStack(spacing: 10) {
            StatusChip(text: "Chargeable: \(m.chargeable.rawValue)", color: Brand.blue)
            StatusChip(
              text: m.receiptUploaded ? "Receipt ✓" : "No receipt",
              color: m.receiptUploaded ? Brand.paidGreen : Brand.red)
          }
          Text(Fmt.date(m.date)).font(.caption).foregroundStyle(Brand.inkSoft)
        }
        .mpgCard()
      }
    }
  }

  @ViewBuilder private var photosList: some View {
    let pics = (me.map { u in store.photos.filter { $0.userId == u.id } } ?? [])
      .sorted { $0.timestamp > $1.timestamp }
    if pics.isEmpty {
      EmptyStateView(
        symbol: "camera", title: "No photos yet",
        message: "Before, during and completed photos will appear here."
      ).mpgCard()
    } else {
      LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
        ForEach(pics) { p in
          VStack(spacing: 8) {
            Image(systemName: p.symbol)
              .font(.system(size: 34))
              .foregroundStyle(Brand.olive)
              .frame(maxWidth: .infinity)
              .frame(height: 90)
              .background(Brand.lightGreen, in: RoundedRectangle(cornerRadius: 12))
            Text(p.type.rawValue).font(.caption.weight(.semibold))
              .foregroundStyle(Brand.ink).lineLimit(1)
            Text(p.description).font(.caption2).foregroundStyle(Brand.inkSoft)
              .lineLimit(2).multilineTextAlignment(.center)
          }
          .padding(10)
          .frame(maxWidth: .infinity)
          .mpgCard(padding: 8)
        }
      }
    }
  }
}

#Preview {
  TradesmanRecordsView().environment(
    {
      let s = AppStore()
      s.login(as: s.tradesmen().first!)
      return s
    }())
}
