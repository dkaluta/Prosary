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

        section(String(localized: "about.section.typefaces", defaultValue: "Typefaces")) {
          Text("about.typefaces.frankRuhlLibre")
          Text("about.typefaces.shofar")
          Text("about.typefaces.amiri")
          Text("about.typefaces.scheherazadeNew")
          Text("about.typefaces.cardo")
          Text("about.typefaces.notoSyriac")
          Text("about.typefaces.optionalHebrew")
          Text("about.typefaces.stam")
          Text("about.typefaces.systemSerifNote")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
        }

        section(String(localized: "about.section.mysteries", defaultValue: "Mystery Illustrations")) {
          Text("about.mysteryImages.intro")
            .font(.footnote)
            .foregroundStyle(.secondary)
          ForEach(mysteryAttributions, id: \.self) { key in
            Text(LocalizedStringKey(key))
          }
          Text(String(
            localized: "about.mysteryImages.easternIcons",
            defaultValue: "The collection of illustrations of the Mysteries in the Eastern style is used with approval from the Mission of St. Gamaliel for Hebrew Catholics in the Aramaic (Syriac) Catholic Church."))
            .padding(.top, 4)
        }

        section(String(localized: "about.section.other", defaultValue: "Other Images")) {
          ForEach(otherImageAttributions, id: \.self) { key in
            Text(LocalizedStringKey(key))
          }
        }

        section(String(localized: "about.section.stations", defaultValue: "Stations of the Cross Illustrations")) {
          Text(String(
            localized: "about.stationImages.fugelCycle",
            defaultValue: "All 14 stations: Gebhard Fugel (1863\u{2013}1939), Kreuzweg (1921), St. Antonius, Bad Saulgau \u{2014} public domain; photographs by Andreas Praefcke, released into the public domain."))
          Text(String(
            localized: "about.stationImages.scripturalScenes",
            defaultValue: "The scriptural (St. John Paul II) form adds: The Kiss of Judas \u{2014} Giotto (Scrovegni Chapel, c. 1305); Christ before the High Priest \u{2014} Gerrit van Honthorst (c. 1617), National Gallery, London; The Denial of St Peter \u{2014} Rembrandt (1660), Rijksmuseum; Le Coup de Lance \u{2014} Peter Paul Rubens (1620), Royal Museum of Fine Arts Antwerp \u{2014} all public domain. Its other scenes reuse illustrations listed elsewhere on this page."))
          Text(String(
            localized: "about.viaLucisImages.scenes",
            defaultValue: "The Via Lucis scenes: The Disciples at the Tomb \u{2014} Eug\u{00E8}ne Burnand (1898), Mus\u{00E9}e d'Orsay; Noli me tangere \u{2014} Fra Angelico (San Marco, c. 1440); The Road to Emmaus, the appearances to the apostles, at Lake Tiberias, and in Galilee \u{2014} Duccio di Buoninsegna (Maest\u{00E0}, 1308\u{2013}1311), Siena; Supper at Emmaus (1601) and The Incredulity of Saint Thomas (1601\u{2013}1602) \u{2014} Caravaggio; Christ's Charge to Peter \u{2014} Raphael (c. 1515), Royal Collection; The Virgin in Prayer \u{2014} Sassoferrato (1640\u{2013}1650), National Gallery, London \u{2014} all public domain. Its other scenes reuse the Rosary's glorious-mystery illustrations."))
        }

        section(String(localized: "about.section.crown", defaultValue: "Franciscan Crown Illustration")) {
          Text(String(
            localized: "about.franciscanCrownImage.magiMurillo",
            defaultValue: "The Adoration of the Magi: Bartolom\u{00E9} Esteban Murillo (c. 1655\u{2013}60), Toledo Museum of Art \u{2014} public domain. The other six Joys reuse the Rosary mystery illustrations above."))
        }

        section(String(localized: "about.section.sorrows", defaultValue: "Seven Sorrows Illustrations")) {
          ForEach(sevenSorrowsAttributions, id: \.self) { key in
            Text(LocalizedStringKey(key))
          }
        }

        section(String(localized: "about.section.divineMercy", defaultValue: "Divine Mercy Illustration")) {
          Text(String(
            localized: "about.divineMercyImage.kazimirowski",
            defaultValue: "Eugeniusz Kazimirowski, Divine Mercy (\u{201C}Jezu, ufam Tobie\u{201D}, 1934), Divine Mercy Sanctuary, Vilnius \u{2014} the original image painted under St. Faustina\u{2019}s direction; public domain."))
        }

        section(String(localized: "about.section.jesusPrayer", defaultValue: "Jesus Prayer Illustration")) {
          Text(String(
            localized: "about.jesusPrayerImage.pantocrator",
            defaultValue: "Christ Pantocrator: encaustic icon (6th century), Saint Catherine\u{2019}s Monastery, Mount Sinai \u{2014} the oldest surviving icon of Christ Pantocrator, honoring the prayer\u{2019}s Eastern tradition; public domain."))
        }

        section(String(localized: "about.section.prayerTexts", defaultValue: "Prayer Texts")) {
          Text("about.prayerTexts")
            .font(.footnote)
            .foregroundStyle(.secondary)
          Text("about.additionalPrayerSources")
            .font(.footnote)
            .foregroundStyle(.secondary)
          Text("about.divineMercyPrayerSources")
            .font(.footnote)
            .foregroundStyle(.secondary)
          Text("about.sevenSorrowsPrayerSources")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }

        section(String(localized: "about.section.scripture", defaultValue: "Scripture Sources")) {
          Text("about.scriptureSources")
            .font(.footnote)
            .foregroundStyle(.secondary)
          Text("about.additionalSources")
            .font(.footnote)
            .foregroundStyle(.secondary)
          Link("about.parolaVivaLink", destination: URL(string: "https://parolaviva.art/opendata")!)
        }

        section(String(localized: "about.section.calendar", defaultValue: "Calendar Data")) {
          Text("about.calendarData")
            .font(.footnote)
            .foregroundStyle(.secondary)
          Text("about.readingBookSources")
            .font(.footnote)
            .foregroundStyle(.secondary)
          Link("about.popeNetworkLink", destination: URL(string: "https://www.popesprayer.va/pray/")!)
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

  /// One classical work per sorrow — full source files and licenses in Shared/Images/CREDITS.markdown.
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
