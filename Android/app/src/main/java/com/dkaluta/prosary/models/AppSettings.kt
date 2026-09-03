package com.dkaluta.prosary.models

import android.content.Context
import android.content.SharedPreferences

/**
 * App-wide preferences that aren't tied to any single [Prayer] — the default prayer language
 * (resolved whenever a Prayer's own languageCode is [LanguageCatalog.defaultSentinel]) and the
 * prayer flows' auto-advance interval.
 *
 * [LanguageCatalog.resolve] is called from many non-Composable sites (engines, stores) that have
 * no [Context] of their own, so this holds the resolved value in a plain `var` initialized once
 * from SharedPreferences at app start (see MainActivity) rather than requiring every call site to
 * carry a Context.
 */
object AppSettings {
    private const val PREFS_NAME = "prosary_settings"
    private const val KEY_DEFAULT_LANGUAGE = "defaultLanguageCode"
    private const val KEY_ARAMAIC_SIGN_OF_CROSS_FORM = "aramaicSignOfCrossForm"
    private const val KEY_AUTO_ADVANCE = "autoAdvanceSeconds"
    private const val KEY_HAPTICS = "hapticsOnAdvance"
    private const val KEY_FEAST_CALENDAR = "feastCalendarId"
    private const val KEY_SHOW_TODAY_FEAST = "showTodayFeast"
    private const val KEY_SHOW_TODAY_INTENTION = "showTodayIntention"
    private const val KEY_SYRIAC_TYPEFACE = "syriacTypeface"
    private const val KEY_HEBREW_PRAYER_TYPEFACE = "hebrewPrayerTypeface"
    private const val KEY_HEBREW_SCRIPTURE_TYPEFACE = "hebrewScriptureTypeface"
    private const val KEY_FAVORITE_BASIC_PRAYERS = "favoriteBasicPrayerIds"
    private const val KEY_FAVORITE_BASIC_PRAYERS_FIRST = "favoriteBasicPrayersFirst"
    private const val KEY_LANGUAGE_FALLBACK_ORDER = "languageFallbackOrder"

    var defaultLanguageCode: String = LanguageCatalog.defaultCode
        private set

    const val ARAMAIC_SIGN_OF_CROSS_FORM_A = "formA"
    const val ARAMAIC_SIGN_OF_CROSS_FORM_B = "formB"

    const val TYPEFACE_DEFAULT = "default"
    const val TYPEFACE_WESTERN = "western"
    const val TYPEFACE_EASTERN = "eastern"
    const val TYPEFACE_DAVID_LIBRE = "davidLibre"
    const val TYPEFACE_SANS_SERIF = "sansSerif"
    const val TYPEFACE_STAM_ASHKENAZ = "stamAshkenaz"
    const val TYPEFACE_STAM_SEFARAD = "stamSefarad"
    const val TYPEFACE_RASHI = "rashi"

    /** Which of Erez's two sourced Aramaic Sign of the Cross forms is used app-wide. */
    var aramaicSignOfCrossForm: String = ARAMAIC_SIGN_OF_CROSS_FORM_A
        private set

    var syriacTypeface: String = TYPEFACE_DEFAULT
        private set
    var hebrewPrayerTypeface: String = TYPEFACE_DEFAULT
        private set
    var hebrewScriptureTypeface: String = TYPEFACE_DEFAULT
        private set
    var favoriteBasicPrayerIds: Set<String> = emptySet()
        private set
    var favoriteBasicPrayersFirst: Boolean = false
        private set
    var languageFallbackOrder: List<String> = emptyList()
        private set

    /** True only when the app-wide form should govern Aramaic prayer text. */
    val usesSystemWideAramaicSignOfCrossForm: Boolean
        get() = (LanguageCatalog.baseLanguage(defaultLanguageCode) ?: defaultLanguageCode) == "arc"

    /** The Home "Today" feast row's liturgical calendar, by calendars.json id; "" (the
     * default) follows the registry's own default. Assigning persists; with no [init] yet
     * (plain JVM unit tests) the assignment simply caches. */
    var feastCalendarId: String = ""
        set(value) {
            field = value
            prefs?.edit()?.putString(KEY_FEAST_CALENDAR, value)?.apply()
        }

    /** Whether Home's Today section shows the day's feast row — Erez's request: each Today
     * row can be switched off on its own, so any of both/either/neither can show. */
    var showTodayFeast: Boolean = true
        set(value) {
            field = value
            prefs?.edit()?.putBoolean(KEY_SHOW_TODAY_FEAST, value)?.apply()
        }

    /** Whether Home's Today section shows the Pope's monthly intention row. */
    var showTodayIntention: Boolean = true
        set(value) {
            field = value
            prefs?.edit()?.putBoolean(KEY_SHOW_TODAY_INTENTION, value)?.apply()
        }

    /** Seconds between automatic step advances in the prayer flows; 0 = off. */
    var autoAdvanceSeconds: Int = 0
        private set

    /** A gentle tap when a flow's step changes — tester-requested (Erez), off by default. */
    var hapticsOnAdvance: Boolean = false
        private set

