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
          Text(String(
            localized: "about.stationImages.fugelCycle",
            defaultValue: "All 14 stations: Gebhard Fugel (1863\u{2013}1939), Kreuzweg (1921), St. Antonius, Bad Saulgau \u{2014} public domain; photographs by Andreas Praefcke, released into the public domain."))
        }

        section("Franciscan Crown Illustration") {
          Text(String(
            localized: "about.franciscanCrownImage.magiMurillo",
            defaultValue: "The Adoration of the Magi: Bartolom\u{00E9} Esteban Murillo (c. 1655\u{2013}60), Toledo Museum of Art \u{2014} public domain. The other six Joys reuse the Rosary mystery illustrations above."))
        }

        section("Seven Sorrows Illustrations") {
          ForEach(sevenSorrowsAttributions, id: \.self) { key in
            Text(LocalizedStringKey(key))
          }
        }

        section("Divine Mercy Illustration") {
          Text(String(
            localized: "about.divineMercyImage.kazimirowski",
            defaultValue: "Eugeniusz Kazimirowski, Divine Mercy (\u{201C}Jezu, ufam Tobie\u{201D}, 1934), Divine Mercy Sanctuary, Vilnius \u{2014} the original image painted under St. Faustina\u{2019}s direction; public domain."))
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

  /// One classical work per sorrow — full source files and licenses in Shared/Images/CREDITS.md.
  private let sevenSorrowsAttributions = [
    "about.sevenSorrowsImage.rembrandtSimeon",
    "about.sevenSorrowsImage.murilloFlight",
    "about.sevenSorrowsImage.veroneseDoctors",
    "about.sevenSorrowsImage.raphaelSpasimo",
    "about.sevenSorrowsImage.terBrugghenCrucifixion",
    "about.sevenSorrowsImage.rubensDescent",
    "about.sevenSorrowsImage.titianEntombment",
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
