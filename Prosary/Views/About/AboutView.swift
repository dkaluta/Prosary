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
          Text("Prosary")
            .font(.largeTitle.bold())
            .foregroundStyle(Color.brandHeadline)
          Text("A companion for praying the Rosary and other Catholic devotions.")
            .foregroundStyle(.secondary)
        }

        section("Typefaces") {
          Text("**Frank Ruhl Libre** — SIL Open Font License 1.1 — Hebrew prayers.")
          Text("**Shofar** — GPL v2 with font-embedding exception — Hebrew Scripture (Culmus Project, Yoram Gnat).")
          Text("**Amiri** — SIL Open Font License 1.1 — Arabic prayers.")
          Text("**Scheherazade New** — SIL Open Font License 1.1 — Arabic Scripture (SIL).")
          Text("**Cardo** — SIL Open Font License 1.1 — Latin/English Scripture (David J. Perry).")
          Text("Latin-script prayers use Apple's system \"New York\" serif design — not bundled with the app.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
        }

        section("Mystery Illustrations") {
          Text("All 20 mystery images are classical paintings in the public domain (artist deceased over 100 years), sourced from Wikimedia Commons.")
            .font(.footnote)
            .foregroundStyle(.secondary)
          ForEach(mysteryAttributions, id: \.self) { line in
            Text(LocalizedStringKey(line))
          }
        }

        section("Other Images") {
          ForEach(otherImageAttributions, id: \.self) { line in
            Text(LocalizedStringKey(line))
          }
        }

        section("Scripture Sources") {
          Text("Mystery meditations quote the Douay-Rheims Bible (English), the Clementine Vulgate (Latin), Franz Delitzsch's Hebrew New Testament translation (sourced from kirjasilta.net/ha-berit), the Jesuit Arabic Bible (Beirut, 1880, revised 1988), the Russian Synodal Bible (1876), and Ang Dating Biblia (Tagalog, 1905) — all public domain.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      }
      .padding(24)
      .frame(maxWidth: 560, alignment: .leading)
      .frame(maxWidth: .infinity)
    }
    .navigationTitle("About Prosary")
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
    "*The Annunciation* — Fra Angelico (d. 1455)",
    "*The Visitation* — Mariotto Albertinelli (d. 1515)",
    "*The Holy Night* — Antonio da Correggio (d. 1534)",
    "*The Presentation at the Temple* — Andrea Mantegna (d. 1506)",
    "*Christ Discovered in the Temple* — Simone Martini (d. 1344)",
    "*The Baptism of Christ* — Piero della Francesca (d. 1492)",
    "*The Wedding at Cana* — Paolo Veronese (d. 1588)",
    "*The Sermon on the Mount* — Cosimo Rosselli (d. 1507)",
    "*The Transfiguration* — Raphael (d. 1520)",
    "*The Last Supper* — Leonardo da Vinci (d. 1519)",
    "*The Agony in the Garden* — Andrea Mantegna (d. 1506)",
    "*The Flagellation of Christ* — Caravaggio (d. 1610)",
    "*The Crowning with Thorns* — Caravaggio (d. 1610)",
    "*Christ Carrying the Cross* — Titian (d. 1576)",
    "*Christ Crucified* — Diego Velázquez (d. 1660)",
    "*The Resurrection* — Piero della Francesca (d. 1492)",
    "*The Ascension of Christ* — Rembrandt (d. 1669)",
    "*The Pentecost* — El Greco (d. 1614)",
    "*Assumption of the Virgin* — Titian (d. 1576)",
    "*Coronation of the Virgin* — Diego Velázquez (d. 1660)",
  ]

  private let otherImageAttributions = [
    "*Crucifix* — Cimabue (d. 1302).",
    "*The Small Cowper Madonna* — Raphael (d. 1520).",
    "*Faith, Hope, and Charity* — Raphael, Baglioni altarpiece predella (d. 1520).",
    "*Praying Hands* — Albrecht Dürer (d. 1528).",
    "*Holy Trinity* — Masaccio (d. 1428).",
    "*Christ in Limbo* — Fra Angelico (d. 1455).",
    "*Michael* — Guido Reni (d. 1642).",
    "*Head of Christ* — Rembrandt (d. 1669).",
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
