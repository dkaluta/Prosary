package com.dkaluta.prosary.content

import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.sp
import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.typography.HebrewDisplayText
import com.dkaluta.prosary.typography.PrayerTypography
import java.io.File
import java.io.ByteArrayOutputStream
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import org.junit.Assert.*
import org.junit.BeforeClass
import org.junit.Test

class AramaicPrayerTitleTest {
    companion object {
        @BeforeClass @JvmStatic fun loadPacks() {
            PrayerPackStore.initialize { name ->
                File("src/main/assets/$name.prosaryprayer").takeIf(File::exists)?.inputStream()
            }
        }
    }

    @Test fun allSourcedRosaryAndTrisagionHeadingsFollowBothDisplayedScripts() {
        val titles = mapOf(
            "rosary" to listOf("signumCrucisTitle", "symbolumApostolorumTitle", "paterNosterTitle",
                "aveMariaTitle", "gloriaPatriTitle", "subTuumPraesidiumTitle"),
            "trisagion" to listOf("trisagionAcclamationTitle", "trisagionKyrieTitle", "gloriaPatriTitle"),
        )
        for ((bundle, keys) in titles) for (key in keys) {
            val pointed = PrayerPackStore.resolveBodyText(bundle, "arc", key)
            val hebrew = HebrewDisplayText.unpoint(pointed)
            val syriac = requireNotNull(PrayerPackStore.transliteration(bundle, "arc", key))
            for (input in listOf(pointed, hebrew, syriac)) {
                assertEquals("$bundle/$key", syriac, PrayerTranslations.flowTitle(input, "arc", true, bundle))
                assertEquals("$bundle/$key", hebrew, PrayerTranslations.flowTitle(input, "arc", false, bundle))
            }
        }
        // A generic bundle using a shared prayer receives the Rosary's exact sourced pair.
        val shared = PrayerPackStore.resolveBodyText("rosary", "arc", "paterNosterTitle")
        assertEquals(PrayerPackStore.transliteration("rosary", "arc", "paterNosterTitle"),
            PrayerTranslations.flowTitle(shared, "arc", true, "angelus"))
    }

    @Test fun repeatedTitlesKeepTheNumbersAndUseTheMatchingSourcedConnector() {
        val hebrew = HebrewDisplayText.unpoint(PrayerPackStore.resolveBodyText("rosary", "arc", "aveMariaTitle"))
        val syriac = requireNotNull(PrayerPackStore.transliteration("rosary", "arc", "aveMariaTitle"))
        assertEquals("$syriac (3 ܡܶܢ 10)", PrayerTranslations.flowTitle("$hebrew (3 מן 10)", "arc", true))
        assertEquals("$hebrew (3 מן 10)", PrayerTranslations.flowTitle("$syriac (3 ܡܶܢ 10)", "arc", false))
        assertEquals("Unknown heading (3 ܡܶܢ 10)", PrayerTranslations.flowTitle("Unknown heading (3 מן 10)", "arc", true))
    }

    @Test fun unsupportedAndUnrelatedTitlesArePreserved() {
        val known = HebrewDisplayText.unpoint(PrayerPackStore.resolveBodyText("rosary", "arc", "paterNosterTitle"))
        for (title in listOf("Salve Regina", "A custom prayer", "$known — personal copy", "$known (evening)")) {
            assertEquals(title, PrayerTranslations.flowTitle(title, "arc", true))
            assertEquals(title, PrayerTranslations.flowTitle(title, "arc", false))
        }
        assertEquals(known, PrayerTranslations.flowTitle(known, "he", true))
        assertEquals(known, PrayerTranslations.flowTitle(known, "en", true))
        val localOnly = HebrewDisplayText.unpoint(PrayerPackStore.resolveBodyText("rosary", "arc", "subTuumPraesidiumTitle"))
        assertEquals(localOnly, PrayerTranslations.flowTitle(localOnly, "arc", true, "angelus"))
    }

    @Test fun importedLocalKeysSupportReversedPairsAndKeepUnpairedOverridesLocal() {
        val hebrew = PrayerPackStore.resolveBodyText("trisagion", "arc", "trisagionAcclamationTitle")
        val syriac = requireNotNull(PrayerPackStore.transliteration("trisagion", "arc", "trisagionAcclamationTitle"))
        val unpaired = PrayerPackStore.resolveBodyText("rosary", "arc", "gloriaPatriTitle")
        val bytes = ByteArrayOutputStream()
        ZipOutputStream(bytes).use { zip ->
            fun add(path: String, text: String) {
                zip.putNextEntry(ZipEntry(path)); zip.write(text.toByteArray()); zip.closeEntry()
            }
            add("manifest.json", """{"schemaVersion":1,"id":"arc-title-fixture","kind":"arc-title-fixture","displayName":"Fixture","languages":["arc"],"hasCatalog":false}""")
            add("devotion.json", """{"type":"steps","steps":[{"titleKey":"customHeading","bodyKey":"customHeading"}]}""")
            add("content/arc.json", buildJsonObject {
                put("prayers", buildJsonObject { put("customHeading", syriac); put("gloriaPatriTitle", unpaired) })
                put("transliterations", buildJsonObject { put("customHeading", hebrew) })
            }.toString())
        }
        try {
            PrayerPackStore.resetForTesting()
            PrayerPackStore.initialize { name ->
                when (name) {
                    "rosary" -> File("src/main/assets/rosary.prosaryprayer").inputStream()
                    "angelus" -> bytes.toByteArray().inputStream()
                    else -> null
                }
            }
            assertEquals(HebrewDisplayText.unpoint(hebrew), PrayerTranslations.flowTitle(syriac, "arc", false, "arc-title-fixture"))
            assertEquals(syriac, PrayerTranslations.flowTitle(hebrew, "arc", true, "arc-title-fixture"))
            assertEquals(HebrewDisplayText.unpoint(unpaired), PrayerTranslations.flowTitle(unpaired, "arc", true, "arc-title-fixture"))
            assertEquals(syriac, PrayerTranslations.flowTitle(syriac, "arc", false, "unrelated-bundle"))
        } finally {
            PrayerPackStore.resetForTesting()
            loadPacks()
        }
    }

    @Test fun syriacHeadingsUseTheChosenFaceWithoutChangingNativeHeadingSize() {
        val previous = AppSettings.syriacTypeface
        val base = TextStyle(fontSize = 22.sp, lineHeight = 28.sp)
        val title = requireNotNull(PrayerPackStore.transliteration("rosary", "arc", "paterNosterTitle"))
        try {
            for (face in listOf(AppSettings.TYPEFACE_DEFAULT, AppSettings.TYPEFACE_WESTERN, AppSettings.TYPEFACE_EASTERN)) {
                AppSettings.setSyriacTypeface(face)
                val heading = PrayerTypography.headingStyleForText(title, base)
                assertEquals(PrayerTypography.styleForText(title, false).fontFamily, heading.fontFamily)
                assertEquals(base.fontSize, heading.fontSize)
                assertEquals(base.lineHeight, heading.lineHeight)
            }
            assertEquals(base, PrayerTypography.headingStyleForText("צלותא מרניתא", base))
            assertEquals(base, PrayerTypography.headingStyleForText("Our Father", base))
        } finally { AppSettings.setSyriacTypeface(previous) }
    }
}
