import SwiftUI

/// "Ask MPG" — a conversational way for the office to interrogate live company
/// data in plain English. Questions and answers are stacked like a chat; every
/// answer is computed locally by `AskMPG`, so figures are authoritative and work
/// offline.
struct AskMPGView: View {
  @Environment(AppStore.self) private var store
  @State private var query = ""
  @State private var turns: [AskTurn] = []
  @FocusState private var inputFocused: Bool

  struct AskTurn: Identifiable {
    let id = UUID()
    let question: String
    let answer: AskAnswer
  }

  var body: some View {
    NavigationStack {
      ZStack {
        MPGBackground()
        VStack(spacing: 0) {
          ScrollViewReader { proxy in
            ScrollView {
              VStack(spacing: 16) {
                if turns.isEmpty {
                  intro
                } else {
                  ForEach(turns) { turn in
                    conversation(turn).id(turn.id)
                  }
                }
                suggestionChips
                Color.clear.frame(height: 8).id("bottom")
              }
              .padding(16)
            }
            .onChange(of: turns.count) { _, _ in
              withAnimation(.easeOut) { proxy.scrollTo("bottom", anchor: .bottom) }
            }
          }
          inputBar
        }
      }
      .navigationTitle("Ask MPG")
      .navigationBarTitleDisplayMode(.inline)
    }
    .__tenxTrackView("AskMPGView")
  }

  // MARK: - Intro

  private var intro: some View {
    VStack(spacing: 14) {
      ZStack {
        Circle().fill(Brand.olive.opacity(0.15)).frame(width: 66, height: 66)
        Image(systemName: "sparkles").font(.title).foregroundStyle(Brand.olive)
      }
      Text("Ask MPG anything")
        .font(.title3.bold()).foregroundStyle(Brand.ink)
      Text(
        "Ask about spend, invoices, receipts, hours, sites or a person by name — in plain English. Answers come straight from your live company data."
      )
      .font(.subheadline).foregroundStyle(Brand.inkSoft)
      .multilineTextAlignment(.center)
      .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 22)
    .padding(.horizontal, 18)
    .mpgCard()
  }

  // MARK: - Conversation

  private func conversation(_ turn: AskTurn) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Spacer(minLength: 40)
        Text(turn.question)
          .font(.subheadline.weight(.medium))
          .foregroundStyle(.white)
          .padding(.vertical, 10).padding(.horizontal, 14)
          .background(Brand.charcoal, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
      }
      answerCard(turn.answer)
    }
  }

  private func answerCard(_ answer: AskAnswer) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .top, spacing: 12) {
        ZStack {
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Brand.olive.opacity(0.15)).frame(width: 44, height: 44)
          Image(systemName: answer.symbol).font(.headline).foregroundStyle(Brand.olive)
        }
        VStack(alignment: .leading, spacing: 3) {
          Text(answer.headline)
            .font(.title3.bold()).foregroundStyle(Brand.ink)
            .fixedSize(horizontal: false, vertical: true)
          Text(answer.summary)
            .font(.footnote).foregroundStyle(Brand.inkSoft)
            .fixedSize(horizontal: false, vertical: true)
        }
      }

      if !answer.rows.isEmpty {
        VStack(spacing: 0) {
          ForEach(Array(answer.rows.enumerated()), id: \.element.id) { index, row in
            if index > 0 { Divider().overlay(Brand.lightGreen) }
            answerRow(row)
          }
        }
        .background(Brand.lightGreen.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .mpgCard()
  }

  private func answerRow(_ row: AskAnswerRow) -> some View {
    HStack(spacing: 12) {
      Image(systemName: row.symbol)
        .font(.footnote).foregroundStyle(Brand.olive)
        .frame(width: 26)
      VStack(alignment: .leading, spacing: 1) {
        Text(row.title).font(.subheadline.weight(.semibold)).foregroundStyle(Brand.ink)
        Text(row.detail).font(.caption2).foregroundStyle(Brand.inkSoft).lineLimit(1)
      }
      Spacer(minLength: 8)
      Text(row.value).font(.subheadline.weight(.bold)).foregroundStyle(Brand.olive)
    }
    .padding(.vertical, 10).padding(.horizontal, 12)
  }

  // MARK: - Suggestions

  private var suggestionChips: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(turns.isEmpty ? "Try asking" : "More to ask")
        .font(.caption.weight(.semibold)).foregroundStyle(Brand.inkSoft)
      FlowLayout(spacing: 8) {
        ForEach(AskMPG.suggestions, id: \.self) { s in
          Button {
            ask(s)
          } label: {
            Text(s)
              .font(.caption.weight(.medium))
              .foregroundStyle(Brand.ink)
              .padding(.vertical, 8).padding(.horizontal, 12)
              .background(Brand.lightGreen.opacity(0.7), in: Capsule())
          }
          .buttonStyle(.plain)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  // MARK: - Input

  private var inputBar: some View {
    HStack(spacing: 10) {
      TextField("Ask about spend, invoices, a site…", text: $query, axis: .vertical)
        .lineLimit(1...3)
        .focused($inputFocused)
        .submitLabel(.send)
        .onSubmit { ask(query) }
        .padding(.vertical, 10).padding(.horizontal, 14)
        .background(Brand.lightGreen.opacity(0.5), in: Capsule())
      Button {
        ask(query)
      } label: {
        Image(systemName: "arrow.up")
          .font(.headline.weight(.bold)).foregroundStyle(.white)
          .frame(width: 42, height: 42)
          .background(
            query.trimmingCharacters(in: .whitespaces).isEmpty ? Brand.inkSoft : Brand.olive,
            in: Circle())
      }
      .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty)
    }
    .padding(12)
    .background(.ultraThinMaterial)
  }

  private func ask(_ text: String) {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    let answer = AskMPG.answer(to: trimmed, store: store)
    turns.append(AskTurn(question: trimmed, answer: answer))
    query = ""
    inputFocused = false
  }
}

/// A simple wrapping flow layout for the suggestion chips.
struct FlowLayout: Layout {
  var spacing: CGFloat = 8

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
    let maxWidth = proposal.width ?? .infinity
    var rows: [[LayoutSubviews.Element]] = [[]]
    var x: CGFloat = 0
    var totalHeight: CGFloat = 0
    var rowHeight: CGFloat = 0
    for view in subviews {
      let size = view.sizeThatFits(.unspecified)
      if x + size.width > maxWidth, !rows[rows.count - 1].isEmpty {
        rows.append([])
        totalHeight += rowHeight + spacing
        x = 0
        rowHeight = 0
      }
      rows[rows.count - 1].append(view)
      x += size.width + spacing
      rowHeight = max(rowHeight, size.height)
    }
    totalHeight += rowHeight
    return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: totalHeight)
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void
  ) {
    var x = bounds.minX
    var y = bounds.minY
    var rowHeight: CGFloat = 0
    for view in subviews {
      let size = view.sizeThatFits(.unspecified)
      if x + size.width > bounds.maxX, x > bounds.minX {
        x = bounds.minX
        y += rowHeight + spacing
        rowHeight = 0
      }
      view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
      x += size.width + spacing
      rowHeight = max(rowHeight, size.height)
    }
  }
}

#Preview {
  AskMPGView().environment(
    {
      let s = AppStore()
      s.login(as: s.users.first { $0.role == .admin }!)
      return s
    }())
}
