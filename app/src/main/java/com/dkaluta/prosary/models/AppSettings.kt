package com.dkaluta.prosary.models

import android.content.Context
import android.content.SharedPreferences

/**
 * App-wide preferences that aren't tied to any single [Prayer] — currently just the default
 * prayer language, resolved whenever a Prayer's own languageCode is [LanguageCatalog.defaultSentinel].
 *
 * [LanguageCatalog.resolve] is called from many non-Composable sites (engines, stores) that have
 * no [Context] of their own, so this holds the resolved value in a plain `var` initialized once
 * from SharedPreferences at app start (see MainActivity) rather than requiring every call site to
 * carry a Context.
 */
object AppSettings {
    private const val PREFS_NAME = "prosary_settings"
    private const val KEY_DEFAULT_LANGUAGE = "defaultLanguageCode"

    var defaultLanguageCode: String = LanguageCatalog.defaultCode
        private set

    private var prefs: SharedPreferences? = null

    fun init(context: Context) {
        val resolved = context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs = resolved
        defaultLanguageCode = resolved.getString(KEY_DEFAULT_LANGUAGE, LanguageCatalog.defaultCode)
            ?: LanguageCatalog.defaultCode
    }

    fun setDefaultLanguageCode(code: String) {
        defaultLanguageCode = code
        prefs?.edit()?.putString(KEY_DEFAULT_LANGUAGE, code)?.apply()
    }
}
