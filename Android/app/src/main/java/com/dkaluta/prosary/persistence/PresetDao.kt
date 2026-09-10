package com.dkaluta.prosary.persistence

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Query
import androidx.room.Upsert
import androidx.room.Update
import androidx.room.Transaction

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

    @Update
    suspend fun update(entity: PresetEntity): Int

    @Delete
    suspend fun delete(entity: PresetEntity)

    @Transaction
    suspend fun deleteAndPromote(id: String) {
        val entity = getById(id) ?: return
        delete(entity)
        if (entity.isDefault) {
            getAll().firstOrNull { it.resolvedKind == entity.resolvedKind }?.let {
                upsert(it.copy(isDefault = true))
            }
        }
    }
}
