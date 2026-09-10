package com.dkaluta.prosary.ui

import com.dkaluta.prosary.ui.shared.PrayerFlowChromeState
import org.junit.Assert.assertEquals
import org.junit.Test

class PrayerCountdownTest {
    @Test fun recreationKeepsTheRemainingIntervalButManualNavigationStartsANewOne() {
        val state = PrayerFlowChromeState()
        assertEquals(5000L, state.remainingDelay("step:3", 5000, 1000))
        assertEquals(1800L, state.remainingDelay("step:3", 5000, 4200))
        assertEquals(0L, state.remainingDelay("step:3", 5000, 6500))
        assertEquals(5000L, state.remainingDelay("step:4", 5000, 6500))
        state.cancelCountdown()
        assertEquals(5000L, state.remainingDelay("step:4", 5000, 7000))
    }
}
