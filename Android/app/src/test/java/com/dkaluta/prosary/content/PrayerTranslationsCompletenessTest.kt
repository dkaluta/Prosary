package com.dkaluta.prosary.content

import com.dkaluta.prosary.models.FranciscanCrownCatalog
import com.dkaluta.prosary.models.MysteryCatalog
import com.dkaluta.prosary.models.MysteryGroup
import com.dkaluta.prosary.models.SevenSorrowsCatalog
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Guards against a missed cell in the per-language content tables — [PrayerTranslations.get]/
 * [MysteryTranslations.get] silently fall back to Latin (then the raw key) when a translation is
 * missing, so a gap here wouldn't otherwise surface until someone actually reads that language in
 * the app. Mirrors iOS's PrayerTranslationsCompletenessTests.swift.
 */
class PrayerTranslationsCompletenessTest {
    private val fullyTranslatedLanguages = listOf("ar", "he", "ru", "tl")

    /** [PrayerKey]s added during the 4-devotion rollout (Stations of the Cross, Seven Sorrows,
     * Divine Mercy Chaplet) that are currently translated only into Latin and English — silently
     * falls back to Latin in the other 4 languages via the normal fallback chain, not a bug. Kept
     * explicit here so a *new*, unintentional gap still fails
     * [everyKeyExceptTheKnownAllowlistHasAllSixLanguages]. */
    private val latinAndEnglishOnlyPrayerKeys = setOf(
        PrayerKey.StationsOpeningPrayer, PrayerKey.StationsVersicle, PrayerKey.StationsResponse, PrayerKey.StationsClosingPrayer,
        PrayerKey.SevenSorrowsVersicle, PrayerKey.SevenSorrowsResponse, PrayerKey.SevenSorrowsCollect,
        PrayerKey.DivineMercyOffering, PrayerKey.DivineMercyPetition, PrayerKey.DivineMercyClosingAcclamation,
    )

    /** Same idea as [latinAndEnglishOnlyPrayerKeys], for [MysteryTranslations] — the Seven
     * Sorrows' 7 imageKeys and the Franciscan Crown's one new mystery (Adoration of the Magi; the
     * other 6 Joys reuse existing, fully-translated Rosary mystery content). */
    private val latinAndEnglishOnlyMysteryImageKeys =
        SevenSorrowsCatalog.sevenSorrows.toSet() + "franciscan_04_adoration_of_the_magi"

    /** [PrayerKey.DoxologiaMinor] is explicitly documented ("kept for future use") as reserved
     * but not wired into any devotion's engine code yet — it has no Latin/English content at all
     * (only a Hebrew entry, added manually), so it can't satisfy even the baseline
     * [everyPrayerKeyHasLatinAndEnglishTranslations] check. Excluded here rather than fabricating
     * placeholder Latin/English text for a key nothing reads yet. */
    private val notYetUsedByAnyDevotion = setOf(PrayerKey.DoxologiaMinor)

    private val allMysteryImageKeys: Set<String> =
        MysteryGroup.entries.flatMap { MysteryCatalog.forGroup(it) }.map { it.imageKey }.toSet() +
            SevenSorrowsCatalog.sevenSorrows.toSet() +
            FranciscanCrownCatalog.sevenJoys.toSet()

    @Test
    fun everyPrayerKeyHasLatinAndEnglishTranslations() {
        for (key in PrayerKey.entries) {
            if (key in notYetUsedByAnyDevotion) continue
            for (language in listOf("la", "en")) {
                val text = PrayerTranslations.byLanguage[language]?.get(key)
                assertNotNull("$key missing a $language translation", text)
                assertFalse("$key has an empty $language translation", text.isNullOrEmpty())
            }
        }
    }

    @Test
    fun everyKeyExceptTheKnownAllowlistHasAllSixLanguages() {
        for (key in PrayerKey.entries) {
            if (key in latinAndEnglishOnlyPrayerKeys || key in notYetUsedByAnyDevotion) continue
            for (language in fullyTranslatedLanguages) {
                val text = PrayerTranslations.byLanguage[language]?.get(key)
                assertNotNull(
                    "$key missing a $language translation — if intentional, add it to latinAndEnglishOnlyPrayerKeys",
                    text,
                )
            }
        }
    }

    /** Guards the allowlist itself from going stale: if a key gets translated into one of the 4
     * languages, this should start failing as a reminder to remove it from the allowlist above
     * rather than leaving a passing-but-inaccurate entry. */
    @Test
    fun allowlistedPrayerKeysAreStillMissingFromTheExpectedLanguages() {
        for (key in latinAndEnglishOnlyPrayerKeys) {
            for (language in fullyTranslatedLanguages) {
                assertNull(
                    "$key now has a $language translation — remove it from latinAndEnglishOnlyPrayerKeys",
                    PrayerTranslations.byLanguage[language]?.get(key),
                )
            }
        }
    }

    @Test
    fun everyMysteryImageKeyHasLatinAndEnglishTranslations() {
        for (imageKey in allMysteryImageKeys) {
            for (language in listOf("la", "en")) {
                val text = MysteryTranslations.byLanguage[language]?.get(imageKey)
                assertNotNull("$imageKey missing a $language translation", text)
            }
        }
    }

    @Test
    fun everyMysteryImageKeyExceptTheKnownAllowlistHasAllSixLanguages() {
        for (imageKey in allMysteryImageKeys) {
            if (imageKey in latinAndEnglishOnlyMysteryImageKeys) continue
            for (language in fullyTranslatedLanguages) {
                val text = MysteryTranslations.byLanguage[language]?.get(imageKey)
                assertNotNull(
                    "$imageKey missing a $language translation — if intentional, add it to latinAndEnglishOnlyMysteryImageKeys",
                    text,
                )
            }
        }
    }

    @Test
    fun allowlistedMysteryImageKeysAreStillMissingFromTheExpectedLanguages() {
        for (imageKey in latinAndEnglishOnlyMysteryImageKeys) {
            for (language in fullyTranslatedLanguages) {
                assertNull(
                    "$imageKey now has a $language translation — remove it from latinAndEnglishOnlyMysteryImageKeys",
                    MysteryTranslations.byLanguage[language]?.get(imageKey),
                )
            }
        }
    }
}
