package com.dkaluta.Prosary.persistence

import androidx.room.Database
import androidx.room.RoomDatabase

@Database(entities = [PresetEntity::class], version = 1, exportSchema = false)
abstract class AppDatabase : RoomDatabase() {
    abstract fun presetDao(): PresetDao
}
