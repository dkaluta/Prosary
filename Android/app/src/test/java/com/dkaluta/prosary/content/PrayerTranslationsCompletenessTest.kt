package com.dkaluta.prosary.content

import com.dkaluta.prosary.content.prayerpack.CustomDevotionDefinition
import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import com.dkaluta.prosary.models.MysteryCatalog
import com.dkaluta.prosary.models.MysteryGroup
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.BeforeClass
import org.junit.Test

/**
 * Guards against silent content gaps. Two layers:
 * 1. The hardcoded tables (main prayers, Rosary keys, antiphons, Jesus Prayer) — every surviving
 *    [PrayerKey] must have all six languages; [PrayerTranslations.get] silently falls back to
 *    Latin, so a gap wouldn't otherwise surface until someone prays in that language.
 * 2. Every shipped devotion bundle — each key its devotion.json references must resolve to real
 *    text (never the raw key) in every language the bundle's manifest declares, with each
 *    bundle's known gaps listed explicitly so they go stale loudly instead of silently wrong.
 *    Mirrors Shared/tools/validate-devotion.py, but against the actually-shipped packs and the
 *    runtime merge (e.g. the Franciscan Crown's shared Joys resolving cross-bundle from the
 *    rosary pack). Mirrors iOS's PrayerTranslationsCompletenessTests.swift.
 */
class PrayerTranslationsCompletenessTest {
    companion object {
        @BeforeClass
        @JvmStatic
        fun loadPacks() {
            PrayerPackStore.initialize { packName ->
                val file = File("src/main/assets/$packName.prosaryprayer")
                if (file.exists()) file.inputStream() else null
            }
        }
    }

    private val allLanguages = listOf("la", "en", "ar", "he", "ru", "tl")

    /** [PrayerKey.DoxologiaMinor] is explicitly documented ("kept for future use") as reserved
     * but not wired into any devotion's engine code yet — it has no Latin/English content at all
     * (only a Hebrew entry, added manually), so it can't satisfy even the baseline check.
     * Excluded here rather than fabricating placeholder Latin/English text for a key nothing
     * reads yet. */
    private val notYetUsedByAnyDevotion = setOf(PrayerKey.DoxologiaMinor)

    /** Known per-bundle translation gaps: bundleId -> language -> keys awaiting a verified
     * translation. The self-guard test below fails once a listed key gains its translation, so
     * this map can never go silently stale. */
    private val bundleKeysMissingLanguages: Map<String, Map<String, Set<String>>> = mapOf(
        "divineMercyChaplet" to mapOf("he" to setOf("divineMercyOffering", "divineMercyPetition")),
        // The composed closing (versicle + Stabat Mater collect) has no verified translation in
        // these languages yet — it falls back to the bundle's Latin text.
        "sevenSorrows" to mapOf(
            "ar" to setOf("sevenSorrowsClosingBody"),
            "he" to setOf("sevenSorrowsClosingBody"),
            "ru" to setOf("sevenSorrowsClosingBody"),
            "tl" to setOf("sevenSorrowsClosingBody"),
        ),
    )

    private val allMysteryImageKeys: Set<String> =
        MysteryGroup.entries.flatMap { MysteryCatalog.forGroup(it) }.map { it.imageKey }.toSet()

    // MARK: Hardcoded tables

    @Test
    fun everyPrayerKeyHasAllSixLanguages() {
        for (key in PrayerKey.entries) {
            if (key in notYetUsedByAnyDevotion) continue
            for (language in allLanguages) {
                val text = PrayerTranslations.byLanguage[language]?.get(key)
                assertNotNull("$key missing a $language translation", text)
                assertFalse("$key has an empty $language translation", text.isNullOrEmpty())
            }
        }
    }

    @Test
    fun everyRosaryMysteryImageKeyHasAllSixLanguages() {
        for (imageKey in allMysteryImageKeys) {
            for (language in allLanguages) {
                assertNotNull(
                    "$imageKey missing a $language translation",
                    MysteryTranslations.byLanguage[language]?.get(imageKey),
                )
            }
        }
    }

    // MARK: Shipped bundles

    /** Collects every bodyKey/titleKey a definition references, and the mystery imageKeys whose
     * text an announced decade needs. */
    private fun referencedKeys(definition: CustomDevotionDefinition): Pair<Set<String>, Set<String>> {
        val text = mutableSetOf<String>()
        val mysteries = mutableSetOf<String>()
        val allEntries = definition.steps.orEmpty() + definition.eastertideSteps.orEmpty() +
            definition.opening.orEmpty() + definition.closing.orEmpty() +
            definition.variants.orEmpty().flatMap { it.steps + it.eastertideSteps.orEmpty() }
        for (entry in allEntries) {
            if (entry.kind != null) continue
            entry.bodyKey?.let { text.add(it) }
            entry.titleKey?.let { text.add(it) }
        }
        definition.decades?.let { decades ->
            text.add(decades.majorStep.bodyKey)
            text.add(decades.minorStep.bodyKey)
            if (decades.announceMystery) {
                for (entry in decades.entries.orEmpty()) mysteries.add(entry.imageKey)
            }
        }
        return text to mysteries
    }

    @Test
    fun everyBundleKeyResolvesInEveryDeclaredLanguage() {
        for (bundleId in PrayerPackStore.customDevotionIds()) {
            val definition = PrayerPackStore.definition(bundleId)
            val info = PrayerPackStore.info(bundleId)
            assertNotNull("$bundleId: missing definition", definition)
            assertNotNull("$bundleId: missing info", info)
            val (textKeys, mysteryKeys) = referencedKeys(definition!!)
            for (language in info!!.languages) {
                val allowedMissing = bundleKeysMissingLanguages[bundleId]?.get(language) ?: emptySet()
                for (key in textKeys) {
                    if (key in allowedMissing) continue
                    val resolved = PrayerPackStore.resolveBodyText(bundleId, language, key)
                    assertNotEquals(
                        "$bundleId/$language: $key resolves to its raw key — missing translation",
                        key, resolved,
                    )
                }
                for (imageKey in mysteryKeys) {
                    val mystery = MysteryTranslations.get(language, imageKey)
                    assertNotEquals(
                        "$bundleId/$language: no mystery text for $imageKey",
                        imageKey, mystery.title,
                    )
                }
            }
        }
    }

    /** Guards the gap allowlist itself from going stale: once a listed key gains a translation,
     * this fails as a reminder to narrow the allowlist rather than leaving it inaccurate. */
    @Test
    fun allowlistedBundleKeysAreStillMissingFromTheExpectedLanguages() {
        for ((bundleId, languages) in bundleKeysMissingLanguages) {
            for ((language, keys) in languages) {
                for (key in keys) {
                    val resolved = PrayerPackStore.resolveBodyText(bundleId, language, key)
                    // A missing bundle-local translation falls back to the bundle's Latin text
                    // (or the hardcoded chain) — "still missing" means it doesn't resolve to
                    // language-specific bundle content, i.e. it equals the Latin resolution.
                    val latin = PrayerPackStore.resolveBodyText(bundleId, "la", key)
                    assertEquals(
                        "$bundleId/$language: $key now has its own translation — narrow bundleKeysMissingLanguages",
                        latin, resolved,
                    )
                }
            }
        }
    }
}
