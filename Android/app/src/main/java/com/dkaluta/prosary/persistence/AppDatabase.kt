package com.dkaluta.prosary.persistence

import androidx.room.Database
import androidx.room.RoomDatabase
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase

@Database(entities = [PresetEntity::class], version = 9, exportSchema = false)
abstract class AppDatabase : RoomDatabase() {
    abstract fun presetDao(): PresetDao
}

/** Adds the columns for the Rosary's "One Mystery Only"/"Presenter Mode" options. Room (unlike
 * SwiftData/sqlite-net-pcl on the other two platforms) doesn't auto-migrate added columns —
 * without this, any update that changes [PresetEntity]'s schema would crash at startup with
 * "migration required but not found" for anyone with an existing saved favorite. */
val MIGRATION_1_2 = object : Migration(1, 2) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL("ALTER TABLE presets ADD COLUMN specificMysteryOrder INTEGER NOT NULL DEFAULT 1")
        db.execSQL("ALTER TABLE presets ADD COLUMN presenterMode INTEGER NOT NULL DEFAULT 0")
    }
}

/** Adds the bundle-id column for PrayerKind.Custom favorites (e.g. Trisagion) — see
 * [PresetEntity.customDevotionId]. */
val MIGRATION_2_3 = object : Migration(2, 3) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL("ALTER TABLE presets ADD COLUMN customDevotionId TEXT")
    }
}

/** Adds the bundle-variant column (alternate step-sets, e.g. the Stations' traditional vs.
 * scriptural forms) — see [PresetEntity.variantId]. */
val MIGRATION_3_4 = object : Migration(3, 4) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL("ALTER TABLE presets ADD COLUMN variantId TEXT")
    }
}

/** Adds the options.json choices column (e.g. the Franciscan Crown's optional closing
 * devotions) — see [PresetEntity.customOptionsJson]. */
val MIGRATION_4_5 = object : Migration(4, 5) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL("ALTER TABLE presets ADD COLUMN customOptionsJson TEXT NOT NULL DEFAULT '{}'")
    }
}

/** Adds multi-day progress — see [PresetEntity.dayIndex]. */
val MIGRATION_5_6 = object : Migration(5, 6) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL("ALTER TABLE presets ADD COLUMN dayIndex INTEGER")
    }
}

/** Adds the Rosary's closing-intentions toggle and mystery-artwork style — see
 * [PresetEntity.includeClosingIntentions] and [PresetEntity.mysteryImageStyle]. */
val MIGRATION_6_7 = object : Migration(6, 7) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL("ALTER TABLE presets ADD COLUMN includeClosingIntentions INTEGER NOT NULL DEFAULT 0")
        db.execSQL("ALTER TABLE presets ADD COLUMN mysteryImageStyle TEXT NOT NULL DEFAULT 'Classic'")
    }
}

/** Adds the per-Rosary Aramaic Sign of the Cross form. */
val MIGRATION_7_8 = object : Migration(7, 8) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL("ALTER TABLE presets ADD COLUMN aramaicSignOfCrossForm TEXT NOT NULL DEFAULT 'formA'")
    }
}

/** Adds the optional Fatima Prayer after the three opening Hail Marys. Existing favorites keep
 * the historical sequence because the new option defaults off. */
val MIGRATION_8_9 = object : Migration(8, 9) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL("ALTER TABLE presets ADD COLUMN includeOpeningFatimaPrayer INTEGER NOT NULL DEFAULT 0")
    }
}

/** Every schema migration, in order. Register this wherever a Room instance is built
 * ([com.dkaluta.prosary.services.AppServices] and the boot-time reopen in
 * [com.dkaluta.prosary.reminders.BootReceiver]) — a secondary open that registers only a
 * subset crashes the moment it meets a database version whose step it lacks (an app update
 * followed by a reboot before the first launch reaches BootReceiver first). */
val ALL_MIGRATIONS = arrayOf(
    MIGRATION_1_2, MIGRATION_2_3, MIGRATION_3_4, MIGRATION_4_5,
    MIGRATION_5_6, MIGRATION_6_7, MIGRATION_7_8, MIGRATION_8_9,
)
