package com.dkaluta.prosary.persistence

import androidx.room.Entity
import androidx.room.PrimaryKey
import com.dkaluta.prosary.models.EternalRestPlacement
import com.dkaluta.prosary.models.JesusPrayerOptions
import com.dkaluta.prosary.models.JesusPrayerTarget
import com.dkaluta.prosary.models.MarianAntiphonOption
import com.dkaluta.prosary.models.MysteryGroup
import com.dkaluta.prosary.models.MysteryImageStyle
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

    // Bundle id for a generic (kind == Custom) devotion, e.g. "trisagion". Null for every other
    // kind. Nullable handles existing rows predating this column.
    val customDevotionId: String? = null,

    // Which bundle variant (alternate step-set) this favorite prays; null = the bundle's
    // default. Added in DB version 4 (see MIGRATION_3_4).
    val variantId: String? = null,
    val dayIndex: Int? = null,

    // JSON-encoded Map<String, String> of the favorite's options.json choices (see
    // Prayer.customOptions). Added in DB version 5 (see MIGRATION_4_5).
    val customOptionsJson: String = "{}",

    // Rosary-specific fields (populated when kind == Rosary)
    val mysterySelectionMode: String = MysterySelectionMode.TodaysMysteries.name,
    val specificMysteryGroup: String = MysteryGroup.Joyful.name,
    // 1-based index into MysteryCatalog.forGroup(specificMysteryGroup); used only when
    // mysterySelectionMode is SingleMystery. Defaults to 1 for existing rows.
    val specificMysteryOrder: Int = 1,
    val includeApostlesCreed: Boolean = true,
    val includeOpeningPrayers: Boolean = true,
    val includeFatimaPrayers: Boolean = true,
    val eternalRestForDeceased: String = EternalRestPlacement.None.name,
    val marianAntiphon: String = MarianAntiphonOption.Seasonal.name,
    // Defaults to false for existing rows. Added in DB version 7 (see MIGRATION_6_7).
    val includeClosingIntentions: Boolean = false,
    val includeStMichaelPrayer: Boolean = false,
    val includeFinalSignOfCross: Boolean = true,
    // Added in DB version 8 (see MIGRATION_7_8).
    val aramaicSignOfCrossForm: String = "formA",
    // Defaults to false for existing rows.
    val presenterMode: Boolean = false,
    // MysteryImageStyle's enum name. Added in DB version 7 (see MIGRATION_6_7).
    val mysteryImageStyle: String = MysteryImageStyle.Classic.name,

    // Jesus Prayer-specific fields (populated when kind == JesusPrayer)
    val jesusPrayerIsUnbounded: Boolean = false,
    val jesusPrayerCount: Int = 33,

    // Reminders — JSON-encoded List<PrayerReminder>. Defaults to an empty array for existing rows.
    val remindersJson: String = "[]",
) {
    /** The row's (kind, customDevotionId) identity, with legacy per-devotion kinds resolved.
     * Rows written before the generic-devotion migration store deleted enum names ("Angelus",
     * "StationsOfTheCross", ...) whose camelCased form is exactly the matching bundle id — map
     * them to Custom + that id. This is permanent read-time behavior, not a one-shot migration:
     * a cloud backup restore can bring rows from old app versions in at any time. Normalized on
     * next save (Prayer.kind is already Custom by then). */
    val resolvedKind: Pair<PrayerKind, String?>
        get() {
            val known = runCatching { PrayerKind.valueOf(kind) }.getOrNull()
            if (known != null) return known to customDevotionId
            return PrayerKind.Custom to (customDevotionId ?: kind.replaceFirstChar { it.lowercaseChar() })
        }

    fun toPrayer(): Prayer {
        val target = if (jesusPrayerIsUnbounded) JesusPrayerTarget.Unbounded else JesusPrayerTarget.Count(jesusPrayerCount)
        val (resolvedKind, resolvedDevotionId) = resolvedKind
        return Prayer(
            id = id,
            name = name,
            kind = resolvedKind,
            isDefault = isDefault,
            languageCode = languageCode,
            customDevotionId = resolvedDevotionId,
            variantId = variantId,
            dayIndex = dayIndex,
            customOptions = customOptionsFromJson(customOptionsJson),
            rosary = RosaryOptions(
                mysterySelectionMode = runCatching { MysterySelectionMode.valueOf(mysterySelectionMode) }
                    .getOrDefault(MysterySelectionMode.TodaysMysteries),
                specificMysteryGroup = runCatching { MysteryGroup.valueOf(specificMysteryGroup) }
                    .getOrDefault(MysteryGroup.Joyful),
                specificMysteryOrder = specificMysteryOrder,
                includeApostlesCreed = includeApostlesCreed,
                includeOpeningPrayers = includeOpeningPrayers,
                includeFatimaPrayer = includeFatimaPrayers,
                eternalRestForDeceased = runCatching { EternalRestPlacement.valueOf(eternalRestForDeceased) }
                    .getOrDefault(EternalRestPlacement.None),
                marianAntiphon = runCatching { MarianAntiphonOption.valueOf(marianAntiphon) }
                    .getOrDefault(MarianAntiphonOption.Seasonal),
                includeClosingIntentions = includeClosingIntentions,
                includeStMichaelPrayer = includeStMichaelPrayer,
                includeFinalSignOfCross = includeFinalSignOfCross,
                aramaicSignOfCrossForm = aramaicSignOfCrossForm,
                presenterMode = presenterMode,
                mysteryImageStyle = runCatching { MysteryImageStyle.valueOf(mysteryImageStyle) }
                    .getOrDefault(MysteryImageStyle.Classic),
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
                customDevotionId = prayer.customDevotionId,
                variantId = prayer.variantId,
                dayIndex = prayer.dayIndex,
                customOptionsJson = customOptionsToJson(prayer.customOptions),
                mysterySelectionMode = prayer.rosary.mysterySelectionMode.name,
                specificMysteryGroup = prayer.rosary.specificMysteryGroup.name,
                specificMysteryOrder = prayer.rosary.specificMysteryOrder,
                includeApostlesCreed = prayer.rosary.includeApostlesCreed,
                includeOpeningPrayers = prayer.rosary.includeOpeningPrayers,
                includeFatimaPrayers = prayer.rosary.includeFatimaPrayer,
                eternalRestForDeceased = prayer.rosary.eternalRestForDeceased.name,
                marianAntiphon = prayer.rosary.marianAntiphon.name,
                includeClosingIntentions = prayer.rosary.includeClosingIntentions,
                includeStMichaelPrayer = prayer.rosary.includeStMichaelPrayer,
                includeFinalSignOfCross = prayer.rosary.includeFinalSignOfCross,
                aramaicSignOfCrossForm = prayer.rosary.aramaicSignOfCrossForm,
                presenterMode = prayer.rosary.presenterMode,
                mysteryImageStyle = prayer.rosary.mysteryImageStyle.name,
                jesusPrayerIsUnbounded = isUnbounded,
                jesusPrayerCount = count,
                remindersJson = remindersToJson(prayer.reminders),
            )
        }

        private fun customOptionsToJson(options: Map<String, String>): String {
            val obj = JSONObject()
            for ((key, value) in options) obj.put(key, value)
            return obj.toString()
        }

        private fun customOptionsFromJson(json: String): Map<String, String> = runCatching {
            val obj = JSONObject(json)
            obj.keys().asSequence().associateWith { obj.getString(it) }
        }.getOrDefault(emptyMap())

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
