package com.dkaluta.prosary.models

import androidx.annotation.StringRes
import com.dkaluta.prosary.R

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

    @get:StringRes
    val displayNameRes: Int
        get() = when (this) {
            Rosary -> R.string.kind_rosary
            JesusPrayer -> R.string.kind_jesus_prayer
            Custom -> R.string.kind_devotion
        }

    /** The built-in kinds' names in each prayer language — the same map a bundle carries in
     * its manifest's displayNameByLanguage, kept here because the Rosary and the Jesus Prayer
     * have no manifest to carry it. Resolution mirrors localizedDisplayName exactly: the
     * prayer language (exact code, rites included, then its base), then the UI string. */
    private val namesByPrayerLanguage: Map<String, String>
        get() = when (this) {
            Rosary -> mapOf("he" to "מחרוזת")
            JesusPrayer -> mapOf("he" to "תפילת ישוע")
            Custom -> emptyMap()
        }

    fun displayName(context: android.content.Context): String = context.getString(displayNameRes)

    fun cardTitle(context: android.content.Context, prayerLanguage: String = LanguageCatalog.resolve(null).code): PrayerCardTitle {
        val prayerCode = LanguageCatalog.uiLanguageCode(prayerLanguage)
        val base = LanguageCatalog.baseLanguage(prayerCode) ?: prayerCode
        val prayerName = if (this == Rosary) {
            com.dkaluta.prosary.content.prayerpack.PrayerPackStore.info("rosary")?.displayNameIn(prayerCode)
        } else null
        val translatedContext = com.dkaluta.prosary.content.today.TodayTranslationLanguage.localizedContext(context, base)
        return PrayerCardTitle.resolve(
            displayName(context),
            prayerName ?: namesByPrayerLanguage[prayerCode] ?: namesByPrayerLanguage[base]
                ?: translatedContext.getString(displayNameRes),
        )
    }

    /** Default name suggested when the user creates a new favorite of this kind. */
    @get:StringRes
    val defaultNameRes: Int
        get() = when (this) {
            Rosary -> R.string.kind_default_name_rosary
            JesusPrayer -> R.string.kind_jesus_prayer
            Custom -> R.string.kind_devotion
        }
}
