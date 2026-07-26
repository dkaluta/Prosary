package com.dkaluta.prosary.services

import android.content.Context
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.room.Room
import com.dkaluta.prosary.calendar.LiturgicalCalendarProviding
import com.dkaluta.prosary.calendar.MockLiturgicalCalendar
import com.dkaluta.prosary.engine.PrayerEngine
import com.dkaluta.prosary.persistence.AppDatabase
import com.dkaluta.prosary.persistence.RoomPresetStore
import com.dkaluta.prosary.presets.MockPresetStore
import com.dkaluta.prosary.presets.PresetStore
import kotlinx.coroutines.runBlocking

/** The backend, as the UI sees it — provided once at the app root and read via
 * [LocalAppServices] everywhere else. [engine] is the single PrayerEngine used for every
 * devotion (see [com.dkaluta.prosary.engine.PrayerEngine]); [presetStore]/[calendar] are still
 * interface-typed since they have real alternate implementations (Room vs. in-memory, real
 * calendar vs. fixed). [create] wires the production implementations. */
data class AppServices(
    val presetStore: PresetStore,
    val engine: PrayerEngine,
    val calendar: LiturgicalCalendarProviding,
) {
    companion object {
        /** In-memory fallback for `@Preview` call sites, which have no Activity [Context] to
         * build a Room database from. */
        val preview = AppServices(
            presetStore = MockPresetStore(),
            engine = PrayerEngine(),
            calendar = MockLiturgicalCalendar(),
        )

        /** Built once in `MainActivity.onCreate`. Seeds the database synchronously (a single
         * cheap insert-if-empty check) so the very first Compose frame never races an empty
         * Favorites list against the seed insert. */
        fun create(context: Context): AppServices {
            val db = Room.databaseBuilder(context.applicationContext, AppDatabase::class.java, "prosary.db").build()
            val presetStore = RoomPresetStore(db.presetDao())
            runBlocking { presetStore.seedIfEmpty() }
            return AppServices(
                presetStore = presetStore,
                engine = PrayerEngine(),
                calendar = MockLiturgicalCalendar(),
            )
        }
    }
}

val LocalAppServices = staticCompositionLocalOf { AppServices.preview }
