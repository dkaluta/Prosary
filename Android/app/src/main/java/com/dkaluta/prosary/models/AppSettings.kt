package com.dkaluta.prosary.models

import android.content.Context
import android.content.SharedPreferences
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

/**
 * App-wide preferences that aren't tied to any single [Prayer] — the default prayer language
 * (resolved whenever a Prayer's own languageCode is [LanguageCatalog.defaultSentinel]) and the
 * prayer flows' auto-advance interval.
 *
 * [LanguageCatalog.resolve] is called from many non-Composable sites (engines, stores) that have
 * no [Context] of their own, so this keeps values initialized from SharedPreferences at app
 * start (see MainActivity). Language values also expose Compose state so an open prayer and
 * its list update immediately after a picker change.
 */
object AppSettings {
    private const val PREFS_NAME = "prosary_settings"
    private const val KEY_DEFAULT_LANGUAGE = "defaultLanguageCode"
    private const val KEY_BASIC_PRAYERS_LANGUAGE = "basicPrayersLanguageCode"
    private const val KEY_ARAMAIC_SIGN_OF_CROSS_FORM = "aramaicSignOfCrossForm"
    private const val KEY_AUTO_ADVANCE = "autoAdvanceSeconds"
    private const val KEY_HAPTICS = "hapticsOnAdvance"
    private const val KEY_FEAST_CALENDAR = "feastCalendarId"
    private const val KEY_SHOW_TODAY_FEAST = "showTodayFeast"
    private const val KEY_SHOW_TODAY_INTENTION = "showTodayIntention"
    private const val KEY_SHOW_TODAY_TORAH = "showTodayTorahPortion"
    private const val KEY_PRAYER_NAME_LANGUAGE = "showPrayerNameInPrayerLanguage"
    private const val KEY_EASTERN_PASCHA_STYLE = "easternPaschaStyle"
    private const val KEY_TODAY_LANGUAGE = "todayLanguageCode"
    private const val KEY_SYRIAC_TYPEFACE = "syriacTypeface"
    private const val KEY_ARAMAIC_DEFAULT_SCRIPT = "aramaicDefaultScript"
    private const val KEY_HEBREW_PRAYER_TYPEFACE = "hebrewPrayerTypeface"
    private const val KEY_HEBREW_SCRIPTURE_TYPEFACE = "hebrewScriptureTypeface"
    private const val KEY_HEBREW_SANS_MIGRATED = "hebrewSansTypefaceMigrated"
    private const val KEY_LATIN_PRAYER_TYPEFACE = "latinPrayerTypeface"
    private const val KEY_CYRILLIC_PRAYER_TYPEFACE = "cyrillicPrayerTypeface"
    private const val KEY_FAVORITE_BASIC_PRAYERS = "favoriteBasicPrayerIds"
    private const val KEY_FAVORITE_BASIC_PRAYERS_FIRST = "favoriteBasicPrayersFirst"
    private const val KEY_LANGUAGE_FALLBACK_ORDER = "languageFallbackOrder"

    private var defaultLanguageState by mutableStateOf(LanguageCatalog.defaultCode)
    val defaultLanguageCode: String get() = defaultLanguageState

    private var basicPrayersLanguageState by mutableStateOf(LanguageCatalog.defaultSentinel)
    val basicPrayersLanguageCode: String get() = basicPrayersLanguageState

    /** Legacy override retained for storage compatibility; Today now ignores it. */
    private var todayLanguageState by mutableStateOf("")
    val todayLanguageCode: String get() = todayLanguageState

    const val ARAMAIC_SIGN_OF_CROSS_FORM_A = "formA"
    const val ARAMAIC_SIGN_OF_CROSS_FORM_B = "formB"

    const val TYPEFACE_DEFAULT = "default"
    const val TYPEFACE_WESTERN = "western"
    const val TYPEFACE_EASTERN = "eastern"
    const val TYPEFACE_DAVID_LIBRE = "davidLibre"
    const val TYPEFACE_SANS_SERIF = "sansSerif"
    const val TYPEFACE_BUNDLED_SANS_SERIF = "bundledSansSerif"
    const val TYPEFACE_STAM_ASHKENAZ = "stamAshkenaz"
    const val TYPEFACE_STAM_SEFARAD = "stamSefarad"
    const val TYPEFACE_RASHI = "rashi"

