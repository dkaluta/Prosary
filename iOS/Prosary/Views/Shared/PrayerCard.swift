
//
//  PrayerCard.swift
//  Prosary
//
//  Tappable devotion card on the Pray tab. Accent strip color is passed in
//  by the caller so the Rosary card can use the dynamic mystery-group color of the day.
//

import SwiftUI

struct PrayerCard: View {
  let systemImage: String
  /// One grapheme (letter or emoji) drawn instead of `systemImage` — the Compose "your own"
  /// icon (v0.7). Nil for the fixed icon set.
  var iconGlyph: String? = nil
  let title: String
  let subtitle: String
  let accentColor: Color
  /// Shown as a chevron the caller can tap separately — a row whose devotion has presets prays
  /// its default on tap and opens the list from here, so the common case stays one tap.
  var onDisclosure: (() -> Void)? = nil
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 0) {
        Rectangle()
          .fill(accentColor)
          .frame(width: 5)

        HStack(spacing: 12) {
          if let iconGlyph {
            Text(iconGlyph)
              .font(.title2)
              .foregroundStyle(accentColor)
              .frame(width: 32)
          } else {
            Image(systemName: systemImage)
              .font(.title2)
              .foregroundStyle(accentColor)
              .frame(width: 32)
          }

          VStack(alignment: .leading, spacing: 3) {
            Text(HebrewDisplayText.unpointed(title))
              .font(.headline)
              .foregroundStyle(.primary)
            if !subtitle.isEmpty {
              Text(HebrewDisplayText.unpointed(subtitle))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
          }

          Spacer()

          if let onDisclosure {
            // Its own button so tapping the chevron opens the presets while tapping the card
            // still prays; .borderless keeps the row's own Button from swallowing it.
            Button(action: onDisclosure) {
              Image(systemName: "chevron.forward.circle")
                .font(.title3)
                .foregroundStyle(accentColor)
                .padding(.leading, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(String(localized: "home.savedPresets", defaultValue: "Saved Presets…"))
          } else {
            Image(systemName: "chevron.forward")
              .font(.subheadline)
              .foregroundStyle(.tertiary)
          }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
      }
      .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
      .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    .buttonStyle(.plain)
  }
}
