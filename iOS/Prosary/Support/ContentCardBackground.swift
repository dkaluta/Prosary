//
//  ContentCardBackground.swift
//  Prosary
//

import SwiftUI

enum TodayCardColor: String, CaseIterable, Identifiable {
  case `default`, blue, green, gold, rose
  static let defaultsKey = "todayCardColor"
  var id: String { rawValue }
  var title: String {
    let fallback: String = switch self {
    case .default: "Default"
    case .blue: "Blue"
    case .green: "Green"
    case .gold: "Gold"
    case .rose: "Rose"
    }
    return UILanguage.text("settings.todayCardColor.\(rawValue)", language: UILanguage.current, fallback: fallback)
  }
  var tint: Color {
    switch self {
    case .default: .clear
    case .blue: .blue.opacity(0.12)
    case .green: .green.opacity(0.12)
    case .gold: .yellow.opacity(0.14)
    case .rose: .pink.opacity(0.12)
    }
  }
}

struct TodayCardColorPicker: View {
  @AppStorage(TodayCardColor.defaultsKey) private var color = TodayCardColor.default.rawValue
  var body: some View {
    Picker(String(localized: "settings.todayCardColor", defaultValue: "Today card color", bundle: UILanguage.bundle, locale: UILanguage.locale), selection: $color) {
      ForEach(TodayCardColor.allCases) { color in Text(color.title).tag(color.rawValue) }
    }
    .accessibilityIdentifier("todayCardColorPicker")
  }
}

/// Stable papal keys remain appropriate when the Pope changes.
struct PapalKeysSymbol: View {
  var body: some View {
    ZStack {
      PapalKeyShape().stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
      PapalKeyShape().stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
        .scaleEffect(x: -1, y: 1)
    }
    .frame(width: 24, height: 24)
    .accessibilityHidden(true)
  }
}

private struct PapalKeyShape: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.addEllipse(in: CGRect(x: 2, y: 16, width: 6, height: 6))
    path.move(to: CGPoint(x: 7, y: 17))
    path.addLine(to: CGPoint(x: 20, y: 4))
    path.move(to: CGPoint(x: 19, y: 5))
    path.addLine(to: CGPoint(x: 16, y: 2))
    path.move(to: CGPoint(x: 16, y: 8))
    path.addLine(to: CGPoint(x: 13, y: 5))
    return path.applying(CGAffineTransform(scaleX: rect.width / 24, y: rect.height / 24))
  }
}

extension View {
  /// Cards belong to the scrolling content layer. Keep their fill opaque on iPhone and Mac;
  /// the spatial window uses a standard material to distinguish content groups within glass.
  @ViewBuilder
  func prosaryContentCardBackground(cornerRadius: CGFloat = 14) -> some View {
    #if os(visionOS)
    background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
    #elseif os(macOS)
    background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: cornerRadius))
    #else
    background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: cornerRadius))
    #endif
  }
}
