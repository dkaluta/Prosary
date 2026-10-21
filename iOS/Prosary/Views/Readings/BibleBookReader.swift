import SwiftUI

/// Pages contain complete source units in their original order. A unit taller than a leaf
/// remains alone on a vertically scrollable page, preserving every word and source note.
enum BibleBookPagination {
  static func pages(heights: [CGFloat], availableHeight: CGFloat, spacing: CGFloat = 16) -> [Range<Int>] {
    guard !heights.isEmpty else { return [] }
    let capacity = max(1, availableHeight)
    var pages: [Range<Int>] = []
    var start = 0
    var used: CGFloat = 0
    for index in heights.indices {
      let height = max(1, heights[index].isFinite ? heights[index] : capacity)
      let addition = height + (index == start ? 0 : spacing)
      if index > start, used + addition > capacity {
        pages.append(start..<index)
        start = index
        used = height
      } else { used += addition }
    }
    pages.append(start..<heights.count)
    return pages
  }

  static func spread(containing item: Int, pages: [Range<Int>]) -> Int {
    (pages.firstIndex { $0.contains(item) } ?? 0) / 2
  }
}

/// One source renderer owns both continuous reading and the wide, facing-page book.
struct BibleChapterReader: View {
  let edition: BibleEdition
  let book: BibleBook
  let display: BibleDisplayChapter
  let script: String
  let jumpGeneration: Int
  @Binding var anchorID: String?
  @Environment(\.layoutDirection) private var interfaceDirection
  @ObservedObject private var typography = PrayerTypographyMonitor.shared
  @State private var heights: [String: CGFloat] = [:]
  @State private var leafSizes: [Int: CGSize] = [:]

  private var canonicalReference: String? {
    book.chapters.first { $0.number == display.chapter.chapter }?.canonicalReference
  }
  private var direction: LayoutDirection { edition.readingEdition.isBibleRightToLeft ? .rightToLeft : .leftToRight }
  private var ids: [String] {
    var result: [String] = []
    if book.chapters.first(where: { $0.number == display.chapter.chapter })?.isComplete == false { result.append("chapter.partial") }
    if book.introduction(for: display.chapter.chapter) != nil { result.append("chapter.introduction") }
    result.append("chapter.heading")
    result += display.blocks.map(\.id)
    result.append("chapter.credits")
    return result
  }
  private var retainedAnchor: Binding<String?> {
    Binding(get: { anchorID }, set: { if let value = $0 { anchorID = value } })
  }

  var body: some View {
    GeometryReader { geometry in
      #if os(iOS)
      if geometry.size.width >= 720, geometry.size.height >= 360 {
        bookContent(size: geometry.size)
      } else { continuousContent }
      #else
      continuousContent
      #endif
    }
  }

