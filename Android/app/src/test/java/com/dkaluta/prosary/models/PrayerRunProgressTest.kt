package com.dkaluta.prosary.models

import java.time.LocalDate
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PrayerRunProgressTest {
    private val today = LocalDate.of(2026, 9, 3)

    @Test
    fun anInterruptedMiddleStepCanResume() {
        val run = PrayerRunProgress(stepIndex = 8, languageCode = "he", savedLocalDate = today.toString())
        assertTrue(run.canResume(stepCount = 40, today = today))
    }

    @Test
    fun anUnstartedOrOutOfRangeRunDoesNotResume() {
        assertFalse(PrayerRunProgress(0, "en", today.toString()).canResume(40, today))
        assertFalse(PrayerRunProgress(40, "en", today.toString()).canResume(40, today))
    }

    @Test
    fun aRosaryContinuationExpiresAtTheLocalDayBoundary() {
        val run = PrayerRunProgress(stepIndex = 8, languageCode = "arc", savedLocalDate = today.toString())
        assertFalse(run.canResume(stepCount = 40, today = today.plusDays(1), sameLocalDayOnly = true))
    }

    @Test
    fun anotherDevotionMayContinueOnAFollowingDay() {
        val run = PrayerRunProgress(stepIndex = 8, languageCode = "arc", savedLocalDate = today.toString())
        assertTrue(run.canResume(stepCount = 40, today = today.plusDays(1), sameLocalDayOnly = false))
    }

    @Test
    fun aChangedOrLegacyConfigurationDoesNotResumeIntoANewSequence() {
        val current = "rosary|current"
        val run = PrayerRunProgress(
            stepIndex = 8,
            languageCode = "he",
            savedLocalDate = today.toString(),
            configurationSignature = current,
        )
        assertTrue(run.canResume(40, today, expectedConfigurationSignature = current))
        assertFalse(run.canResume(40, today, expectedConfigurationSignature = "rosary|changed"))

        val legacy = PrayerRunProgress(8, "he", today.toString())
        assertFalse(legacy.canResume(40, today, expectedConfigurationSignature = current))
    }

    @Test
    fun signaturesCoverSequenceOptionsAndSortCustomOverrides() {
        assertEquals(
            "rosary|todaysMysteries|joyful|1|1|1|0|1|none|seasonal|0|0|1|formA|0|classic",
            PrayerRunSignatures.rosary(RosaryOptions()),
        )
        assertFalse(
            PrayerRunSignatures.rosary(RosaryOptions()) ==
                PrayerRunSignatures.rosary(RosaryOptions(includeOpeningFatimaPrayer = true)),
        )
        assertEquals(
            "custom|stations|scriptural|2|alpha=1|zeta=2",
            PrayerRunSignatures.custom(
                devotionId = "stations",
                effectiveVariantId = "scriptural",
                dayIndex = 2,
                options = linkedMapOf("zeta" to "2", "alpha" to "1"),
            ),
        )
        assertFalse(
            PrayerRunSignatures.custom("trisagion", "byzantine", 0, emptyMap()) ==
                PrayerRunSignatures.custom("trisagion", "syriac", 0, emptyMap()),
        )
        assertEquals("jesus|count|33", PrayerRunSignatures.jesus(JesusPrayerTarget.Count(33)))
        assertEquals("jesus|unbounded", PrayerRunSignatures.jesus(JesusPrayerTarget.Unbounded))
    }

    @Test
    fun reorderedOpeningFatimaInvalidatesOnlyRunsThatIncludeIt() {
        val options = RosaryOptions(includeOpeningFatimaPrayer = true, includeClosingIntentions = true)
        val current = PrayerRunSignatures.rosary(options)
        assertTrue(current.endsWith("|closing-v2:1,1,1|opening-fatima-v2"))
        val previous = current.removeSuffix("|opening-fatima-v2")
        val run = PrayerRunProgress(6, "en", today.toString(), previous)
        assertFalse(run.canResume(100, today, expectedConfigurationSignature = current))
        assertTrue(run.copy(configurationSignature = current).canResume(100, today, expectedConfigurationSignature = current))
        assertFalse(PrayerRunSignatures.rosary(options.copy(includeOpeningPrayers = false)).contains("opening-fatima-v2"))
        assertFalse(PrayerRunSignatures.rosary(options.copy(includeOpeningFatimaPrayer = false)).contains("opening-fatima-v2"))
    }

    @Test
    fun customRosarySignaturesNormalizeLegacyGroupsAndRejectChangedSequences() {
        fun signature(options: Map<String, String>, devotionId: String = "rosary") =
            PrayerRunSignatures.custom(devotionId, null, 0, options)

        assertEquals("custom|rosary||0|", signature(emptyMap()))
        val current = signature(mapOf("closingIntentions" to "true", "openingFatimaPrayer" to "true"))
        assertEquals(
            "custom|rosary||0|closingIntentions=true|openingFatimaPrayer=true|closing-v2:1,1,1|opening-fatima-v2",
            current,
        )
        assertEquals(current, signature(mapOf("closingPopeIntention" to "true", "openingFatimaPrayer" to "true")))
        val previous = "custom|rosary||0|closingIntentions=true|openingFatimaPrayer=true"
        assertFalse(PrayerRunProgress(8, "en", today.toString(), previous)
            .canResume(100, today, expectedConfigurationSignature = current))
        val allOff = RosaryOptions.legacyClosingIntentionKeys.associateWith { "false" } +
            ("closingIntentions" to "true")
        assertEquals(signature(mapOf("closingIntentions" to "false")), signature(allOff))
        assertFalse(signature(mapOf("openingPrayers" to "false", "openingFatimaPrayer" to "true"))
            .contains("opening-fatima-v2"))
        assertEquals(
            "custom|foreignRosary||0|closingPopeIntention=true|openingFatimaPrayer=true",
            signature(mapOf("closingPopeIntention" to "true", "openingFatimaPrayer" to "true"), "foreignRosary"),
        )
    }

    @Test
    fun runKeysSeparateRosariesCustomFormsAndJesusTargets() {
        assertEquals("rosary:preset-id", PrayerRunKeys.rosary("preset-id"))
        assertEquals(
            "custom:stationsOfTheCross:scriptural:2",
            PrayerRunKeys.custom("stationsOfTheCross", "scriptural", 2),
        )
        assertEquals("custom:angelus::0", PrayerRunKeys.custom("angelus", null, 0))
        assertEquals(
            "jesus:unbounded",
            PrayerRunKeys.jesus(null, JesusPrayerTarget.Unbounded),
        )
        assertEquals(
            "jesus:saved-id",
            PrayerRunKeys.jesus("saved-id", JesusPrayerTarget.Count(33)),
        )
    }

    @Test
    fun languageSwitchOnlyKeepsPositionWhenTheEffectiveFormStaysTheSame() {
        assertEquals(
            4,
            CustomDevotionLanguageSwitch.indexAfterSwitch(4, "byzantine", "byzantine", 6),
        )
        assertEquals(
            0,
            CustomDevotionLanguageSwitch.indexAfterSwitch(4, "byzantine", "syriac", 4),
        )
    }
}
