package com.dkaluta.prosary.models

import java.util.UUID

/** A saved, user-configurable prayer session (a "Favorite"). [kind] selects the prayer type;
 * kind-specific settings live in nested option classes. Add new [PrayerKind] cases and matching
 * option classes here to expand into new devotions (Divine Mercy Chaplet, Seven Sorrows, etc.). */
data class Prayer(
    val id: String = UUID.randomUUID().toString(),
    var name: String = "My Prayer",
    var kind: PrayerKind = PrayerKind.Rosary,

    /** The starred/primary favorite for its kind — used when the home screen launches this
     * kind of prayer without the user picking one explicitly. At most one per kind at a time. */
    var isDefault: Boolean = false,

    /** Prayer language for this favorite. [LanguageCatalog.defaultSentinel] means follow the
     * app-level default language setting. */
    var languageCode: String = LanguageCatalog.defaultSentinel,

    // Kind-specific options — populate the relevant class when creating a Prayer.
    var rosary: RosaryOptions = RosaryOptions(),
    var jesusPrayer: JesusPrayerOptions = JesusPrayerOptions(),
    // Angelus has no options beyond languageCode.

    /** The bundle id (e.g. "trisagion") whose `steps.json` defines this favorite's step sequence
     * — populated only when [kind] is [PrayerKind.Custom], null otherwise. See
     * [com.dkaluta.prosary.engine.PrayerEngine.buildCustomDevotionSteps]. */
    var customDevotionId: String? = null,

    /** Daily reminders to pray this favorite. Scheduled via
     * [com.dkaluta.prosary.reminders.ReminderScheduler]. */
    var reminders: List<PrayerReminder> = emptyList(),
) {
    val isNotDefault: Boolean get() = !isDefault
    val resolvedLanguageCode: String get() = LanguageCatalog.resolve(languageCode).code
    val languageNativeName: String get() = LanguageCatalog.resolve(languageCode).nativeName

    /** Display string for list rows — shows "Default (Latina)" for the sentinel, plain name otherwise. */
    val languageDisplayName: String
        get() = if (languageCode == LanguageCatalog.defaultSentinel) {
            "Default (${LanguageCatalog.resolve(languageCode).nativeName})"
        } else {
            LanguageCatalog.resolve(languageCode).nativeName
        }
}
