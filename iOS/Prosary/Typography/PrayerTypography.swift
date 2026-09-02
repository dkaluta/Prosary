//
//  PrayerTypography.swift
//  Prosary
//
//  Resolves the serif typeface used for prayer/Scripture body text, per language and content
//  type. Scripture quotations (the mystery-announcement step) get a dedicated typeface distinct
//  from ordinary prayer text — Cardo (Latin/English) and Scheherazade New (Arabic) were both
//  designed for classical/Biblical typesetting, the same reasoning behind using Shofar (rather
//  than Frank Ruhl Libre) for Hebrew. Latin/English prayers use Apple's native "New York" serif
//  design rather than a bundled font, since it's not ours to redistribute.
//
//  All sizes are relative to `.body`, so custom fonts still respond to Dynamic Type.
//

import SwiftUI

enum PrayerTypography {
  static let syriacTypefaceKey = "syriacTypeface"
  static let hebrewPrayerTypefaceKey = "hebrewPrayerTypeface"
  static let hebrewScriptureTypefaceKey = "hebrewScriptureTypeface"

  enum TypefaceValue {
    static let `default` = "default"
    static let western = "western"
    static let eastern = "eastern"
    static let davidLibre = "davidLibre"
    static let sansSerif = "sansSerif"
    static let stamAshkenaz = "stamAshkenaz"
    static let stamSefarad = "stamSefarad"
    static let rashi = "rashi"
  }

  // macOS's native `.body` runs a good deal smaller than iOS's (~13pt vs. ~17pt). The sizes
  // below were tuned by eye against iOS, so without this correction the same literal point
  // sizes read as oversized next to the rest of a Mac window. Scaling keeps every custom
  // typeface in the same visual proportion to `.body` on both platforms.
  #if os(macOS)
  private static let scale: CGFloat = 0.76
  #else
  private static let scale: CGFloat = 1.0
  #endif

  /// The writing system a run of text is actually in.
  ///
  /// Nearly always this follows from the language, and `font(languageCode:isScripture:)` derives
  /// it that way. The exception is a transliteration, which is *by definition* in a different
  /// script from its own language's — and the bundle format deliberately leaves which script to
  /// the author (Hebrew letters for Tagalog, Syriac letters for Aramaic). So rather than have
  /// the format declare it and risk the declaration drifting from the text, it is read off the
  /// characters, which cannot disagree with themselves.
  enum Script {
    case hebrew, arabic, syriac, latin
  }

  /// The script the majority of a text's letters belong to. Counted rather than sampled: a
  /// citation line ("— ܡܬܝ 28:1-7") mixes digits and punctuation into every body.
  static func script(of text: String) -> Script {
    var hebrew = 0, arabic = 0, syriac = 0, latin = 0
    for scalar in text.unicodeScalars {
      switch scalar.value {
      case 0x0590...0x05FF: hebrew += 1
      case 0x0600...0x06FF, 0x0750...0x077F: arabic += 1
      case 0x0700...0x074F, 0x0860...0x086F: syriac += 1
      case 0x0041...0x005A, 0x0061...0x007A, 0x0370...0x03FF, 0x1F00...0x1FFF: latin += 1
      default: break
      }
    }
    let counts = [(hebrew, Script.hebrew), (arabic, .arabic), (syriac, .syriac), (latin, .latin)]
    return counts.max(by: { $0.0 < $1.0 })?.1 ?? .latin
  }

  /// `script` overrides what the language would imply — pass it when rendering a transliteration.
  static func font(languageCode: String?, isScripture: Bool, script: Script? = nil) -> Font {
    // Variants key on their base script: "he-x-gamliel" typesets exactly like "he".
    let baseCode = languageCode.map { code in
      LanguageCatalog.baseLanguage(of: code) ?? code
    }
    let resolved: Script = script ?? {
      switch baseCode {
      case "he", "arc": return .hebrew  // Aramaic ships in Hebrew square script
      case "ar": return .arabic
      default: return .latin
      }
    }()

    switch resolved {
    case .hebrew:
      if isScripture {
        let name = switch UserDefaults.standard.string(forKey: hebrewScriptureTypefaceKey) {
        case TypefaceValue.stamAshkenaz: FontRegistration.PostScriptName.stamAshkenaz
        case TypefaceValue.stamSefarad: FontRegistration.PostScriptName.stamSefarad
        case TypefaceValue.rashi: FontRegistration.PostScriptName.notoRashiHebrew
        default: FontRegistration.PostScriptName.shofar
        }
        return .custom(name, size: 16 * scale, relativeTo: .body)
      }
      let prayerTypeface = UserDefaults.standard.string(forKey: hebrewPrayerTypefaceKey)
      if prayerTypeface == TypefaceValue.sansSerif {
        return .system(size: 21 * scale, weight: .regular, design: .default)
      }
      let name = switch prayerTypeface {
      case TypefaceValue.davidLibre: FontRegistration.PostScriptName.davidLibre
      default: FontRegistration.PostScriptName.frankRuhlLibre
      }
      return .custom(name, size: 21 * scale, relativeTo: .body)

    case .arabic:
      return isScripture
        ? .custom(FontRegistration.PostScriptName.scheherazadeNew, size: 16 * scale, relativeTo: .body)
        : .custom(FontRegistration.PostScriptName.amiri, size: 18 * scale, relativeTo: .body)

    case .syriac:
      // Only ever reached through a transliteration: no language's own text is in Syriac
      // letters, because "arc" ships Aramaic in Hebrew script. Without a face that covers the
      // block the toggle would draw a line of tofu, which is worse than not offering it.
      let name = switch UserDefaults.standard.string(forKey: syriacTypefaceKey) {
      case TypefaceValue.western: FontRegistration.PostScriptName.notoSansSyriacWestern
      case TypefaceValue.eastern: FontRegistration.PostScriptName.notoSansSyriacEastern
      default: FontRegistration.PostScriptName.notoSansSyriac
      }
      return .custom(name, size: 19 * scale, relativeTo: .body)

    case .latin: // "la", "en", and any other Latin- or Greek-script language
      return isScripture
        ? .custom(FontRegistration.PostScriptName.cardo, size: 19 * scale, relativeTo: .body)
        : .system(.body, design: .serif)
    }
  }
}

#Preview("Typography Sample") {
  FontRegistration.registerBundledFontsIfNeeded()

  return ScrollView {
    VStack(alignment: .leading, spacing: 20) {
      ForEach(LanguageCatalog.all) { language in
        VStack(alignment: .leading, spacing: 8) {
          Text(language.nativeName).font(.headline)

          Text(PrayerTranslations.get(languageCode: language.code, key: .aveMaria))
            .font(PrayerTypography.font(languageCode: language.code, isScripture: false))
            .environment(\.layoutDirection, language.isRightToLeft ? .rightToLeft : .leftToRight)

          Text(MysteryTranslations.get(languageCode: language.code, imageKey: "joyful_01_annunciation").description)
            .font(PrayerTypography.font(languageCode: language.code, isScripture: true))
            .environment(\.layoutDirection, language.isRightToLeft ? .rightToLeft : .leftToRight)
        }
        Divider()
      }

      VStack(alignment: .leading, spacing: 8) {
        Text("Syriac (a transliteration)").font(.headline)
        Text("ܡܛܠ ܗܢܐ ܢܬܠ ܠܟܘܢ ܡܪܝܐ ܐܠܗܐ ܐܬܐ")
          .font(PrayerTypography.font(languageCode: "arc", isScripture: true, script: .syriac))
          .environment(\.layoutDirection, .rightToLeft)
      }
    }
    .padding()
  }
}
