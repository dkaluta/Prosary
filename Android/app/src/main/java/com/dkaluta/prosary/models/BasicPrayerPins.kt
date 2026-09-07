package com.dkaluta.prosary.models

import android.content.SharedPreferences
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

/** Pray pins reuse the former favorites key, so existing selections survive the change.
 * The list's manual order is independent; pinning only changes which Pray cards are visible. */
internal class BasicPrayerPins {
    private var preferences: SharedPreferences? = null
    var ids: Set<String> by mutableStateOf(emptySet())
        private set

    fun initialize(preferences: SharedPreferences) {
        this.preferences = preferences
        // SharedPreferences owns its returned set: never expose or mutate that instance.
        ids = preferences.getStringSet("favoriteBasicPrayerIds", emptySet()).orEmpty().toSet()
    }

    fun setPinned(id: String, pinned: Boolean) {
        val updated = if (pinned) ids + id else ids - id
        if (updated == ids) return
        ids = updated
        preferences?.edit()?.putStringSet("favoriteBasicPrayerIds", updated.toSet())?.apply()
    }

    fun toggle(id: String) = setPinned(id, id !in ids)
}
