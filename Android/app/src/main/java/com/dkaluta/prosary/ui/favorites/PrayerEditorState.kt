package com.dkaluta.prosary.ui.favorites

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import com.dkaluta.prosary.models.Prayer

/** The draft belongs to the editor's navigation entry, so a fold or rotation cannot replace
 * unsaved changes with another store read. Leaving that entry discards the draft as before.
 * Keep the original reminders too: Save needs their IDs to cancel removed alarms. */
internal class PrayerEditorState : ViewModel() {
    var prayer by mutableStateOf<Prayer?>(null)
    var originalPrayer: Prayer? = null
        private set
    var initialized = false
        private set

    fun initialize(original: Prayer?, draft: Prayer? = original) {
        if (initialized) return
        originalPrayer = original
        prayer = draft
        initialized = true
    }
}
