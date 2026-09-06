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
import Combine

/// Display headings in Hebrew are deliberately unpointed even when their canonical source text
/// is vocalized. Keep this at the presentation boundary: prayer bodies and Scripture retain every
/// authored niqqud/cantillation mark.
enum HebrewDisplayText {
  nonisolated static func unpointed(_ text: String) -> String {
    String(text.unicodeScalars.filter { !isHebrewPoint($0.value) })
  }

  nonisolated private static func isHebrewPoint(_ value: UInt32) -> Bool {
    switch value {
    case 0x0591...0x05BD, 0x05BF, 0x05C1...0x05C2, 0x05C4...0x05C5, 0x05C7, 0xFB1E:
      return true
    default:
      return false
    }
  }
}

enum PrayerTypography {
  static let syriacTypefaceKey = "syriacTypeface"
  static let hebrewPrayerTypefaceKey = "hebrewPrayerTypeface"
  static let hebrewScriptureTypefaceKey = "hebrewScriptureTypeface"
  static let latinPrayerTypefaceKey = "latinPrayerTypeface"
  static let cyrillicPrayerTypefaceKey = "cyrillicPrayerTypeface"

  struct Typefaces: Equatable {
    var syriac = TypefaceValue.default
    var hebrewPrayer = TypefaceValue.default
    var hebrewScripture = TypefaceValue.default
    var latinPrayer = TypefaceValue.default
    var cyrillicPrayer = TypefaceValue.default

    static var current: Self {
      let defaults = UserDefaults.standard
      return Self(
        syriac: defaults.string(forKey: syriacTypefaceKey) ?? TypefaceValue.default,
        hebrewPrayer: defaults.string(forKey: hebrewPrayerTypefaceKey) ?? TypefaceValue.default,
        hebrewScripture: defaults.string(forKey: hebrewScriptureTypefaceKey) ?? TypefaceValue.default,
        latinPrayer: defaults.string(forKey: latinPrayerTypefaceKey) ?? TypefaceValue.default,
        cyrillicPrayer: defaults.string(forKey: cyrillicPrayerTypefaceKey) ?? TypefaceValue.default)
    }
  }

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
  /// Imported prayers and transliterations may use a different script from their language's
  /// built-in texts. Render their actual letters; language is only a fallback for empty text.
  enum Script: Equatable {
    case hebrew, arabic, syriac, latin, cyrillic, greek
  }

  /// The script the majority of a text's letters belong to. Counted rather than sampled: a
  /// citation line ("— ܡܬܝ 28:1–7") mixes digits and punctuation into every body.
  static func script(of text: String) -> Script {
    detectedScript(of: text) ?? .latin
  }

  private static func detectedScript(of text: String) -> Script? {
    var hebrew = 0, arabic = 0, syriac = 0, latin = 0, cyrillic = 0, greek = 0
    for scalar in text.unicodeScalars {
      guard CharacterSet.letters.contains(scalar) else { continue }
      switch scalar.value {
      case 0x0590...0x05FF, 0xFB1D...0xFB4F: hebrew += 1
      case 0x0600...0x06FF, 0x0750...0x077F, 0x0870...0x089F, 0x08A0...0x08FF,
           0xFB50...0xFDFF, 0xFE70...0xFEFF: arabic += 1
      case 0x0700...0x074F, 0x0860...0x086F: syriac += 1
      case 0x0400...0x052F, 0x1C80...0x1C8F, 0x2DE0...0x2DFF, 0xA640...0xA69F: cyrillic += 1
      case 0x0370...0x03FF, 0x1F00...0x1FFF: greek += 1
      case 0x0041...0x005A, 0x0061...0x007A, 0x00C0...0x024F, 0x1E00...0x1EFF: latin += 1
      default: break
      }
    }
    let counts = [(hebrew, Script.hebrew), (arabic, .arabic), (syriac, .syriac),
                  (latin, .latin), (cyrillic, .cyrillic), (greek, .greek)]
    guard let winner = counts.max(by: { $0.0 < $1.0 }), winner.0 > 0 else { return nil }
    return winner.1
  }

