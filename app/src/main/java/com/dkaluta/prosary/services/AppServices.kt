package com.dkaluta.prosary.services

import android.content.Context
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.room.Room
import com.dkaluta.prosary.calendar.LiturgicalCalendarProviding
import com.dkaluta.prosary.calendar.MockLiturgicalCalendar
import com.dkaluta.prosary.engine.AngelusEngine
import com.dkaluta.prosary.engine.DivineMercyEngine
import com.dkaluta.prosary.engine.FranciscanCrownEngine
import com.dkaluta.prosary.engine.MockAngelusEngine
import com.dkaluta.prosary.engine.MockDivineMercyEngine
import com.dkaluta.prosary.engine.MockFranciscanCrownEngine
import com.dkaluta.prosary.engine.MockRosaryEngine
import com.dkaluta.prosary.engine.MockSevenSorrowsEngine
import com.dkaluta.prosary.engine.MockStationsEngine
import com.dkaluta.prosary.engine.RosaryEngine
import com.dkaluta.prosary.engine.SevenSorrowsEngine
import com.dkaluta.prosary.engine.StationsEngine
import com.dkaluta.prosary.persistence.AppDatabase
import com.dkaluta.prosary.persistence.RoomPresetStore
import com.dkaluta.prosary.presets.MockPresetStore
import com.dkaluta.prosary.presets.PresetStore
import kotlinx.coroutines.runBlocking

/** The backend, as the UI sees it — four interfaces, provided once at the app root and read via
 * [LocalAppServices] everywhere else. [create] wires the production implementations: Room-backed
 * persistence, while `Mock*` engines/calendar are already production-direct per this codebase's
 * existing convention (see their own docs) — everything downstream only ever talks to the
 * interfaces. */
data class AppServices(
    val presetStore: PresetStore,
    val rosaryEngine: RosaryEngine,
    val angelusEngine: AngelusEngine,
    val stationsEngine: StationsEngine,
    val franciscanCrownEngine: FranciscanCrownEngine,
    val sevenSorrowsEngine: SevenSorrowsEngine,
    val divineMercyEngine: DivineMercyEngine,
    val calendar: LiturgicalCalendarProviding,
) {
    companion object {
        /** In-memory fallback for `@Preview` call sites, which have no Activity [Context] to
         * build a Room database from. */
        val preview = AppServices(
            presetStore = MockPresetStore(),
            rosaryEngine = MockRosaryEngine(),
            angelusEngine = MockAngelusEngine(),
            stationsEngine = MockStationsEngine(),
            franciscanCrownEngine = MockFranciscanCrownEngine(),
            sevenSorrowsEngine = MockSevenSorrowsEngine(),
            divineMercyEngine = MockDivineMercyEngine(),
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
                rosaryEngine = MockRosaryEngine(),
                angelusEngine = MockAngelusEngine(),
                stationsEngine = MockStationsEngine(),
                franciscanCrownEngine = MockFranciscanCrownEngine(),
                sevenSorrowsEngine = MockSevenSorrowsEngine(),
                divineMercyEngine = MockDivineMercyEngine(),
                calendar = MockLiturgicalCalendar(),
            )
        }
    }
}

val LocalAppServices = staticCompositionLocalOf { AppServices.preview }
