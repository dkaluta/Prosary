//
//  AboutView.swift
//  Prosary
//
//  On Mac this is reachable only from the app menu (see ProsaryApp's CommandGroup), opening as
//  its own separate window — the native convention every Mac app follows, matching how "About
//  This Mac" and every other Mac app's About panel behaves. On iPhone/iPad there's no menu bar,
//  so HomeView links to this in-app instead.
//

import SwiftUI

struct AboutView: View {
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        VStack(alignment: .leading, spacing: 4) {
          Text("about.title")
            .font(.largeTitle.bold())
            .foregroundStyle(Color.brandHeadline)
          Text("about.tagline")
            .foregroundStyle(.secondary)
        }

        section("Typefaces") {
          Text("about.typefaces.frankRuhlLibre")
          Text("about.typefaces.shofar")
          Text("about.typefaces.amiri")
          Text("about.typefaces.scheherazadeNew")
          Text("about.typefaces.cardo")
          Text("about.typefaces.systemSerifNote")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
        }

        section("Mystery Illustrations") {
          Text("about.mysteryImages.intro")
            .font(.footnote)
            .foregroundStyle(.secondary)
          ForEach(mysteryAttributions, id: \.self) { key in
            Text(LocalizedStringKey(key))
          }
        }

        section("Other Images") {
          ForEach(otherImageAttributions, id: \.self) { key in
            Text(LocalizedStringKey(key))
          }
        }

        section("Stations of the Cross Illustrations") {
          Text("about.stationImages.intro")
            .font(.footnote)
            .foregroundStyle(.secondary)
          ForEach(stationAttributions, id: \.self) { key in
            Text(LocalizedStringKey(key))
          }
        }

        section("Franciscan Crown Illustration") {
          Text("about.franciscanCrownImages.intro")
            .font(.footnote)
            .foregroundStyle(.secondary)
          Text(LocalizedStringKey("about.franciscanCrownImage.adorationOfTheMagi"))
        }

        section("Seven Sorrows Illustrations") {
          Text("about.sevenSorrowsImages.intro")
            .font(.footnote)
            .foregroundStyle(.secondary)
          ForEach(sevenSorrowsAttributions, id: \.self) { key in
            Text(LocalizedStringKey(key))
          }
        }

        section("Divine Mercy Illustration") {
          Text("about.divineMercyImages.intro")
            .font(.footnote)
            .foregroundStyle(.secondary)
          Text(LocalizedStringKey("about.divineMercyImage.divineMercy"))
        }

        section("Scripture Sources") {
          Text("about.scriptureSources")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      }
      .padding(24)
      .frame(maxWidth: 560, alignment: .leading)
      .frame(maxWidth: .infinity)
    }
    .navigationTitle("about.navigationTitle")
  }

  @ViewBuilder
  private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.title3.weight(.semibold))
        .foregroundStyle(Color.brandHeadline)
      content()
    }
  }

  private let mysteryAttributions = [
    "about.mysteryImage.annunciation",
    "about.mysteryImage.visitation",
    "about.mysteryImage.holyNight",
    "about.mysteryImage.presentation",
    "about.mysteryImage.findingInTheTemple",
    "about.mysteryImage.baptism",
    "about.mysteryImage.weddingAtCana",
    "about.mysteryImage.sermonOnTheMount",
    "about.mysteryImage.transfiguration",
    "about.mysteryImage.lastSupper",
    "about.mysteryImage.agonyInTheGarden",
    "about.mysteryImage.flagellation",
    "about.mysteryImage.crowningWithThorns",
    "about.mysteryImage.carryingTheCross",
    "about.mysteryImage.crucifixion",
    "about.mysteryImage.resurrection",
    "about.mysteryImage.ascension",
    "about.mysteryImage.pentecost",
    "about.mysteryImage.assumption",
    "about.mysteryImage.coronation",
  ]

  private let otherImageAttributions = [
    "about.otherImage.crucifix",
    "about.otherImage.smallCowperMadonna",
    "about.otherImage.faithHopeCharity",
    "about.otherImage.prayingHands",
    "about.otherImage.holyTrinity",
    "about.otherImage.christInLimbo",
    "about.otherImage.michael",
    "about.otherImage.headOfChrist",
  ]

  /// Placeholder illustrations for now (see about.stationImages.intro) — real public-domain
  /// artwork with proper attribution hasn't been sourced yet for the 14 stations.
  private let stationAttributions = [
    "about.stationImage.station01", "about.stationImage.station02", "about.stationImage.station03",
    "about.stationImage.station04", "about.stationImage.station05", "about.stationImage.station06",
    "about.stationImage.station07", "about.stationImage.station08", "about.stationImage.station09",
    "about.stationImage.station10", "about.stationImage.station11", "about.stationImage.station12",
    "about.stationImage.station13", "about.stationImage.station14",
  ]

  /// Placeholder illustrations for now (see about.sevenSorrowsImages.intro) — real public-domain
  /// artwork with proper attribution hasn't been sourced yet for any of the 7 sorrows.
  private let sevenSorrowsAttributions = [
    "about.sevenSorrowsImage.sorrow01", "about.sevenSorrowsImage.sorrow02",
    "about.sevenSorrowsImage.sorrow03", "about.sevenSorrowsImage.sorrow04",
    "about.sevenSorrowsImage.sorrow05", "about.sevenSorrowsImage.sorrow06",
    "about.sevenSorrowsImage.sorrow07",
  ]
}

#Preview {
  NavigationStack {
    AboutView()
  }
}

#Preview("Dark Mode") {
  NavigationStack {
    AboutView()
  }
  .preferredColorScheme(.dark)
}
