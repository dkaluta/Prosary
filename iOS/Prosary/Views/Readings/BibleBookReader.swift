import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

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

  /// Measure the flowing candidate, not the sum of isolated verse paragraphs.
  static func flowPages(count: Int, availableHeight: CGFloat, measure: (Range<Int>) -> CGFloat) -> [Range<Int>] {
    guard count > 0 else { return [] }
    var result: [Range<Int>] = []
    var start = 0
    for end in 1...count {
      if end > start + 1, measure(start..<end) > max(1, availableHeight) {
        result.append(start..<(end - 1))
        start = end - 1
      }
    }
    result.append(start..<count)
    return result
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
  var previousChapter: (() -> Void)? = nil
  var nextChapter: (() -> Void)? = nil
  @Environment(\.layoutDirection) private var interfaceDirection
  @ObservedObject private var typography = PrayerTypographyMonitor.shared
  @ScaledMetric(relativeTo: .body) private var bodyScale = 1.0
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
      #if os(iOS) || os(macOS)
      bookContent(size: geometry.size)
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

  #if os(iOS) || os(macOS)
  private func bookContent(size: CGSize) -> some View {
    let leaves = size.width >= 720 && size.height >= 360 ? 2 : 1
    let width = max(1, leafSizes.values.map(\.width).min() ?? (size.width - 40) / CGFloat(leaves) - 32)
    let height = max(1, leafSizes.values.map(\.height).min() ?? size.height - 100)
    let pages = BibleBookPagination.flowPages(count: ids.count, availableHeight: height) { range in
      measuredHeight(range.map { ids[$0] }, width: width, fallback: height)
    }
    let spreadCount = max(1, (pages.count + leaves - 1) / leaves)
    let index = anchorID == "edition.previous.end" ? max(0, ids.count - 1) : ids.firstIndex(of: anchorID ?? "") ?? 0
    let selected = (pages.firstIndex { $0.contains(index) } ?? 0) / leaves
    let selection = Binding(get: { min(selected, spreadCount - 1) }, set: { spread in
      guard pages.indices.contains(spread * leaves) else { return }
      anchorID = ids[pages[spread * leaves].lowerBound]
    })

    return VStack(spacing: 12) {
      Group {
        if leaves == 2 {
          turningPages(pages: pages, selection: selection, selected: selected, spreadCount: spreadCount)
        } else {
          #if os(iOS)
          BibleBookPageCurlView(pageCount: pages.count, selection: selection,
            isRightToLeft: direction == .rightToLeft,
            revision: AnyHashable("\(pages)|\(script)|\(typography.typefaces)|\(jumpGeneration)"), leaves: 1,
            previousSection: previousChapter, nextSection: nextChapter) { number, slot, active in
              page(number, slot: slot, pages: pages, active: active)
            }.padding(.horizontal, 20)
          #else
          page(selected, slot: 0, pages: pages, active: true).padding(.horizontal, 20)
          #endif
        }
      }.id("\(display.chapter.book)|\(display.chapter.chapter)|\(leaves)")
      HStack {
        Button { if selected == 0 { previousChapter?() } else { selection.wrappedValue -= 1 } } label: {
          Label(bibleLabel("previousPage", "Previous Page"), systemImage: direction == .rightToLeft ? "chevron.right" : "chevron.left")
        }
        .disabled(selected == 0 && previousChapter == nil)
        .accessibilityIdentifier("bible.previousPage")
        Spacer()
        VStack(spacing: 2) {
          Text(bibleChapterLabel(display.chapter.chapter, book: book, edition: edition.readingEdition, script: script))
            .font(.caption2).foregroundStyle(.secondary)
          Text(String(format: bibleLabel("pageCount", "Pages %1$d–%2$d of %3$d"), locale: UILanguage.locale,
            selected * leaves + 1, min(selected * leaves + leaves, pages.count), pages.count))
            .font(.caption).monospacedDigit()
            .accessibilityIdentifier("bible.pageCount")
        }
        Spacer()
        Button { if selected >= spreadCount - 1 { nextChapter?() } else { selection.wrappedValue += 1 } } label: {
          Label(bibleLabel("nextPage", "Next Page"), systemImage: direction == .rightToLeft ? "chevron.left" : "chevron.right")
        }
        .disabled(selected >= spreadCount - 1 && nextChapter == nil)
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
    #if os(iOS)
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
    #else
    HStack(spacing: 24) {
      page(selected * 2, slot: 0, pages: pages, active: true)
      page(selected * 2 + 1, slot: 1, pages: pages, active: true)
    }.padding(.horizontal, 20).environment(\.layoutDirection, direction)
    #endif
  }

  #if os(iOS)
  private func curlingPages(pages: [Range<Int>], selection: Binding<Int>) -> some View {
    BibleBookPageCurlView(pageCount: pages.count, selection: selection,
      isRightToLeft: direction == .rightToLeft,
      revision: AnyHashable("\(pages)|\(script)|\(typography.typefaces)|\(jumpGeneration)"),
      previousSection: previousChapter, nextSection: nextChapter) { number, slot, active in
      page(number, slot: slot, pages: pages, active: active)
    }
    .padding(.horizontal, 20)
    .environment(\.layoutDirection, direction)
  }

  #endif

  private func textParts(_ group: [String]) -> [BibleBookTextPart] {
    group.compactMap { id in
      guard let block = display.blocks.first(where: { $0.id == id }), let unit = block.unit else { return nil }
      return BibleBookTextPart(text: unit.displayedText(script: script, edition: edition.readingEdition),
        label: biblePrimaryLabel(unit, displayChapter: display.chapter.chapter, edition: edition.readingEdition, script: script))
    }
  }

  private func measuredHeight(_ values: [String], width: CGFloat, fallback: CGFloat) -> CGFloat {
    let groups = paragraphGroups(values)
    return groups.reduce(CGFloat(max(0, groups.count - 1)) * 16) { total, group in
      guard group.count > 1 else { return total + (heights[group[0]] ?? fallback) }
      let parts = textParts(group)
      let text = parts.map(\.text).joined(separator: " ")
      let face = PrayerTypography.scriptureFace(script: PrayerTypography.resolvedScript(text: text, languageCode: edition.languageCode), typefaces: typography.typefaces)
      let font = BibleParagraphFont(name: face.name, size: face.size * bodyScale) ?? .systemFont(ofSize: face.size * bodyScale)
      let paragraph = BibleJustifiedParagraph(text: text, label: nil, font: font, isRightToLeft: direction == .rightToLeft, parts: parts)
      let bounds = paragraph.attributedText.boundingRect(with: CGSize(width: max(1, width), height: .greatestFiniteMagnitude),
        options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
      return total + ceil(bounds.height) + 2
    }
  }

  private func paragraphGroups(_ values: [String]) -> [[String]] {
    var result: [[String]] = []
    var flowing = false
    for id in values {
      let block = display.blocks.first { $0.id == id }
      let joins = canonicalReference == nil && block?.kind == .verse && block?.printedLabel == nil && block?.sourceNotes.isEmpty == true
      if joins, flowing { result[result.count - 1].append(id) }
      else { result.append([id]) }
      flowing = joins
    }
    return result
  }

  private func page(_ number: Int, slot: Int, pages: [Range<Int>], active: Bool) -> some View {
    GeometryReader { geometry in
      BibleBookLeaf(groups: paragraphGroups(pages.indices.contains(number) ? pages[number].map { ids[$0] } : []),
        active: active, anchorID: $anchorID, jumpGeneration: jumpGeneration) { group in
          if group.count > 1 {
            let parts = textParts(group)
            BibleBookVerseText(text: parts.map(\.text).joined(separator: " "), label: nil, languageCode: edition.languageCode,
              isRightToLeft: direction == .rightToLeft, typefaces: typography.typefaces, parts: parts)
              .accessibilityIdentifier("bible.paragraph.\(group[0])")
          } else if let id = group.first { item(id, bookTypography: true) }
        }
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
    .accessibilityHidden(!active)
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
        #if os(iOS) || os(macOS)
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
      Text(bibleChapterLabel(display.chapter.chapter, book: book, edition: edition.readingEdition, script: script))
        .font(.caption).foregroundStyle(.secondary)
        .accessibilityAddTraits(.isHeader).accessibilityIdentifier("readings.chapter.\(display.chapter.chapter)")
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

#if os(iOS) || os(macOS)
private struct BibleBookLeaf<Content: View>: View {
  let groups: [[String]]
  private var ids: [String] { groups.flatMap { $0 } }
  let active: Bool
  @Binding var anchorID: String?
  let jumpGeneration: Int
  @ViewBuilder let content: ([String]) -> Content
  @State private var visibleID: String?
  @State private var isScrolling = false

  var body: some View {
    ScrollViewReader { proxy in
      trackedScroll {
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 16) {
            ForEach(groups, id: \.first) { group in content(group).id(group.first!) }
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
    if let anchorID, let group = groups.first(where: { $0.contains(anchorID) }) { proxy.scrollTo(group.first!, anchor: .top) }
  }

  @ViewBuilder
  private func trackedScroll<ScrollContent: View>(@ViewBuilder _ content: () -> ScrollContent) -> some View {
    if #available(iOS 18.0, macOS 15.0, *) {
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