  static func resolvedScript(text: String?, languageCode: String?) -> Script {
    if let text, let detected = detectedScript(of: text) { return detected }
    // Variants key on their base script: "he-x-gamliel" typesets exactly like "he".
    let baseCode = languageCode.map { code in
      LanguageCatalog.baseLanguage(of: code) ?? code
    }
    switch baseCode {
    case "he", "arc": return .hebrew  // Built-in Aramaic uses Hebrew square script.
    case "ar": return .arabic
    case "ru": return .cyrillic
    case "el": return .greek
    default: return .latin
    }
  }

  static func font(languageCode: String?, isScripture: Bool, text: String? = nil,
                   script: Script? = nil, typefaces: Typefaces = .current, pointSize: CGFloat? = nil) -> Font {
    let resolved = script ?? resolvedScript(text: text, languageCode: languageCode)

    switch resolved {
    case .hebrew:
      if isScripture {
        let name = switch typefaces.hebrewScripture {
        case TypefaceValue.stamAshkenaz: FontRegistration.PostScriptName.stamAshkenaz
        case TypefaceValue.stamSefarad: FontRegistration.PostScriptName.stamSefarad
        case TypefaceValue.rashi: FontRegistration.PostScriptName.notoRashiHebrew
        default: FontRegistration.PostScriptName.shofar
        }
        return .custom(name, size: (pointSize ?? 16) * scale, relativeTo: .body)
      }
      let prayerTypeface = typefaces.hebrewPrayer
      if prayerTypeface == TypefaceValue.sansSerif {
        return .system(size: (pointSize ?? 21) * scale, weight: .regular, design: .default)
      }
      let name = switch prayerTypeface {
      case TypefaceValue.davidLibre: FontRegistration.PostScriptName.davidLibre
      default: FontRegistration.PostScriptName.frankRuhlLibre
      }
      return .custom(name, size: (pointSize ?? 21) * scale, relativeTo: .body)

    case .arabic:
      return isScripture
        ? .custom(FontRegistration.PostScriptName.scheherazadeNew, size: 16 * scale, relativeTo: .body)
        : .custom(FontRegistration.PostScriptName.amiri, size: 18 * scale, relativeTo: .body)

    case .syriac:
      // Custom Aramaic bodies and Syriac transliterations share the chosen Syriac face.
      let name = switch typefaces.syriac {
      case TypefaceValue.western: FontRegistration.PostScriptName.notoSansSyriacWestern
      case TypefaceValue.eastern: FontRegistration.PostScriptName.notoSansSyriacEastern
      default: FontRegistration.PostScriptName.notoSansSyriac
      }
      return .custom(name, size: (pointSize ?? 19) * scale, relativeTo: .body)

    case .latin, .cyrillic, .greek:
      let choice = resolved == .cyrillic ? typefaces.cyrillicPrayer
        : resolved == .latin ? typefaces.latinPrayer : TypefaceValue.default
      return isScripture
        ? .custom(FontRegistration.PostScriptName.cardo, size: 19 * scale, relativeTo: .body)
        : .system(.body, design: choice == TypefaceValue.sansSerif ? .default : .serif)
    }
  }
}

/// Deliver settings changes after native picker menus close, as PrayerLanguageMonitor does.
/// AppStorage alone does not reliably refresh a prayer open in another Mac scene.
@MainActor
final class PrayerTypographyMonitor: ObservableObject {
  static let shared = PrayerTypographyMonitor()
  @Published private(set) var typefaces = PrayerTypography.Typefaces.current
  private var cancellable: AnyCancellable?

  private init() {
    cancellable = NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
      .receive(on: RunLoop.main)
      .map { _ in PrayerTypography.Typefaces.current }
      .removeDuplicates()
      .sink { [weak self] value in self?.typefaces = value }
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