    private var prefs: SharedPreferences? = null

    fun init(context: Context) {
        val resolved = context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs = resolved
        defaultLanguageCode = resolved.getString(KEY_DEFAULT_LANGUAGE, LanguageCatalog.defaultCode)
            ?: LanguageCatalog.defaultCode
        aramaicSignOfCrossForm = resolved
            .getString(KEY_ARAMAIC_SIGN_OF_CROSS_FORM, ARAMAIC_SIGN_OF_CROSS_FORM_A)
            .takeIf { it == ARAMAIC_SIGN_OF_CROSS_FORM_B }
            ?: ARAMAIC_SIGN_OF_CROSS_FORM_A
        autoAdvanceSeconds = resolved.getInt(KEY_AUTO_ADVANCE, 0)
        hapticsOnAdvance = resolved.getBoolean(KEY_HAPTICS, false)
        val storedFeastCalendar = resolved.getString(KEY_FEAST_CALENDAR, "") ?: ""
        feastCalendarId = if (storedFeastCalendar == "roman-he") "roman" else storedFeastCalendar
        showTodayFeast = resolved.getBoolean(KEY_SHOW_TODAY_FEAST, true)
        showTodayIntention = resolved.getBoolean(KEY_SHOW_TODAY_INTENTION, true)
        syriacTypeface = resolved.getString(KEY_SYRIAC_TYPEFACE, TYPEFACE_DEFAULT) ?: TYPEFACE_DEFAULT
        hebrewPrayerTypeface = resolved.getString(KEY_HEBREW_PRAYER_TYPEFACE, TYPEFACE_DEFAULT) ?: TYPEFACE_DEFAULT
        hebrewScriptureTypeface = resolved.getString(KEY_HEBREW_SCRIPTURE_TYPEFACE, TYPEFACE_DEFAULT) ?: TYPEFACE_DEFAULT
        favoriteBasicPrayerIds = resolved.getStringSet(KEY_FAVORITE_BASIC_PRAYERS, emptySet()).orEmpty()
        favoriteBasicPrayersFirst = resolved.getBoolean(KEY_FAVORITE_BASIC_PRAYERS_FIRST, false)
        languageFallbackOrder = resolved.getString(KEY_LANGUAGE_FALLBACK_ORDER, "")
            .orEmpty().split('\n').filter { it.isNotEmpty() }
    }

    fun setDefaultLanguageCode(code: String) {
        defaultLanguageCode = code
        prefs?.edit()?.putString(KEY_DEFAULT_LANGUAGE, code)?.apply()
    }

    fun setAramaicSignOfCrossForm(form: String) {
        aramaicSignOfCrossForm = if (form == ARAMAIC_SIGN_OF_CROSS_FORM_B) {
            ARAMAIC_SIGN_OF_CROSS_FORM_B
        } else {
            ARAMAIC_SIGN_OF_CROSS_FORM_A
        }
        prefs?.edit()?.putString(KEY_ARAMAIC_SIGN_OF_CROSS_FORM, aramaicSignOfCrossForm)?.apply()
    }

    fun setSyriacTypeface(value: String) {
        syriacTypeface = value
        prefs?.edit()?.putString(KEY_SYRIAC_TYPEFACE, value)?.apply()
    }

    fun setHebrewPrayerTypeface(value: String) {
        hebrewPrayerTypeface = value
        prefs?.edit()?.putString(KEY_HEBREW_PRAYER_TYPEFACE, value)?.apply()
    }

    fun setHebrewScriptureTypeface(value: String) {
        hebrewScriptureTypeface = value
        prefs?.edit()?.putString(KEY_HEBREW_SCRIPTURE_TYPEFACE, value)?.apply()
    }

    fun toggleFavoriteBasicPrayer(id: String) {
        favoriteBasicPrayerIds = favoriteBasicPrayerIds.toMutableSet().also {
            if (!it.add(id)) it.remove(id)
        }
        prefs?.edit()?.putStringSet(KEY_FAVORITE_BASIC_PRAYERS, favoriteBasicPrayerIds)?.apply()
    }

    fun setFavoriteBasicPrayersFirst(value: Boolean) {
        favoriteBasicPrayersFirst = value
        prefs?.edit()?.putBoolean(KEY_FAVORITE_BASIC_PRAYERS_FIRST, value)?.apply()
    }

    fun setLanguageFallbackOrder(value: List<String>) {
        languageFallbackOrder = value
        prefs?.edit()?.putString(KEY_LANGUAGE_FALLBACK_ORDER, value.joinToString("\n"))?.apply()
    }

    fun setAutoAdvanceSeconds(seconds: Int) {
        autoAdvanceSeconds = seconds
        prefs?.edit()?.putInt(KEY_AUTO_ADVANCE, seconds)?.apply()
    }

    fun setHapticsOnAdvance(enabled: Boolean) {
        hapticsOnAdvance = enabled
        prefs?.edit()?.putBoolean(KEY_HAPTICS, enabled)?.apply()
    }
}