  private var continuousContent: some View {
    ScrollViewReader { proxy in
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 16) {
        ForEach(ids, id: \.self) { id in
          item(id).id(id)
        }
      }
      .scrollTargetLayout()
      .frame(maxWidth: 720, alignment: .leading)
      .frame(maxWidth: .infinity)
      .padding(20)
    }
    .scrollPosition(id: retainedAnchor, anchor: .top)
    .environment(\.layoutDirection, direction)
    .accessibilityIdentifier("bible.continuousReader")
    .onChange(of: jumpGeneration) { _, _ in
      if let anchorID { proxy.scrollTo(anchorID, anchor: .top) }
    }
    }
  }

  #if os(iOS)
  private func bookContent(size: CGSize) -> some View {
    let width = max(1, leafSizes.values.map(\.width).min() ?? (size.width - 72) / 2)
    let height = max(1, leafSizes.values.map(\.height).min() ?? size.height - 100)
    let pages = BibleBookPagination.pages(heights: ids.map { heights[$0] ?? height }, availableHeight: height)
    let spreadCount = max(1, (pages.count + 1) / 2)
    let selected = BibleBookPagination.spread(containing: ids.firstIndex(of: anchorID ?? "") ?? 0, pages: pages)
    let selection = Binding(get: { min(selected, spreadCount - 1) }, set: { spread in
      guard pages.indices.contains(spread * 2) else { return }
      anchorID = ids[pages[spread * 2].lowerBound]
    })

    return VStack(spacing: 12) {
      turningPages(pages: pages, selection: selection, selected: selected, spreadCount: spreadCount)
      HStack {
        Button { selection.wrappedValue -= 1 } label: {
          Label(bibleLabel("previousPage", "Previous Page"), systemImage: direction == .rightToLeft ? "chevron.right" : "chevron.left")
        }
        .disabled(selected == 0)
        .accessibilityIdentifier("bible.previousPage")
        Spacer()
        Text(String(format: bibleLabel("pageCount", "Pages %1$d–%2$d of %3$d"), locale: UILanguage.locale,
          selected * 2 + 1, min(selected * 2 + 2, pages.count), pages.count))
          .font(.caption).monospacedDigit()
          .accessibilityIdentifier("bible.pageCount")
        Spacer()
        Button { selection.wrappedValue += 1 } label: {
          Label(bibleLabel("nextPage", "Next Page"), systemImage: direction == .rightToLeft ? "chevron.left" : "chevron.right")
        }
        .disabled(selected >= spreadCount - 1)
        .accessibilityIdentifier("bible.nextPage")
      }
      .labelStyle(.iconOnly)
      .buttonStyle(.bordered)
      .controlSize(.large)
      .environment(\.layoutDirection, direction)
      .padding(.horizontal, 20)
      .padding(.bottom, 8)
    }
    .background(alignment: .topLeading) {
      // Measure the actual shared rows, including source notes and Dynamic Type. Hidden
      // measurement copies never enter selection, accessibility or pointer interaction.
      ZStack(alignment: .topLeading) {
        ForEach(ids, id: \.self) { id in
          item(id, bookTypography: true)
            .frame(width: width, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { heights[id] = $0 }
        }
      }
      .hidden().accessibilityHidden(true).allowsHitTesting(false)
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("bible.bookReader")
  }

  @ViewBuilder
  private func turningPages(pages: [Range<Int>], selection: Binding<Int>, selected: Int, spreadCount: Int) -> some View {
    if #available(iOS 27.1, *) {
      GeometryReader { geometry in
        let bounds = CGRect(origin: .zero, size: geometry.size)
        let folded = geometry.reservedRegions(kind: .division).contains {
          $0.isActive && PrayerReservedRegionLayout.intersects($0.frame, bounds: bounds)
        }
        if folded {
          // A bent display supplies the physical spine. Keep native reserved-region
          // placement while the hinge is active, with the same source-based turns.
          TabView(selection: selection) {
            ForEach(0..<spreadCount, id: \.self) { spread in
              ArrangementView {
                page(spread * 2, slot: 0, pages: pages, active: spread == selected)
              } secondary: {
                page(spread * 2 + 1, slot: 1, pages: pages, active: spread == selected)
              }
              .arrangementViewStyle(.split)
              .padding(.horizontal, 20)
              .tag(spread)
            }
          }
          .tabViewStyle(.page(indexDisplayMode: .never))
          .environment(\.layoutDirection, direction)
        } else {
          curlingPages(pages: pages, selection: selection)
        }
      }
    } else {
      curlingPages(pages: pages, selection: selection)
    }
  }

  private func curlingPages(pages: [Range<Int>], selection: Binding<Int>) -> some View {
    BibleBookPageCurlView(pageCount: pages.count, selection: selection,
      isRightToLeft: direction == .rightToLeft,
      revision: AnyHashable("\(pages)|\(script)|\(typography.typefaces)|\(jumpGeneration)")) { number, slot, active in
      page(number, slot: slot, pages: pages, active: active)
    }
    .padding(.horizontal, 20)
    .environment(\.layoutDirection, direction)
  }

  private func page(_ number: Int, slot: Int, pages: [Range<Int>], active: Bool) -> some View {
    GeometryReader { geometry in
      BibleBookLeaf(ids: pages.indices.contains(number) ? pages[number].map { ids[$0] } : [],
        active: active, anchorID: $anchorID, jumpGeneration: jumpGeneration) { item($0, bookTypography: true) }
      .id(number)
      .onGeometryChange(for: CGSize.self) { $0.size } action: {
        leafSizes[slot] = CGSize(width: max(1, $0.width - 32), height: max(1, $0.height - 32))
      }
      .frame(width: geometry.size.width, height: geometry.size.height)
    }
    .background(.background)
    .overlay { RoundedRectangle(cornerRadius: 4).strokeBorder(.secondary.opacity(0.2), lineWidth: 1).allowsHitTesting(false) }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("bible.page.\(slot)")
  }
  #endif

  @ViewBuilder
  private func item(_ id: String, bookTypography: Bool = false) -> some View {
    switch id {
    case "chapter.partial":
      Text(bibleLabel("partial", "Only part of this chapter is available"))
        .font(.callout).foregroundStyle(.secondary).accessibilityIdentifier("bible.partial")
        .environment(\.layoutDirection, interfaceDirection)
    case "chapter.introduction":
      if let introduction = book.introduction(for: display.chapter.chapter) {
        #if os(iOS)
        if bookTypography {
          BibleBookVerseText(text: introduction, label: nil, languageCode: edition.languageCode,
            isRightToLeft: edition.readingEdition.isBibleRightToLeft, typefaces: typography.typefaces)
            .accessibilityIdentifier("bible.introduction")
        } else {
          ScriptureIntroduction(text: introduction, edition: edition.readingEdition)
        }
        #else
        ScriptureIntroduction(text: introduction, edition: edition.readingEdition)
        #endif
      }
    case "chapter.heading":
      BibleSourceChapterHeading(edition: edition.readingEdition, chapter: display.chapter.chapter,
        script: script, canonicalReference: canonicalReference)
    case "chapter.credits":
      BibleCredits(edition: edition.readingEdition, book: book)
        .environment(\.layoutDirection, interfaceDirection)
    default:
      if let block = display.blocks.first(where: { $0.id == id }) {
        BibleSourceBlockRow(edition: edition.readingEdition, displayChapter: display.chapter.chapter,
          block: block, script: script, canonicalReference: canonicalReference, bookTypography: bookTypography)
      }
    }
  }
}

