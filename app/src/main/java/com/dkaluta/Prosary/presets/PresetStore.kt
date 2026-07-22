package com.dkaluta.Prosary.presets

import com.dkaluta.Prosary.models.RosaryConfig

/** What the UI needs from the backend to save/load Rosary presets. This is the persistence
 * boundary — implement your own production version (file, Room, DataStore, etc.); see
 * [MockPresetStore] for a fully-working in-memory version used to drive the app today. */
interface PresetStore {
    suspend fun all(): List<RosaryConfig>

    /** The preset used when the user just taps "Pray" without picking one explicitly. Every
     * store is expected to always have at least one preset, so this never returns null. */
    suspend fun defaultPreset(): RosaryConfig

    suspend fun get(id: String): RosaryConfig?

    /** Inserts a new preset, or updates one that already exists (matched by `config.id`). If
     * `config.isDefault` is true, every other saved preset should have its own flag cleared. */
    suspend fun save(config: RosaryConfig)

    /** Deletes a preset. If it was the default and other presets remain, the store should
     * promote one of them to be the new default. */
    suspend fun delete(config: RosaryConfig)
}
