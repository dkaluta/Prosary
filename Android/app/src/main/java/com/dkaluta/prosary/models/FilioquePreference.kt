package com.dkaluta.prosary.models

import android.content.SharedPreferences
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

/** Absence is deliberate: the first selected rite or resolved Nicene source supplies its
 * default, then later language changes preserve the user's app-wide choice. */
internal class FilioquePreference {
    private var preferences: SharedPreferences? = null
    var choice: Boolean? by mutableStateOf(null)
        private set

    fun initialize(preferences: SharedPreferences) {
        this.preferences = preferences
        choice = if (preferences.contains("includeFilioque")) preferences.getBoolean("includeFilioque", true) else null
    }

    fun set(value: Boolean) {
        choice = value
        preferences?.edit()?.putBoolean("includeFilioque", value)?.apply()
    }

    fun initializeOnce(value: Boolean) {
        if (choice == null) set(value)
    }

    internal fun restoreForTesting(value: Boolean?) {
        choice = value
        if (value == null) preferences?.edit()?.remove("includeFilioque")?.apply() else set(value)
    }
}
