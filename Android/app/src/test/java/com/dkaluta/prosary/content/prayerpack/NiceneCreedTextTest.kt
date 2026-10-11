package com.dkaluta.prosary.content.prayerpack

import com.dkaluta.prosary.content.NiceneCreedText
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.models.BasicPrayerCatalog
import com.dkaluta.prosary.models.LanguageCatalog
import com.dkaluta.prosary.models.Prayer
import com.dkaluta.prosary.models.PrayerKind
import com.dkaluta.prosary.engine.PrayerEngine
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream
import kotlinx.serialization.json.*
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.Assert.*

class NiceneCreedTextTest {
    private var savedChoice: Boolean? = null
    private var savedOrder = emptyList<String>()
    private val key = "symbolumNicaenum"
    private val latin = "qui ex Patre Filioque procedit"
    private val greek = "τὸ ἐκ τοῦ Πατρὸς ἐκπορευόμενον"
    private val hebrew = "הַו דּמֶן אַבָא ובא ננפֶק"
    private val syriac = "ܗܰܘ ܕ݁ܡܶܢ ܐܰܒܳܐ ܘܒܐ ܢܢܦܶܩ"

    @Before fun setUp() {
        savedChoice = AppSettings.includeFilioqueChoice
        savedOrder = AppSettings.languageFallbackOrder
        AppSettings.restoreFilioqueForTesting(null)
        AppSettings.setLanguageFallbackOrder(listOf("el", "arc", "la"))
        PrayerPackStore.resetForTesting()
    }

    @After fun tearDown() {
        AppSettings.restoreFilioqueForTesting(savedChoice)
        AppSettings.setLanguageFallbackOrder(savedOrder)
        PrayerPackStore.resetForTesting()
        PrayerPackStore.initialize { name -> File("src/main/assets/$name.prosaryprayer").takeIf(File::exists)?.inputStream() }
    }

    @Test fun aRequestedGreekCreedInitializesFromItsActualLatinFallback() {
        load(mapOf("la" to (latin to null)))
        assertEquals(latin, PrayerPackStore.resolveBodyText("creedFixture", "el", key))
        assertEquals(true, AppSettings.includeFilioqueChoice)
        AppSettings.includeFilioque = false
        assertEquals("qui ex Patre procedit", PrayerPackStore.resolveBodyText("creedFixture", "el", key))
        AppSettings.includeFilioque = true
        assertEquals(latin, PrayerPackStore.resolveBodyText("creedFixture", "el", key))
    }

    @Test fun emptyAppSettingSentinelUsesTheWinningSourceRatherThanTheInheritedLanguageLabel() {
        val savedDefault = AppSettings.defaultLanguageCode
        try {
            AppSettings.setDefaultLanguageCode("el")
            load(mapOf("la" to (latin to null)))
            assertEquals(latin, PrayerPackStore.resolveBodyText("creedFixture", "", key))
            assertEquals(true, AppSettings.includeFilioqueChoice)
        } finally {
            AppSettings.setDefaultLanguageCode(savedDefault)
        }
    }

    @Test fun bookmarkAndWidgetValidationCannotChooseTheFirstRiteBeforeTheReaderOpens() {
        load(mapOf("el" to (greek to null), "la" to (latin to null)))
        val engine = PrayerEngine()
        val greekPrayer = Prayer(kind = PrayerKind.Custom, customDevotionId = "creedFixture", languageCode = "el")
        assertEquals(greek, engine.buildSteps(greekPrayer, initializeFilioque = false).single().body)
        assertNull(AppSettings.includeFilioqueChoice)

        // A discarded Greek candidate must not turn Filioque off in the Latin session.
        val latinPrayer = greekPrayer.copy(languageCode = "la")
        assertEquals(latin, engine.buildSteps(latinPrayer, initializeFilioque = false).single().body)
        assertNull(AppSettings.includeFilioqueChoice)
        assertEquals(latin, engine.buildSteps(latinPrayer).single().body)
        assertEquals(true, AppSettings.includeFilioqueChoice)
    }

