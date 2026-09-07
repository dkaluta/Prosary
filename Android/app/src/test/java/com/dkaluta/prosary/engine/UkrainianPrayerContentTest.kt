package com.dkaluta.prosary.engine

import com.dkaluta.prosary.calendar.MockLiturgicalCalendar
import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import com.dkaluta.prosary.models.*
import com.dkaluta.prosary.typography.PrayerTypography
import java.io.File
import org.junit.Assert.*
import org.junit.After
import org.junit.Before
import org.junit.BeforeClass
import org.junit.Test

class UkrainianPrayerContentTest {
    companion object {
        @BeforeClass @JvmStatic fun loadPacks() {
            PrayerPackStore.initialize { name -> File("src/main/assets/$name.prosaryprayer").takeIf(File::exists)?.inputStream() }
        }
    }
    private var savedFallback = emptyList<String>()
    @Before fun saveFallback() {
        savedFallback = LanguageCatalog.fallbackOrder
        AppSettings.setLanguageFallbackOrder(listOf("en", "he", "la"))
    }
    @After fun restoreFallback() { AppSettings.setLanguageFallbackOrder(savedFallback) }

    private fun steps(bundle: String, variant: String? = null) = PrayerEngine(MockLiturgicalCalendar()).buildSteps(
        Prayer(kind = PrayerKind.Custom, languageCode = "uk", customDevotionId = bundle, variantId = variant),
    )

    @Test fun allBasicPrayersUseTheSourcedUkrainianTitleAndBody() {
        val titles = listOf("Знак хреста", "Отче наш", "Радуйся, Маріє", "Слава Отцю", "Апостольський символ віри", "Святий Боже")
        for ((prayer, title) in BasicPrayerCatalog.all.zip(titles)) {
            val step = BasicPrayerCatalog.step(prayer, "uk")
            assertEquals(prayer.id, title, step.title)
            assertEquals(prayer.id, PrayerTypography.Script.Cyrillic, PrayerTypography.scriptOf(step.body))
            assertNotEquals(step.body, BasicPrayerCatalog.step(prayer, "en").body)
        }
    }

    @Test fun ukrainianDevotionsRenderTextInsteadOfUnresolvedKeys() {
        val rawKey = Regex("^[a-z][A-Za-z0-9]*$")
        for (bundle in listOf("divineMercyChaplet", "angelus", "oAntiphons", "sevenSorrows")) {
            val rendered = steps(bundle)
            assertTrue(bundle, rendered.isNotEmpty())
            assertTrue(bundle, rendered.any { PrayerTypography.scriptOf(it.body) == PrayerTypography.Script.Cyrillic })
            for (step in rendered) {
                assertFalse(step.title, rawKey.matches(step.title))
                assertFalse(step.body, rawKey.matches(step.body))
            }
        }
    }

    @Test fun scripturalStationsUseUkrainianAndMissingMeditationsFollowTheSelectedFallback() {
        val scriptural = steps("stationsOfTheCross", "scriptural")
        assertEquals("Ісус у Гетсиманському саду", scriptural[2].title)
        assertTrue(scriptural[2].body.startsWith("І приходять на врочище Гетсиман"))
        assertTrue(scriptural[2].body.contains("Марко 14:32–36"))
        assertTrue(scriptural[2].isScripture)
        val english = PrayerPackStore.resolveBodyText("stationsOfTheCross", "en", "station01Body")
        assertNotEquals("station01Body", english)
        assertEquals(english, PrayerPackStore.resolveBodyText("stationsOfTheCross", "uk", "station01Body"))
        assertTrue(steps("stationsOfTheCross", "traditional")[2].body.contains(english))
    }
}
