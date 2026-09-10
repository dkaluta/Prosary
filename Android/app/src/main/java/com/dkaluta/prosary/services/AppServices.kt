package com.dkaluta.prosary.services

import android.content.Context
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.sqlite.db.SupportSQLiteDatabase
import com.dkaluta.prosary.calendar.LiturgicalCalendarProviding
import com.dkaluta.prosary.calendar.MockLiturgicalCalendar
import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import com.dkaluta.prosary.content.today.TodayInfoStore
import com.dkaluta.prosary.engine.PrayerEngine
import com.dkaluta.prosary.persistence.ALL_MIGRATIONS
import com.dkaluta.prosary.persistence.AppDatabase
import com.dkaluta.prosary.persistence.RoomPresetStore
import com.dkaluta.prosary.presets.MockPresetStore
import com.dkaluta.prosary.presets.PresetStore
import java.io.IOException
import java.util.concurrent.atomic.AtomicBoolean
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
        @Volatile
        private var production: AppServices? = null

        /** In-memory fallback for `@Preview` call sites, which have no Activity [Context] to
         * build a Room database from. */
        val preview = AppServices(
            presetStore = MockPresetStore(),
            engine = PrayerEngine(),
            calendar = MockLiturgicalCalendar(),
        )

        /** Returns the process-wide production graph. Construction runs on an IO dispatcher in
         * MainActivity; the synchronized fallback prevents configuration changes from opening a
         * second Room instance while the first launch is still indexing packs. */
        fun create(context: Context): AppServices {
            production?.let { return it }
            return synchronized(this) {
                production?.let { return@synchronized it }
                build(context.applicationContext).also { production = it }
            }
        }

        /** Lets a recreated Activity render immediately when the process graph already exists. */
        fun cached(): AppServices? = production

        /** Seeds before publishing the graph, so the first Pray frame never races an empty
         * preset store against the initial insert. */
        private fun build(context: Context): AppServices {
            val created = AtomicBoolean(false)
            val db = Room.databaseBuilder(context.applicationContext, AppDatabase::class.java, "prosary.db")
                .addMigrations(*ALL_MIGRATIONS)
                .addCallback(object : RoomDatabase.Callback() {
                    override fun onCreate(db: SupportSQLiteDatabase) {
                        created.set(true)
                    }
                })
                .build()
            val presetStore = RoomPresetStore(db.presetDao()) {
                com.dkaluta.prosary.widgets.WidgetUpdates.request(context)
            }
            // Opening triggers onCreate only for a new database. A deliberately emptied
            // library stays empty across restarts, including after an app upgrade.
            db.openHelper.writableDatabase
            if (created.get()) runBlocking { presetStore.seedIfEmpty() }
            PrayerPackStore.installedPacksDirectory = java.io.File(context.filesDir, "prayerpacks")
            PrayerPackStore.initialize(context.assets)
            TodayInfoStore.initialize { name ->
                runCatching { context.assets.open("data/$name.json") }
                    .getOrElse { if (it is IOException) null else throw it }
            }
            return AppServices(
                presetStore = presetStore,
                engine = PrayerEngine(),
                calendar = MockLiturgicalCalendar(),
            )
        }
    }
}

val LocalAppServices = staticCompositionLocalOf { AppServices.preview }
