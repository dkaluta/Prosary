package com.dkaluta.prosary.models

/** Discriminant for the type of a saved prayer session. Only the Rosary (deeply configurable,
 * options/calendar-driven) and the Jesus Prayer (a repetition counter with no steps) warrant
 * their own cases; every other devotion is [Custom]. */
enum class PrayerKind {
    Rosary,
    JesusPrayer,

    /** Any devotion whose entire step sequence comes from a bundle's `devotion.json` instead of
     * a hardcoded engine builder — see
     * [com.dkaluta.prosary.engine.PrayerEngine.buildCustomDevotionSteps] and
     * [Prayer.customDevotionId]. One case covers every such devotion (Angelus, Stations of the
     * Cross, Franciscan Crown, Seven Sorrows, Divine Mercy Chaplet, Trisagion, ...); adding
     * another doesn't need a new [PrayerKind] case, only a new bundle. [displayName]/
     * [defaultName] below return a generic fallback for this case — real call sites (Home,
     * Favorites) read the actual devotion's name/icon from
     * [com.dkaluta.prosary.content.prayerpack.PrayerPackStore.info] instead, since a single
     * [PrayerKind] value can't carry per-bundle data. */
    Custom;

    val displayName: String
        get() = when (this) {
            Rosary -> "Rosary"
            JesusPrayer -> "Jesus Prayer"
            Custom -> "Devotion"
        }

    /** Default name suggested when the user creates a new favorite of this kind. */
    val defaultName: String
        get() = when (this) {
            Rosary -> "My Rosary"
            JesusPrayer -> "Jesus Prayer"
            Custom -> "Devotion"
        }
}
