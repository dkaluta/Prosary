//
//  FontRegistration.swift
//  Prosary
//
//  Registers the bundled prayer/Scripture typefaces at launch via CTFontManager rather than
//  the iOS-only "Fonts provided by application" Info.plist key, since that mechanism doesn't
//  cover macOS in a single shared multiplatform Info.plist.
//

import CoreText
import Foundation

enum FontRegistration {
  /// PostScript names of the bundled fonts, as reported by CoreText — used by
  /// `PrayerTypography` to build `Font.custom` values. Frank Ruhl Libre is a variable font;
  /// only its base ("Regular") instance is registered/used here.
  enum PostScriptName {
    static let cardo = "Cardo-Regular"
    static let frankRuhlLibre = "FrankRuhlLibre-Regular"
    static let shofar = "ShofarRegular"
    static let amiri = "Amiri-Regular"
    static let scheherazadeNew = "ScheherazadeNew-Regular"
    static let davidLibre = "DavidLibre-Regular"
    static let notoSansHebrew = "NotoSansHebrew-Regular"
    static let notoRashiHebrew = "NotoRashiHebrew-Regular"
    static let stamAshkenaz = "StamAshkenazCLM"
    static let stamSefarad = "StamSefaradCLM"
    /// Syriac-script prayer bodies and transliterations. Variable font; its Regular
    /// instance is what registers.
    static let notoSansSyriac = "NotoSansSyriac-Regular"
    static let notoSansSyriacWestern = "NotoSansSyriacWestern-Regular"
    static let notoSansSyriacEastern = "NotoSansSyriacEastern-Regular"
  }

  private static let fileNames = [
    "Cardo-Regular.ttf",
    "FrankRuhlLibre-Variable.ttf",
    "ShofarRegular.ttf",
    "Amiri-Regular.ttf",
    "ScheherazadeNew-Regular.ttf",
    "NotoSansSyriac-Variable.ttf",
    "NotoSansSyriacWestern-Variable.ttf",
    "NotoSansSyriacEastern-Variable.ttf",
    "DavidLibre-Regular.ttf",
    "NotoSansHebrew-Variable.ttf",
    "NotoRashiHebrew-Variable.ttf",
    "StamAshkenazCLM.ttf",
    "StamSefaradCLM.ttf",
  ]

  private static var didRegister = false

  static func registerBundledFontsIfNeeded() {
    guard !didRegister else { return }
    didRegister = true

    for fileName in fileNames {
      guard let url = Bundle.main.url(forResource: fileName, withExtension: nil) else {
        continue
      }

      var error: Unmanaged<CFError>?
      CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
    }
  }
}
