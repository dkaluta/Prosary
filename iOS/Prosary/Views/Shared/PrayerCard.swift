
//
//  PrayerCard.swift
//  Prosary
//
//  Tappable card for a prayer kind on the Home screen. Accent strip color is passed in
//  by the caller so the Rosary card can use the dynamic mystery-group color of the day.
//

import SwiftUI

struct PrayerCard: View {
  let systemImage: String
  let title: String
  let subtitle: String
  let accentColor: Color
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 0) {
        Rectangle()
          .fill(accentColor)
          .frame(width: 5)

        HStack(spacing: 12) {
          Image(systemName: systemImage)
            .font(.title2)
            .foregroundStyle(accentColor)
            .frame(width: 32)

          VStack(alignment: .leading, spacing: 3) {
            Text(title)
              .font(.headline)
              .foregroundStyle(.primary)
            if !subtitle.isEmpty {
              Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
          }

          Spacer()

          Image(systemName: "chevron.right")
            .font(.subheadline)
            .foregroundStyle(.tertiary)
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