#if os(iOS)
private struct BibleBookLeaf<Content: View>: View {
  let ids: [String]
  let active: Bool
  @Binding var anchorID: String?
  let jumpGeneration: Int
  @ViewBuilder let content: (String) -> Content
  @State private var visibleID: String?
  @State private var isScrolling = false

  var body: some View {
    ScrollViewReader { proxy in
      trackedScroll {
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 16) {
            ForEach(ids, id: \.self) { id in content(id).id(id) }
          }
          .scrollTargetLayout()
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(16)
        }
        .scrollPosition(id: $visibleID, anchor: .top)
      }
      .onAppear { scrollToAnchor(proxy) }
      .onChange(of: anchorID) { _, _ in if !isScrolling { scrollToAnchor(proxy) } }
      .onChange(of: jumpGeneration) { _, _ in scrollToAnchor(proxy) }
      .onChange(of: ids) { _, _ in scrollToAnchor(proxy) }
      .onChange(of: visibleID) { _, id in
        if active, isScrolling, let id { anchorID = id }
      }
      .simultaneousGesture(TapGesture().onEnded {
        if active { anchorID = visibleID ?? ids.first }
      })
    }
  }

  private func scrollToAnchor(_ proxy: ScrollViewProxy) {
    if let anchorID, ids.contains(anchorID) { proxy.scrollTo(anchorID, anchor: .top) }
  }

  @ViewBuilder
  private func trackedScroll<ScrollContent: View>(@ViewBuilder _ content: () -> ScrollContent) -> some View {
    if #available(iOS 18.0, *) {
      content().onScrollPhaseChange { _, phase in
        let wasScrolling = isScrolling
        isScrolling = phase == .interacting || phase == .decelerating
        if active, wasScrolling, phase == .idle, let visibleID { anchorID = visibleID }
      }
    } else {
      content().simultaneousGesture(DragGesture().onChanged { value in
        isScrolling = abs(value.translation.height) > abs(value.translation.width)
      }.onEnded { _ in
        if active, isScrolling, let visibleID { anchorID = visibleID }
        isScrolling = false
      })
    }
  }
}
#endif
