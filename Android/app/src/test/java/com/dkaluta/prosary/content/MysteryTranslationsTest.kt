package com.dkaluta.prosary.content

import com.dkaluta.prosary.content.prayerpack.MysteryTextOverride
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class MysteryTranslationsTest {
    private val imageKey = "joyful_01_annunciation"

    @Test
    fun aramaicDescriptionAndItsSyriacTransliterationKeepFallbackTitleAndFruit() {
        val aramaic = MysteryTextOverride(
            description = "הָא מַלַאכָא אֶתָא לוָת מַריַם.",
            transliteratedDescription = "ܗܳܐ ܡܰܠܰܐܟ݂ܳܐ ܐܶܬ݂ܳܐ ܠܘܳܬ݂ ܡܰܪܝܰܡ.",
        )
        val english = MysteryText(
            title = "The Annunciation",
            fruit = "Humility",
            description = "The angel came to Mary.",
            transliteratedDescription = "must not win",
        )

        val resolved = MysteryTranslations.resolve(
            chain = listOf("arc", "en", "la"),
            imageKey = imageKey,
            overrideAt = { code, _ -> aramaic.takeIf { code == "arc" } },
            completeAt = { code, _ -> english.takeIf { code == "en" } },
        )

        assertEquals("The Annunciation", resolved.title)
        assertEquals("Humility", resolved.fruit)
        assertEquals(aramaic.description, resolved.description)
        assertEquals(aramaic.transliteratedDescription, resolved.transliteratedDescription)
    }

    @Test
    fun transliterationNeverFallsThroughSeparatelyFromItsDescription() {
        val resolved = MysteryTranslations.resolve(
            chain = listOf("arc", "en"),
            imageKey = imageKey,
            overrideAt = { code, _ ->
                when (code) {
                    "arc" -> MysteryTextOverride(description = "Peshitta")
                    "en" -> MysteryTextOverride(
                        description = "English",
                        transliteratedDescription = "English alternate script",
                    )
                    else -> null
                }
            },
            completeAt = { _, _ -> null },
        )

        assertEquals("Peshitta", resolved.description)
        assertNull(resolved.transliteratedDescription)
    }

    @Test
    fun sourceNativeHebrewCitationKeepsGematriaAndHasNoColon() {
        val description = "וַיְהִי הַדָּבָר׃\n\n— יוחנן ג׳ 16–17 (דליטש)"
        val resolved = MysteryTranslations.resolve(
            chain = listOf("he", "en"),
            imageKey = imageKey,
            overrideAt = { code, _ ->
                MysteryTextOverride(description = description).takeIf { code == "he" }
            },
            completeAt = { _, _ -> null },
        )

        assertTrue(resolved.description.endsWith("— יוחנן ג׳ 16–17 (דליטש)"))
        assertFalse(resolved.description.contains("ג׳:"))
    }

    @Test
    fun hardcodedCitationRangesUseEnDashesInEveryLanguage() {
        val asciiRange = Regex("""\d-\d""")
        for ((language, mysteries) in MysteryTranslations.byLanguage) {
            for ((key, mystery) in mysteries) {
                assertFalse(
                    "$language/$key still uses an ASCII citation-range hyphen",
                    asciiRange.containsMatchIn(mystery.description),
                )
            }
        }
    }

    @Test
    fun laterSparseMysteryContributionsDoNotEraseEarlierFields() {
        val earlier = MysteryTextOverride(
            title = "Earlier title",
            description = "Earlier description",
            transliteratedDescription = "Earlier transliteration",
        )
        val merged = earlier.mergedWith(
            MysteryTextOverride(title = "Later title", fruit = "Later fruit"),
        )

        assertEquals("Later title", merged.title)
        assertEquals("Later fruit", merged.fruit)
        assertEquals("Earlier description", merged.description)
        assertEquals("Earlier transliteration", merged.transliteratedDescription)

        val replaced = earlier.mergedWith(
            MysteryTextOverride(description = "Later description"),
        )
        assertEquals("Later description", replaced.description)
        assertEquals(null, replaced.transliteratedDescription)
    }
}
