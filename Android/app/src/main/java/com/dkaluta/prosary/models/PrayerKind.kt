package com.dkaluta.prosary.models

/** Discriminant for the type of a saved prayer session.
 * Add new cases here (and a matching options class) to expand into new devotions. */
enum class PrayerKind {
    Rosary,
    Angelus,
    JesusPrayer,
    StationsOfTheCross,
    FranciscanCrown,
    SevenSorrows,
    DivineMercyChaplet,

    /** Any devotion whose entire step sequence comes from a bundle's `steps.json` instead of a
     * hardcoded engine builder — see [com.dkaluta.prosary.engine.PrayerEngine.buildCustomDevotionSteps]
     * and [Prayer.customDevotionId]. One case covers every such devotion (currently just
     * Trisagion); adding another doesn't need a new [PrayerKind] case, only a new bundle.
     * [displayName]/[defaultName] below return a generic fallback for this case — real call sites
     * (Home, Favorites) read the actual devotion's name/icon from
     * [com.dkaluta.prosary.content.prayerpack.PrayerPackStore.info] instead, since a single
     * [PrayerKind] value can't carry per-bundle data. */
    Custom;

    val displayName: String
        get() = when (this) {
            Rosary -> "Rosary"
            Angelus -> "Angelus"
            JesusPrayer -> "Jesus Prayer"
            StationsOfTheCross -> "Stations of the Cross"
            FranciscanCrown -> "Franciscan Crown"
            SevenSorrows -> "Seven Sorrows"
            DivineMercyChaplet -> "Divine Mercy Chaplet"
            Custom -> "Devotion"
        }

    /** Default name suggested when the user creates a new favorite of this kind. */
    val defaultName: String
        get() = when (this) {
            Rosary -> "My Rosary"
            Angelus -> "Angelus"
            JesusPrayer -> "Jesus Prayer"
            StationsOfTheCross -> "Stations of the Cross"
            FranciscanCrown -> "Franciscan Crown"
            SevenSorrows -> "Seven Sorrows"
            DivineMercyChaplet -> "Divine Mercy Chaplet"
            Custom -> "Devotion"
        }
}