    /** Which of Erez's two sourced Aramaic Sign of the Cross forms is used app-wide. */
    var aramaicSignOfCrossForm: String = ARAMAIC_SIGN_OF_CROSS_FORM_A
        private set

    private var syriacTypefaceState by mutableStateOf(TYPEFACE_DEFAULT)
    private var aramaicDefaultScriptState by mutableStateOf("Hebr")
    val aramaicDefaultScript: String get() = aramaicDefaultScriptState
    val syriacTypeface: String get() = syriacTypefaceState
    private var hebrewPrayerTypefaceState by mutableStateOf(TYPEFACE_DEFAULT)
    val hebrewPrayerTypeface: String get() = hebrewPrayerTypefaceState
    private var hebrewScriptureTypefaceState by mutableStateOf(TYPEFACE_DEFAULT)
    val hebrewScriptureTypeface: String get() = hebrewScriptureTypefaceState
    private var latinPrayerTypefaceState by mutableStateOf(TYPEFACE_DEFAULT)
    val latinPrayerTypeface: String get() = latinPrayerTypefaceState
    private var cyrillicPrayerTypefaceState by mutableStateOf(TYPEFACE_DEFAULT)
    val cyrillicPrayerTypeface: String get() = cyrillicPrayerTypefaceState
    private var pinnedBasicPrayerIdsState by mutableStateOf<Set<String>>(emptySet())
    /** Historical favorites are now Home pins; retain the persisted key and selections. */
    val favoriteBasicPrayerIds: Set<String> get() = pinnedBasicPrayerIdsState
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

    private var showTodayTorahState by mutableStateOf(false)
    var showTodayTorahPortion: Boolean
        get() = showTodayTorahState
        set(value) {
            showTodayTorahState = value
            prefs?.edit()?.putBoolean(KEY_SHOW_TODAY_TORAH, value)?.apply()
        }

    private var prayerNameLanguageState by mutableStateOf(false)
    var showPrayerNameInPrayerLanguage: Boolean
        get() = prayerNameLanguageState
        set(value) {
            prayerNameLanguageState = value
            prefs?.edit()?.putBoolean(KEY_PRAYER_NAME_LANGUAGE, value)?.apply()
        }

    private var easternPaschaStyleState by mutableStateOf("julian")
    var easternPaschaStyle: String
        get() = easternPaschaStyleState
        set(value) {
            easternPaschaStyleState = normalizedEasternPaschaStyle(value)
            prefs?.edit()?.putString(KEY_EASTERN_PASCHA_STYLE, easternPaschaStyleState)?.apply()
        }

