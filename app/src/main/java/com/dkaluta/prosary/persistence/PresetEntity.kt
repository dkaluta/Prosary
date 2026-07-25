package com.dkaluta.prosary.persistence

import androidx.room.Entity
import androidx.room.PrimaryKey
import com.dkaluta.prosary.models.EternalRestPlacement
import com.dkaluta.prosary.models.JesusPrayerOptions
import com.dkaluta.prosary.models.JesusPrayerTarget
import com.dkaluta.prosary.models.MarianAntiphonOption
import com.dkaluta.prosary.models.MysteryGroup
import com.dkaluta.prosary.models.MysterySelectionMode
import com.dkaluta.prosary.models.Prayer
import com.dkaluta.prosary.models.PrayerKind
import com.dkaluta.prosary.models.PrayerReminder
import com.dkaluta.prosary.models.RosaryOptions
import org.json.JSONArray
import org.json.JSONObject

/**
 * Room row for a saved [Prayer]. `remindersJson` is a manually (de)serialized JSON array (via
 * `org.json`, already part of the Android SDK — no new dependency needed) rather than a Room
 * TypeConverter or a second relational table: it's a small list always loaded with its parent
 * Prayer, mirroring how iOS's `PresetEntry.remindersJSON` is a `Data` blob.
 */
@Entity(tableName = "presets")
data class PresetEntity(
    @PrimaryKey val id: String,
    val name: String,
    val isDefault: Boolean,
    val languageCode: String,

    // Discriminant — PrayerKind's enum name. Defaults to Rosary so a schema upgrade that adds
    // this column to existing rows doesn't need a destructive migration.
    val kind: String = PrayerKind.Rosary.name,

    // Rosary-specific fields (populated when kind == Rosary)
    val mysterySelectionMode: String = MysterySelectionMode.TodaysMysteries.name,
    val specificMysteryGroup: String = MysteryGroup.Joyful.name,
    val includeApostlesCreed: Boolean = true,
    val includeOpeningPrayers: Boolean = true,
    val includeFatimaPrayers: Boolean = true,
    val eternalRestForDeceased: String = EternalRestPlacement.None.name,
    val marianAntiphon: String = MarianAntiphonOption.Seasonal.name,
    val includeStMichaelPrayer: Boolean = false,
    val includeFinalSignOfCross: Boolean = true,

    // Jesus Prayer-specific fields (populated when kind == JesusPrayer)
    val jesusPrayerIsUnbounded: Boolean = false,
    val jesusPrayerCount: Int = 33,

    // Reminders — JSON-encoded List<PrayerReminder>. Defaults to an empty array for existing rows.
    val remindersJson: String = "[]",
) {
    fun toPrayer(): Prayer {
        val target = if (jesusPrayerIsUnbounded) JesusPrayerTarget.Unbounded else JesusPrayerTarget.Count(jesusPrayerCount)
        return Prayer(
            id = id,
            name = name,
            kind = runCatching { PrayerKind.valueOf(kind) }.getOrDefault(PrayerKind.Rosary),
            isDefault = isDefault,
            languageCode = languageCode,
            rosary = RosaryOptions(
                mysterySelectionMode = runCatching { MysterySelectionMode.valueOf(mysterySelectionMode) }
                    .getOrDefault(MysterySelectionMode.TodaysMysteries),
                specificMysteryGroup = runCatching { MysteryGroup.valueOf(specificMysteryGroup) }
                    .getOrDefault(MysteryGroup.Joyful),
                includeApostlesCreed = includeApostlesCreed,
                includeOpeningPrayers = includeOpeningPrayers,
                includeFatimaPrayer = includeFatimaPrayers,
                eternalRestForDeceased = runCatching { EternalRestPlacement.valueOf(eternalRestForDeceased) }
                    .getOrDefault(EternalRestPlacement.None),
                marianAntiphon = runCatching { MarianAntiphonOption.valueOf(marianAntiphon) }
                    .getOrDefault(MarianAntiphonOption.Seasonal),
                includeStMichaelPrayer = includeStMichaelPrayer,
                includeFinalSignOfCross = includeFinalSignOfCross,
            ),
            jesusPrayer = JesusPrayerOptions(target = target),
            reminders = remindersFromJson(remindersJson),
        )
    }

    companion object {
        fun from(prayer: Prayer): PresetEntity {
            val (isUnbounded, count) = when (val target = prayer.jesusPrayer.target) {
                is JesusPrayerTarget.Count -> false to target.value
                JesusPrayerTarget.Unbounded -> true to 33
            }
            return PresetEntity(
                id = prayer.id,
                name = prayer.name,
                isDefault = prayer.isDefault,
                languageCode = prayer.languageCode,
                kind = prayer.kind.name,
                mysterySelectionMode = prayer.rosary.mysterySelectionMode.name,
                specificMysteryGroup = prayer.rosary.specificMysteryGroup.name,
                includeApostlesCreed = prayer.rosary.includeApostlesCreed,
                includeOpeningPrayers = prayer.rosary.includeOpeningPrayers,
                includeFatimaPrayers = prayer.rosary.includeFatimaPrayer,
                eternalRestForDeceased = prayer.rosary.eternalRestForDeceased.name,
                marianAntiphon = prayer.rosary.marianAntiphon.name,
                includeStMichaelPrayer = prayer.rosary.includeStMichaelPrayer,
                includeFinalSignOfCross = prayer.rosary.includeFinalSignOfCross,
                jesusPrayerIsUnbounded = isUnbounded,
                jesusPrayerCount = count,
                remindersJson = remindersToJson(prayer.reminders),
            )
        }

        private fun remindersToJson(reminders: List<PrayerReminder>): String {
            val array = JSONArray()
            for (reminder in reminders) {
                val obj = JSONObject()
                obj.put("id", reminder.id)
                obj.put("hour", reminder.hour)
                obj.put("minute", reminder.minute)
                obj.put("isEnabled", reminder.isEnabled)
                array.put(obj)
            }
            return array.toString()
        }

        private fun remindersFromJson(json: String): List<PrayerReminder> = runCatching {
            val array = JSONArray(json)
            (0 until array.length()).map { i ->
                val obj = array.getJSONObject(i)
                PrayerReminder(
                    id = obj.getString("id"),
                    hour = obj.getInt("hour"),
                    minute = obj.optInt("minute", 0),
                    isEnabled = obj.optBoolean("isEnabled", true),
                )
            }
        }.getOrDefault(emptyList())
    }
}