    @Test fun shippedVicariateNiceneBodyKeepsTheExactSuppliedTextWithoutInventingAReadingAid() {
        val fixture = Json.parseToJsonElement(File("../../Shared/tools/fixtures/nicene-creed.json").readText()).jsonObject
        val supplied = fixture.getValue("hebrewVicariate").jsonObject.getValue("text").jsonPrimitive.content
        val apostles = fixture.getValue("existingApostlesHebrew").jsonPrimitive.content
        val includedClause = "הַנּוֹבֵעַ מֵהָאָב וּמֵהַבֵּן"
        assertTrue(supplied.contains(includedClause))
        assertEquals(java.text.Normalizer.normalize(supplied, java.text.Normalizer.Form.NFC), supplied)
        PrayerPackStore.initialize { name -> File("src/main/assets/$name.prosaryprayer").takeIf(File::exists)?.inputStream() }
        val prayer = requireNotNull(BasicPrayerCatalog.prayer("niceneCreed"))

        val included = BasicPrayerCatalog.step(prayer, "he")
        assertEquals(supplied, included.body)
        assertTrue(included.body.contains(includedClause))
        assertEquals(true, AppSettings.includeFilioqueChoice)
        assertNull(included.transliteratedBody)
        assertFalse(included.body.contains('['))
        assertFalse(included.body.contains(']'))

        AppSettings.includeFilioque = false
        val omitted = BasicPrayerCatalog.step(prayer, "he")
        val suppliedWithoutFilioque = supplied.replace(includedClause, "הַנּוֹבֵעַ מֵהָאָב")
        assertNotEquals(supplied, suppliedWithoutFilioque)
        assertEquals(suppliedWithoutFilioque, omitted.body)
        assertNull(omitted.transliteratedBody)
        assertEquals(apostles, BasicPrayerCatalog.step(requireNotNull(BasicPrayerCatalog.prayer("creed")), "he").body)

        AppSettings.includeFilioque = true
        assertEquals(supplied, BasicPrayerCatalog.step(prayer, "he").body)
        assertNull(PrayerPackStore.transliteration("rosary", "he", key))
        assertEquals(apostles, BasicPrayerCatalog.step(requireNotNull(BasicPrayerCatalog.prayer("creed")), "he").body)
    }

    @Test fun greekSourceKeepsItsWordingAndItsFirstDefaultSurvivesLatinFallback() {
        load(mapOf("el" to (greek to null), "la" to (latin to null)))
        assertEquals(greek, PrayerPackStore.resolveBodyText("creedFixture", "el", key))
        assertEquals(false, AppSettings.includeFilioqueChoice)
        assertEquals("qui ex Patre procedit", PrayerPackStore.resolveBodyText("creedFixture", "la", key))
        AppSettings.includeFilioque = true
        assertEquals(greek, PrayerPackStore.resolveBodyText("creedFixture", "el", key))
    }

    @Test fun bothAramaicScriptsFollowTheWinningSourceWithoutBorrowingAnotherAid() {
        load(mapOf("arc" to (hebrew to syriac), "la" to (latin to "Unrelated aid")))
        AppSettings.includeFilioque = false
        assertEquals("הַו דּמֶן אַבָא ננפֶק", PrayerPackStore.resolveBodyText("creedFixture", "el", key))
        assertEquals("ܗܰܘ ܕ݁ܡܶܢ ܐܰܒܳܐ ܢܢܦܶܩ", PrayerPackStore.transliteration("creedFixture", "el", key))
        AppSettings.includeFilioque = true
        assertEquals(hebrew, PrayerPackStore.resolveBodyText("creedFixture", "arc", key))
        assertEquals(syriac, PrayerPackStore.transliteration("creedFixture", "arc", key))
        load(mapOf("arc" to (hebrew to null), "la" to (latin to "Unrelated aid")))
        assertNull(PrayerPackStore.transliteration("creedFixture", "arc", key))
    }

    @Test fun missionParenthesesDisappearAndWorshipOfTheSonRemains() {
        val procession = "אֲשֶׁר נֶאֱצַל מִן הָאָב (וּמִן הַבֵּן)"
        val worship = "לו סוגדים ולו נותנים יקר כלאב וכלבן"
        val source = "$procession. $worship"
        assertEquals("אֲשֶׁר נֶאֱצַל מִן הָאָב וּמִן הַבֵּן. $worship", NiceneCreedText.applying(key, source, true))
        assertEquals("אֲשֶׁר נֶאֱצַל מִן הָאָב. $worship", NiceneCreedText.applying(key, source, false))
        val vicariate = "הנובע מהאב [ומהבן]. $worship"
        assertEquals("הנובע מהאב ומהבן. $worship", NiceneCreedText.applying(key, vicariate, true))
        assertEquals("הנובע מהאב. $worship", NiceneCreedText.applying(key, vicariate, false))
    }

