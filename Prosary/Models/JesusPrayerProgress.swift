//
//  JesusPrayerProgress.swift
//  Prosary
//
//  Pure UI-computed presentation state for the Jesus Prayer's repetition counter — mirrors how
//  BeadLayout (RosaryFlow/BeadModels.swift) is a pure struct derived from the backend's steps
//  rather than something the backend itself provides. There's no engine/backend for the Jesus
//  Prayer: every repetition prays the same fixed line, so there's nothing for a backend to build
//  beyond this counter.
//

import Foundation

struct JesusPrayerProgress: Hashable {
    var target: JesusPrayerTarget
    /// 0-based, same convention as RosaryFlowView's currentIndex.
    var currentIndex: Int = 0

    /// Total repetitions for a bounded target; nil for `.unbounded`.
    var targetCount: Int? {
        if case let .count(count) = target { return count }
        return nil
    }

    var canGoBack: Bool { currentIndex > 0 }

    /// False for `.unbounded` — an unbounded session never auto-completes; the user ends it
    /// explicitly via the Finish action.
    var isLastRep: Bool {
        guard let targetCount else { return false }
        return currentIndex >= targetCount - 1
    }

    /// Nil for `.unbounded`, since there's no total to measure progress against.
    var progressFraction: Double? {
        guard let targetCount, targetCount > 0 else { return nil }
        return Double(currentIndex + 1) / Double(targetCount)
    }

    mutating func goNext() {
        guard !isLastRep else { return }
        currentIndex += 1
    }

    mutating func goBack() {
        guard canGoBack else { return }
        currentIndex -= 1
    }
}