    internal fun normalizedEasternPaschaStyle(value: String): String =
        if (value == "gregorian") "gregorian" else "julian"

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
        defaultLanguageState = resolved.getString(KEY_DEFAULT_LANGUAGE, LanguageCatalog.defaultCode)
            ?: LanguageCatalog.defaultCode
        basicPrayersLanguageState = resolved.getString(KEY_BASIC_PRAYERS_LANGUAGE, LanguageCatalog.defaultSentinel)
            ?: LanguageCatalog.defaultSentinel
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
        showTodayTorahPortion = resolved.getBoolean(KEY_SHOW_TODAY_TORAH, false)
        showPrayerNameInPrayerLanguage = resolved.getBoolean(KEY_PRAYER_NAME_LANGUAGE, false)
        easternPaschaStyle = resolved.getString(KEY_EASTERN_PASCHA_STYLE, "julian") ?: "julian"
        todayLanguageState = resolved.getString(KEY_TODAY_LANGUAGE, "").orEmpty()
        syriacTypefaceState = resolved.getString(KEY_SYRIAC_TYPEFACE, TYPEFACE_DEFAULT) ?: TYPEFACE_DEFAULT
        aramaicDefaultScriptState = if (resolved.getString(KEY_ARAMAIC_DEFAULT_SCRIPT, "Hebr") == "Syrc") "Syrc" else "Hebr"
        hebrewPrayerTypefaceState = resolved.getString(KEY_HEBREW_PRAYER_TYPEFACE, TYPEFACE_DEFAULT) ?: TYPEFACE_DEFAULT
        if (!resolved.getBoolean(KEY_HEBREW_SANS_MIGRATED, false)) {
            // Earlier Android versions named the bundled Roboto/Noto face "sansSerif".
            hebrewPrayerTypefaceState = migratedHebrewTypeface(hebrewPrayerTypefaceState)
            resolved.edit().putString(KEY_HEBREW_PRAYER_TYPEFACE, hebrewPrayerTypefaceState)
                .putBoolean(KEY_HEBREW_SANS_MIGRATED, true).apply()
        }
        hebrewScriptureTypefaceState = resolved.getString(KEY_HEBREW_SCRIPTURE_TYPEFACE, TYPEFACE_DEFAULT) ?: TYPEFACE_DEFAULT
        cyrillicPrayerTypefaceState = resolved.getString(KEY_CYRILLIC_PRAYER_TYPEFACE, TYPEFACE_DEFAULT) ?: TYPEFACE_DEFAULT
        latinPrayerTypefaceState = resolved.getString(KEY_LATIN_PRAYER_TYPEFACE, TYPEFACE_DEFAULT) ?: TYPEFACE_DEFAULT
        pinnedBasicPrayerIdsState = resolved.getStringSet(KEY_FAVORITE_BASIC_PRAYERS, emptySet()).orEmpty()
        favoriteBasicPrayersFirst = resolved.getBoolean(KEY_FAVORITE_BASIC_PRAYERS_FIRST, false)
        languageFallbackOrder = resolved.getString(KEY_LANGUAGE_FALLBACK_ORDER, "")
            .orEmpty().split('\n').filter { it.isNotEmpty() }
    }

    fun setDefaultLanguageCode(code: String) {
        defaultLanguageState = code
        prefs?.edit()?.putString(KEY_DEFAULT_LANGUAGE, code)?.apply()
    }

    fun setBasicPrayersLanguageCode(code: String) {
        basicPrayersLanguageState = code
        prefs?.edit()?.putString(KEY_BASIC_PRAYERS_LANGUAGE, code)?.apply()
    }

    fun setTodayLanguageCode(code: String) {
        todayLanguageState = code
        prefs?.edit()?.putString(KEY_TODAY_LANGUAGE, code)?.apply()
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
        syriacTypefaceState = value
        prefs?.edit()?.putString(KEY_SYRIAC_TYPEFACE, value)?.apply()
    }

    fun setAramaicDefaultScript(value: String) {
        aramaicDefaultScriptState = if (value == "Syrc") "Syrc" else "Hebr"
        prefs?.edit()?.putString(KEY_ARAMAIC_DEFAULT_SCRIPT, aramaicDefaultScriptState)?.apply()
    }

    internal fun migratedHebrewTypeface(stored: String): String =
        if (stored == TYPEFACE_SANS_SERIF) TYPEFACE_BUNDLED_SANS_SERIF else stored

    fun setHebrewPrayerTypeface(value: String) {
        hebrewPrayerTypefaceState = value
        prefs?.edit()?.putString(KEY_HEBREW_PRAYER_TYPEFACE, value)?.apply()
    }

    fun setLatinPrayerTypeface(value: String) {
        latinPrayerTypefaceState = value
        prefs?.edit()?.putString(KEY_LATIN_PRAYER_TYPEFACE, value)?.apply()
    }

    fun setCyrillicPrayerTypeface(value: String) {
        cyrillicPrayerTypefaceState = value
        prefs?.edit()?.putString(KEY_CYRILLIC_PRAYER_TYPEFACE, value)?.apply()
    }

    fun setHebrewScriptureTypeface(value: String) {
        hebrewScriptureTypefaceState = value
        prefs?.edit()?.putString(KEY_HEBREW_SCRIPTURE_TYPEFACE, value)?.apply()
    }

    fun toggleFavoriteBasicPrayer(id: String) {
        pinnedBasicPrayerIdsState = favoriteBasicPrayerIds.toMutableSet().also {
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
