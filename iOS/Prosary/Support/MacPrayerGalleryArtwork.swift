#if os(macOS)
import Foundation

/// Gallery covers are intentionally distinct from the illustrations used during a prayer.
/// Each image remains inside its devotion pack, using the existing asynchronous image cache.
@MainActor
enum MacPrayerGalleryArtwork {
  static let curatedImageKeys: [String: String] = [
    "angelus": "gallery_angelus",
    "divineMercyChaplet": "gallery_divineMercyChaplet",
    "franciscanCrown": "gallery_franciscanCrown",
    "jesusPrayer": "gallery_jesusPrayer",
    "litanyOfLoreto": "gallery_litanyOfLoreto",
    "sevenSorrows": "gallery_sevenSorrows",
    "stationsOfTheCross": "gallery_stationsOfTheCross",
    "rosary": "gallery_rosary",
    "oAntiphons": "gallery_oAntiphons",
    "trisagion": "gallery_trisagion",
    "viaLucis": "gallery_viaLucis",
  ]

  static func resource(for devotionID: String) -> PrayerPackImageResource? {
    PrayerPackStore.galleryImageResource(for: devotionID)
      ?? imageKey(for: devotionID).flatMap { PrayerPackStore.imageResource(for: $0) }
  }

  static func imageKey(for devotionID: String) -> String? {
    if PrayerPackStore.galleryImageResource(for: devotionID) != nil {
      return PrayerPackStore.info(for: devotionID)?.galleryImageKey
    }
    if let curated = curatedImageKeys[devotionID], PrayerPackStore.imageResource(for: curated) != nil {
      return curated
    }
    guard let definition = PrayerPackStore.definition(for: devotionID) else { return nil }

    // An imported pack can carry an illustration in any declared form/day. Missing image
    // entries are skipped; a pack without artwork keeps its genuine symbol or glyph.
    var candidates = decadeImageKeys(definition.decades)
    var steps = (definition.steps ?? []) + (definition.opening ?? []) + (definition.closing ?? [])
    for variant in definition.variants ?? [] {
      candidates.append(contentsOf: decadeImageKeys(variant.decades))
      steps.append(contentsOf: (variant.steps ?? []) + (variant.opening ?? []) + (variant.closing ?? []))
      steps.append(contentsOf: variant.eastertideSteps ?? [])
    }
    steps.append(contentsOf: definition.eastertideSteps ?? [])
    for day in definition.days ?? [] { steps.append(contentsOf: day.steps) }
    candidates.append(contentsOf: steps.compactMap(\.imageKey))
    return candidates.first {
      $0 != PrayerArtwork.fallbackAssetName && PrayerPackStore.imageResource(for: $0) != nil
    }
  }

  private static func decadeImageKeys(_ decades: CustomDevotionDefinition.Decades?) -> [String] {
    guard let decades else { return [] }
    return [decades.fixedImageKey].compactMap { $0 }
      + (decades.entries ?? []).map(\.imageKey)
      + [decades.majorStep.imageKey, decades.minorStep.imageKey].compactMap { $0 }
      + ((decades.preAnnouncement ?? []) + (decades.postMinor ?? [])).compactMap(\.imageKey)
  }
}
#endif
