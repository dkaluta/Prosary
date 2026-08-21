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
    private const val KEY_AUTO_ADVANCE = "autoAdvanceSeconds"
    private const val KEY_HAPTICS = "hapticsOnAdvance"
    private const val KEY_FEAST_CALENDAR = "feastCalendarId"

    var defaultLanguageCode: String = LanguageCatalog.defaultCode
        private set

    /** The Home "Today" feast row's liturgical calendar, by calendars.json id; "" (the
     * default) follows the registry's own default. Assigning persists; with no [init] yet
     * (plain JVM unit tests) the assignment simply caches. */
    var feastCalendarId: String = ""
        set(value) {
            field = value
            prefs?.edit()?.putString(KEY_FEAST_CALENDAR, value)?.apply()
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
        autoAdvanceSeconds = resolved.getInt(KEY_AUTO_ADVANCE, 0)
        hapticsOnAdvance = resolved.getBoolean(KEY_HAPTICS, false)
        feastCalendarId = resolved.getString(KEY_FEAST_CALENDAR, "") ?: ""
    }

    fun setDefaultLanguageCode(code: String) {
        defaultLanguageCode = code
        prefs?.edit()?.putString(KEY_DEFAULT_LANGUAGE, code)?.apply()
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
