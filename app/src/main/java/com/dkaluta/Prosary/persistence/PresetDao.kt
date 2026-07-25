package com.dkaluta.Prosary.persistence

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Query
import androidx.room.Upsert

@Dao
interface PresetDao {
    @Query("SELECT * FROM presets ORDER BY name")
    suspend fun getAll(): List<PresetEntity>

    @Query("SELECT * FROM presets WHERE id = :id LIMIT 1")
    suspend fun getById(id: String): PresetEntity?

    @Query("SELECT COUNT(*) FROM presets")
    suspend fun count(): Int

    @Upsert
    suspend fun upsert(entity: PresetEntity)

    @Delete
    suspend fun delete(entity: PresetEntity)
}
