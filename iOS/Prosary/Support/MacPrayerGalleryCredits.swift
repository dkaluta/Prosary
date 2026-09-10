#if os(macOS)
import Foundation

/// Source-linked credit metadata. Artwork and artist names retain their credited spellings.
enum MacPrayerGalleryCredits {
  struct Entry: Identifiable {
    let id: String
    let title: String
    let collection: String
    let source: URL
  }

  static let entries: [Entry] = [
    Entry(id: "angelus",
      title: "Jean-François Millet — L’Angélus (1857–1859)",
      collection: "Musée d’Orsay, RF 1877",
      source: URL(string: "https://commons.wikimedia.org/wiki/File:Jean-Fran%C3%A7ois_Millet_Angelus.jpg")!),
    Entry(id: "divineMercyChaplet",
      title: "Rembrandt van Rijn — The Return of the Prodigal Son (c. 1668)",
      collection: "State Hermitage Museum, 742",
      source: URL(string: "https://commons.wikimedia.org/wiki/File:Rembrandt_Harmensz._van_Rijn_-_The_Return_of_the_Prodigal_Son.jpg")!),
    Entry(id: "franciscanCrown",
      title: "Agnolo Gaddi — The Coronation of the Virgin with Six Angels (c. 1390)",
      collection: "Samuel H. Kress Collection, 1939.1.203; Courtesy National Gallery of Art, Washington",
      source: URL(string: "https://www.nga.gov/artworks/344-coronation-virgin-six-angels")!),
    Entry(id: "jesusPrayer",
      title: "El Greco — Christ Blessing (The Saviour of the World) (c. 1600)",
      collection: "Scottish National Gallery",
      source: URL(string: "https://commons.wikimedia.org/wiki/File:El_Greco_021.jpg")!),
    Entry(id: "litanyOfLoreto",
      title: "Raphael — Madonna of Loreto (c. 1509–1510)",
      collection: "Musée Condé, PE 40; Google Art Project",
      source: URL(string: "https://commons.wikimedia.org/wiki/File:Rapha%C3%ABl_-_La_Madone_de_Lorette_-_Google_Art_Project.jpg")!),
    Entry(id: "oAntiphons",
      title: "Circle of Geertgen tot Sint Jans — The Tree of Jesse (c. 1500)",
      collection: "Rijksmuseum, SK-A-3901",
      source: URL(string: "https://commons.wikimedia.org/wiki/File:De_boom_van_Jesse,_SK-A-3901.jpg")!),
    Entry(id: "rosary",
      title: "Bartolomé Esteban Murillo — Virgin and Child with a Rosary (c. 1650–1655)",
      collection: "Museo del Prado, P000975",
      source: URL(string: "https://commons.wikimedia.org/wiki/File:Virgen_del_Rosario_(Murillo).jpg")!),
    Entry(id: "sevenSorrows",
      title: "Anonymous Spanish Colonial artist — The Virgin of Sorrows (18th century)",
      collection: "The Metropolitan Museum of Art, 2007.49.347; Bequest of William S. Lieberman, 2005",
      source: URL(string: "https://www.metmuseum.org/art/collection/search/232209")!),
    Entry(id: "stationsOfTheCross",
      title: "El Greco — Christ Carrying the Cross (c. 1577–1587)",
      collection: "The Metropolitan Museum of Art, 1975.1.145",
      source: URL(string: "https://commons.wikimedia.org/wiki/File:Christ_Carrying_the_Cross_MET_DP347226.jpg")!),
    Entry(id: "trisagion",
      title: "Andrei Rublev — Trinity (early 15th century)",
      collection: "Historical Tretyakov Gallery reproduction",
      source: URL(string: "https://commons.wikimedia.org/wiki/File:Rublev_Troitsa.jpg")!),
    Entry(id: "viaLucis",
      title: "Matthias Grünewald — Resurrection (Isenheim Altarpiece) (1512–1516)",
      collection: "Musée Unterlinden; photograph by Gleb Simonov",
      source: URL(string: "https://commons.wikimedia.org/wiki/File:Matthias_Gr%C3%BCnewald_-_Resurrection.jpg")!),
  ]
}
#endif