    @Test fun pointedVicariateProcessionKeepsEverySuppliedPointOutsideTheOmittedPhrase() {
        val canonical = "הַנּוֹבֵעַ מֵהָאָב וּמֵהַבֵּן"
        val priorCombiningOrder = "הַנּוֹבֵעַ מֵהָאָב וּמֵהַבֵּן"
        assertNotEquals(canonical, priorCombiningOrder)
        assertEquals(java.text.Normalizer.normalize(priorCombiningOrder, java.text.Normalizer.Form.NFC), canonical)
        for (clause in listOf(canonical, priorCombiningOrder)) {
            val source = "בֵּ $clause. כלאב וכלבן"
            assertEquals(true, NiceneCreedText.statusQuo(key, source))
            assertEquals(source, NiceneCreedText.applying(key, source, true))
            assertEquals("בֵּ הַנּוֹבֵעַ מֵהָאָב. כלאב וכלבן", NiceneCreedText.applying(key, source, false))
        }
        assertEquals(false, NiceneCreedText.statusQuo(key, "הַנּוֹבֵעַ מֵהָאָב"))

        val source = "רוח הקדש $canonical. כלאב וכלבן"
        load(mapOf("he" to (source to null)))
        assertEquals(source, PrayerPackStore.resolveBodyText("creedFixture", "he", key))
        assertEquals(true, AppSettings.includeFilioqueChoice)
        AppSettings.includeFilioque = false
        assertEquals("רוח הקדש הַנּוֹבֵעַ מֵהָאָב. כלאב וכלבן", PrayerPackStore.resolveBodyText("creedFixture", "he", key))
    }

    @Test fun ordinaryApostlesAndUnknownBodiesRemainUnchangedAndDoNotInitialize() {
        val apostles = "I believe in God, the Father almighty, and in Jesus Christ, his only Son."
        assertNull(NiceneCreedText.statusQuo("symbolumApostolorum", apostles))
        assertEquals(apostles, NiceneCreedText.applying("symbolumApostolorum", apostles, false))
        assertEquals(latin, NiceneCreedText.applying("anotherPrayer", latin, false))
        load(mapOf("la" to ("Unrecognized sourced body" to null)))
        assertEquals("Unrecognized sourced body", PrayerPackStore.resolveBodyText("creedFixture", "la", key))
        assertNull(AppSettings.includeFilioqueChoice)
    }

    @Test fun niceneCreedHasAnIndependentCatalogEntryImmediatelyAfterTheExistingCreed() {
        val prayer = requireNotNull(BasicPrayerCatalog.prayer("niceneCreed"))
        assertEquals("rosary", prayer.bundleId)
        assertEquals(key, prayer.bodyKey)
        assertEquals("symbolumNicaenumTitle", prayer.titleKey)
        val preceding = BasicPrayerCatalog.all.indexOfFirst { it.id == "creed" }
        assertEquals(prayer, BasicPrayerCatalog.all[preceding + 1])
        assertEquals("symbolumApostolorum", BasicPrayerCatalog.prayer("creed")!!.bodyKey)
    }

    private fun load(contents: Map<String, Pair<String, String?>>) {
        val bytes = ByteArrayOutputStream()
        ZipOutputStream(bytes).use { zip ->
            fun add(name: String, text: String) {
                zip.putNextEntry(ZipEntry(name)); zip.write(text.toByteArray()); zip.closeEntry()
            }
            add("manifest.json", buildJsonObject {
                put("schemaVersion", 1); put("id", "creedFixture"); put("kind", "creedFixture")
                put("displayName", "Fixture"); put("languages", JsonArray(contents.keys.map(::JsonPrimitive)))
                put("hasCatalog", false)
            }.toString())
            add("devotion.json", """{"type":"steps","steps":[{"title":"Fixture","bodyKey":"$key"}]}""")
            for ((language, pair) in contents) add("content/$language.json", buildJsonObject {
                put("prayers", buildJsonObject { put(key, pair.first) })
                pair.second?.let { aid -> put("transliterations", buildJsonObject { put(key, aid) }) }
            }.toString())
        }
        PrayerPackStore.resetForTesting()
        PrayerPackStore.initialize { name -> if (name == "rosary") bytes.toByteArray().inputStream() else null }
    }
}
