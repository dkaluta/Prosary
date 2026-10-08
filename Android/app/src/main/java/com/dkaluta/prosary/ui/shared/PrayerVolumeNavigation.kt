package com.dkaluta.prosary.ui.shared

import android.view.KeyEvent

/** The visible reader supplies the same actions as its Back and Next / Count / Finish buttons. */
internal data class PrayerVolumeNavigationTarget(
    val readerActive: () -> Boolean,
    val audioActive: () -> Boolean,
    val canGoBack: () -> Boolean,
    val onBack: () -> Unit,
    val onNext: () -> Unit,
)

internal enum class PrayerVolumeAction { Ignore, Consume, Previous, Next }

/** Own the whole physical press, including release after Next has finished a prayer. */
internal class PrayerVolumeNavigation {
    private val capturedPresses = mutableMapOf<Int, Long>()

    fun action(
        keyCode: Int,
        keyAction: Int,
        repeatCount: Int,
        downTime: Long,
        enabled: Boolean,
        readerActive: Boolean,
        audioActive: Boolean,
        canGoBack: Boolean,
        hasModifiers: Boolean = false,
        canceled: Boolean = false,
    ): PrayerVolumeAction {
        if (keyCode != KeyEvent.KEYCODE_VOLUME_UP && keyCode != KeyEvent.KEYCODE_VOLUME_DOWN) {
            return PrayerVolumeAction.Ignore
        }
        if (capturedPresses[keyCode] == downTime) {
            if (keyAction == KeyEvent.ACTION_UP) capturedPresses.remove(keyCode)
            return PrayerVolumeAction.Consume
        }
        // A press begun for volume stays with Android even if playback stops mid-press.
        if (keyAction != KeyEvent.ACTION_DOWN || repeatCount != 0 || canceled || hasModifiers ||
            !enabled || !readerActive || audioActive) {
            return PrayerVolumeAction.Ignore
        }
        capturedPresses[keyCode] = downTime
        return if (keyCode == KeyEvent.KEYCODE_VOLUME_UP) PrayerVolumeAction.Next
            else if (canGoBack) PrayerVolumeAction.Previous else PrayerVolumeAction.Consume
    }
}
