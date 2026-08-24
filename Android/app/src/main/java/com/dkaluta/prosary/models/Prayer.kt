package com.dkaluta.prosary.models

import android.content.Context
import java.util.UUID

/** A saved, user-configurable prayer session. [kind] selects the Rosary, the Jesus Prayer, or
 * the generic bundle path; adding an ordinary devotion means adding a bundle, not a new case. */
data class Prayer(
    val id: String = UUID.randomUUID().toString(),
    var name: String = "My Prayer",
    var kind: PrayerKind = PrayerKind.Rosary,

    /** The primary configuration for its devotion. At most one per
     * ([kind], [customDevotionId]) at a time. */
    var isDefault: Boolean = false,

    /** Prayer language for this configuration. [LanguageCatalog.defaultSentinel] means follow the
     * app-level default language setting. */
    var languageCode: String = LanguageCatalog.defaultSentinel,

    // Kind-specific options — populate the relevant class when creating a Prayer.
    var rosary: RosaryOptions = RosaryOptions(),
    var jesusPrayer: JesusPrayerOptions = JesusPrayerOptions(),
    /** The bundle id (e.g. "trisagion") whose `devotion.json` defines this configuration's step sequence
     * — populated only when [kind] is [PrayerKind.Custom], null otherwise. See
     * [com.dkaluta.prosary.engine.PrayerEngine.buildCustomDevotionSteps]. */
    var customDevotionId: String? = null,
    /** Which of the bundle's variants (alternate step-sets, e.g. the Stations' traditional vs.
     * scriptural forms) this configuration prays. Null = the bundle's default variant; only
     * meaningful when kind == Custom and the bundle declares variants. */
    var variantId: String? = null,
    /** Multi-day ("days"-type) devotions: the day this configuration opens on, 0-based; advances
     * when a day's session finishes (clamped by the engine). Null = day 1. */
    var dayIndex: Int? = null,

    /** This configuration's choices for the bundle's `options.json` options, keyed by option key —
     * "true"/"false" for toggles, a case id for choices. Only overrides: an absent key means the
     * option's declared default. Only meaningful when [kind] == [PrayerKind.Custom]. */
    var customOptions: Map<String, String> = emptyMap(),

    /** Daily reminders for this configuration. Scheduled via
     * [com.dkaluta.prosary.reminders.ReminderScheduler]. */
    var reminders: List<PrayerReminder> = emptyList(),
) {
    val isNotDefault: Boolean get() = !isDefault
    val resolvedLanguageCode: String get() = LanguageCatalog.resolve(languageCode).code
    val languageNativeName: String get() = LanguageCatalog.resolve(languageCode).nativeName

    /** Display string for list rows — shows "Default (Latina)" for the sentinel, plain name otherwise. */
    fun languageDisplayName(context: Context): String =
        if (languageCode == LanguageCatalog.defaultSentinel) {
            context.getString(
                com.dkaluta.prosary.R.string.language_default_parenthesized,
                LanguageCatalog.resolve(languageCode).nativeName,
            )
        } else {
            LanguageCatalog.resolve(languageCode).nativeName
        }
}
