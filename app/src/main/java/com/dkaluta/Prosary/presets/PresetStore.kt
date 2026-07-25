package com.dkaluta.Prosary.presets

import com.dkaluta.Prosary.models.Prayer

/** Persistence boundary for saved prayer favorites. Implement your own production version (this
 * app uses Room — see [com.dkaluta.Prosary.persistence.RoomPresetStore]); see [MockPresetStore]
 * for a fully-working in-memory version used in previews/tests. */
interface PresetStore {
    /** All saved favorites, in any order. */
    suspend fun all(): List<Prayer>

    /** The starred (isDefault) Rosary favorite, or the first Rosary favorite if none is starred,
     * or null if no Rosary favorites exist at all. */
    suspend fun defaultPreset(): Prayer?

    suspend fun get(id: String): Prayer?

    /** Inserts a new favorite or updates an existing one (matched by id). When
     * `prayer.isDefault` is true, every other saved favorite of the **same kind** has its flag
     * cleared — each kind keeps its own independent default. */
    suspend fun save(prayer: Prayer)

    /** Deletes a favorite. If it was the default and other favorites of the same kind remain,
     * the next one is promoted to default. */
    suspend fun delete(prayer: Prayer)
}
