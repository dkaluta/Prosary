import Foundation

/// Headings belong to the selected Bible edition, independently of the interface and
/// prayer language. Aramaic follows the passage's chosen script.
struct ScriptureChapterHeading: Equatable {
  let label: String
  let number: String
  var text: String { "\(label) \(number)" }

  init(chapter: Int, edition: ReadingTextEdition, script: String) {
    let language = UILanguage.normalized(edition.languageCode)
    if language == "arc" {
      // CAL, LSt.3:4, attests both spellings; Kiraz's Antioch Bible foreword distinguishes
      // this modern chapter label from the older, differently divided ṣḥḥā sections.
      // https://cal.huc.edu/oneentry.php?cits=all&lemma=%29+s
      label = script == "Syrc" ? "ܩܦܠܐܘܢ" : "קפלאון"
    } else if language == "el" {
      label = "Κεφάλαιο"
    } else {
      label = UILanguage.text("readings.chapter", language: language, fallback: "Chapter")
    }
    number = Self.number(chapter, language: language, script: script)
  }

  nonisolated static func number(_ chapter: Int, language: String, script: String = "Hebr") -> String {
    let code = UILanguage.normalized(language)
    if (1...999).contains(chapter), code == "he" || (code == "arc" && script != "Syrc") {
      var remainder = chapter
      var letters = ""
      for (value, letter) in [(400, "ת"), (300, "ש"), (200, "ר"), (100, "ק")] {
        while remainder >= value { letters += letter; remainder -= value }
      }
      if remainder == 15 { letters += "טו" }
      else if remainder == 16 { letters += "טז" }
      else {
        for (value, letter) in [(90, "צ"), (80, "פ"), (70, "ע"), (60, "ס"), (50, "נ"),
                                (40, "מ"), (30, "ל"), (20, "כ"), (10, "י"), (9, "ט"),
                                (8, "ח"), (7, "ז"), (6, "ו"), (5, "ה"), (4, "ד"),
                                (3, "ג"), (2, "ב"), (1, "א")] {
          if remainder >= value { letters += letter; remainder -= value }
        }
      }
      if letters.count == 1 { return letters + "׳" }
      letters.insert("״", at: letters.index(before: letters.endIndex))
      return letters
    }
    if (1...999).contains(chapter), code == "arc", script == "Syrc" {
      // Syriac biblical headings use letter numerals without Hebrew's 15/16 substitution:
      // https://www.maryosipparish.org/documents/assyrian/peshitta/matthew/15.html
      var remainder = chapter
      var letters = ""
      for (value, letter) in [(400, "ܬ"), (300, "ܫ"), (200, "ܪ"), (100, "ܩ"), (90, "ܨ"),
                              (80, "ܦ"), (70, "ܥ"), (60, "ܣ"), (50, "ܢ"), (40, "ܡ"),
                              (30, "ܠ"), (20, "ܟ"), (10, "ܝ"), (9, "ܛ"), (8, "ܚ"),
                              (7, "ܙ"), (6, "ܘ"), (5, "ܗ"), (4, "ܕ"), (3, "ܓ"), (2, "ܒ"), (1, "ܐ")] {
        while remainder >= value { letters += letter; remainder -= value }
      }
      return letters
    }
    if code == "ar" {
      // NumberFormatter can inherit the person's Latin-digit preference even with an
      // Arabic numbering-system locale. This heading follows the Arabic Bible's digits.
      let digits = Array("٠١٢٣٤٥٦٧٨٩")
      return String(String(chapter).map { character in
        character.wholeNumberValue.map { digits[$0] } ?? character
      })
    }
    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: code == "tl" ? "fil" : code)
    formatter.numberStyle = .decimal
    formatter.usesGroupingSeparator = false
    formatter.maximumFractionDigits = 0
    return formatter.string(from: NSNumber(value: chapter)) ?? String(chapter)
  }
}
