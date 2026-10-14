package com.dkaluta.prosary.content.prayerpack

import com.dkaluta.prosary.models.Prayer
import com.dkaluta.prosary.models.PrayerKind
import com.dkaluta.prosary.presets.PresetStore

/** Permanently withdrawn downloads. Authored text credited by a built-in pack remains usable. */
object RetiredPrayerPacks {
    val ids: Set<String> = setOf("repo.stgamliel-il.litanyOfMaryTheBlessedEverVirgin")

    fun contains(id: String?): Boolean = id in ids

    fun contains(prayer: Prayer): Boolean =
        prayer.kind == PrayerKind.Custom && contains(prayer.customDevotionId)

    /** Run on every launch: a device backup may restore an older saved copy at any time.
     * Cancel its reminders before deleting so a cleanup failure leaves a row to retry. */
    suspend fun removeSavedPrayers(store: PresetStore, cancelReminders: (Prayer) -> Unit) {
        for (prayer in store.all().filter(::contains)) {
            cancelReminders(prayer)
            store.delete(prayer)
        }
    }
}
