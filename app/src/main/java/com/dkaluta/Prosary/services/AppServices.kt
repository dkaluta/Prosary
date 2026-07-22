package com.dkaluta.Prosary.services

import androidx.compose.runtime.staticCompositionLocalOf
import com.dkaluta.Prosary.calendar.LiturgicalCalendarProviding
import com.dkaluta.Prosary.calendar.MockLiturgicalCalendar
import com.dkaluta.Prosary.engine.MockRosaryEngine
import com.dkaluta.Prosary.engine.RosaryEngine
import com.dkaluta.Prosary.presets.MockPresetStore
import com.dkaluta.Prosary.presets.PresetStore

/** The backend, as the UI sees it — three interfaces, provided once at the app root and read via
 * [LocalAppServices] everywhere else. Currently wired to the Mock* implementations so the app is
 * fully interactive today; swap these for real implementations once they're ready — everything
 * downstream only ever talks to the interfaces. */
data class AppServices(
    val presetStore: PresetStore,
    val rosaryEngine: RosaryEngine,
    val calendar: LiturgicalCalendarProviding,
) {
    companion object {
        val shared = AppServices(
            presetStore = MockPresetStore(),
            rosaryEngine = MockRosaryEngine(),
            calendar = MockLiturgicalCalendar(),
        )
    }
}

val LocalAppServices = staticCompositionLocalOf { AppServices.shared }
