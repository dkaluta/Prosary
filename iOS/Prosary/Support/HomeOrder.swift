//
//  HomeOrder.swift
//  Prosary
//
//  The user's personal ordering of the Home cards (v0.7, Gamaliel item 2): a persisted list
//  of card ids. Cards absent from the list (newly installed devotions) keep their natural
//  directory order after the ordered ones; an empty list means pure directory order.
//

import Foundation

enum HomeOrder {
  private static let key = "homeCardOrder"

  static var saved: [String] {
    UserDefaults.standard.stringArray(forKey: key) ?? []
  }

  static func save(_ ids: [String]) {
    UserDefaults.standard.set(ids, forKey: key)
  }

  static func reset() {
    UserDefaults.standard.removeObject(forKey: key)
  }

  /// Stable sort by saved position; unknown ids keep their relative (directory) order at the
  /// end. Swift's sort isn't stable, so the original index breaks ties explicitly.
  static func apply<T>(_ cards: [T], id: (T) -> String) -> [T] {
    let order = saved
    guard !order.isEmpty else { return cards }
    return cards.enumerated()
      .sorted { a, b in
        let ia = order.firstIndex(of: id(a.element)) ?? Int.max
        let ib = order.firstIndex(of: id(b.element)) ?? Int.max
        return ia != ib ? ia < ib : a.offset < b.offset
      }
      .map(\.element)
  }

  /// The Pray tab used to order devotion *cards* ("rosary", "custom.trisagion"); it now orders
  /// favorites, whose ids are UUIDs. A saved order from the old scheme would silently rank
  /// nothing, so drop it the first time none of its ids belong to the list being ordered.
  static func dropOrderIfUnrelated(to currentIds: [String]) {
    let order = saved
    guard !order.isEmpty, !currentIds.isEmpty else { return }
    if order.allSatisfy({ !currentIds.contains($0) }) {
      reset()
    }
  }

  /// "My most important prayer first" — the one-move path (card context menu).
  static func moveToTop(_ cardId: String, allIdsInDisplayOrder: [String]) {
    save([cardId] + allIdsInDisplayOrder.filter { $0 != cardId })
  }
}
