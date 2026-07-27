package com.dkaluta.prosary.persistence

import androidx.room.Database
import androidx.room.RoomDatabase
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase

@Database(entities = [PresetEntity::class], version = 2, exportSchema = false)
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
