package com.dkaluta.prosary.ui.shared

import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.graphics.Color
import androidx.lifecycle.ViewModel
import com.dkaluta.prosary.content.audio.AudioPlaybackController
import com.dkaluta.prosary.models.DevotionEntryContext
import com.dkaluta.prosary.models.JesusPrayerProgress
import com.dkaluta.prosary.models.JesusPrayerTarget
import com.dkaluta.prosary.models.LanguageCatalog
import com.dkaluta.prosary.models.Prayer
import com.dkaluta.prosary.models.PrayerRunProgress
import com.dkaluta.prosary.models.RosaryStep

/** These models belong to a navigation entry, not its current Activity or measured layout.
 * A recreated screen keeps its live run; only a newly opened entry consults the bookmark. */
internal class RosaryPrayerSession(prayer: Prayer) : ViewModel() {
    val steps = mutableStateOf<List<RosaryStep>>(emptyList())
    val currentIndex = mutableIntStateOf(0)
    val seasonColor = mutableStateOf(Color.Transparent)
    val chosenLanguage = mutableStateOf(prayer.languageCode)
    val languageCode = mutableStateOf(prayer.resolvedLanguageCode)
    val languageMenuExpanded = mutableStateOf(false)
    val pendingResume = mutableStateOf<PrayerRunProgress?>(null)
    val runReady = mutableStateOf(false)
    val showsLitanyOffer = mutableStateOf(false)
    var loadedSignature: String? = null
    var appliedJaffaWording: Boolean? = null
}

internal class JesusPrayerSession(prayer: Prayer?, target: JesusPrayerTarget) : ViewModel() {
    val progress = mutableStateOf(JesusPrayerProgress(target = target))
    val isRightToLeft = mutableStateOf(false)
    val seasonColor = mutableStateOf(Color.Transparent)
    val languageCode = mutableStateOf<String?>(null)
    val hasLoaded = mutableStateOf(false)
    val matchingFavoriteId = mutableStateOf<String?>(null)
    val isPinned = mutableStateOf(false)
    val chosenLanguage = mutableStateOf(prayer?.languageCode ?: LanguageCatalog.defaultSentinel)
    val pendingResume = mutableStateOf<PrayerRunProgress?>(null)
    val runReady = mutableStateOf(false)
}

internal class CustomDevotionPrayerSession(
    devotionId: String,
    prayer: Prayer?,
    initialVariantId: String?,
    initialLanguageCode: String?,
) : ViewModel() {
    val steps = mutableStateOf<List<RosaryStep>>(emptyList())
    val currentIndex = mutableIntStateOf(0)
    val isRightToLeft = mutableStateOf(false)
    val seasonColor = mutableStateOf(Color.Transparent)
    val languageCode = mutableStateOf<String?>(null)
    val matchingFavoriteId = mutableStateOf(prayer?.id)
    val displayName = mutableStateOf(devotionId)
    val variantId = mutableStateOf(DevotionEntryContext.initialVariant(devotionId, initialVariantId, prayer?.variantId))
    val variantMenuExpanded = mutableStateOf(false)
    val chosenLanguage = mutableStateOf(initialLanguageCode ?: prayer?.languageCode ?: LanguageCatalog.defaultSentinel)
    val customOptions = mutableStateOf(prayer?.customOptions.orEmpty())
    val languageMenuExpanded = mutableStateOf(false)
    val dayIndex = mutableIntStateOf(prayer?.dayIndex ?: 0)
    val dayMenuExpanded = mutableStateOf(false)
    val missedDayChoice = mutableStateOf<Pair<Int, Int>?>(null)
    val isPinned = mutableStateOf(false)
    val completionSuggestion = mutableStateOf<Pair<String, String>?>(null)
    val pendingResume = mutableStateOf<PrayerRunProgress?>(null)
    val checkedRunKey = mutableStateOf<String?>(null)
    val runReady = mutableStateOf(false)
    val resetAudioOnNextRebuild = mutableStateOf(false)

    var entryLoaded = false
    var loadedSelection: Pair<String?, Int>? = null
    var appliedJaffaWording: Boolean? = null
    val audio = AudioPlaybackController()
    var observedAudioChapter: Pair<String?, Int?>? = null

    override fun onCleared() {
        // The player survives Activity replacement, but never outlives this navigation entry.
        audio.stop()
    }
}
