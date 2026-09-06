package com.dkaluta.prosary.content.prayerpack

import com.dkaluta.prosary.content.MysteryTranslations
import com.dkaluta.prosary.content.PrayerKey
import com.dkaluta.prosary.content.PrayerTranslations
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.models.LanguageCatalog
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream
import kotlinx.serialization.json.*
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.Assert.*

/** Synthetic source labels deliberately distinguish traditions, generic repository wording,
 * and reading aids without inventing any prayer text. Every fixture uses the actual ZIP loader. */
class HebrewPrayerPriorityTest {
    private lateinit var savedOrder: List<String>
    private lateinit var savedDefault: String
    private lateinit var savedBasic: String
    private val mission = "he-x-gamliel"
    private val vicariate = LanguageCatalog.hebrewVicariateContentCode
    private val target = "priorityFixture"

    @Before fun setUp() {
        savedOrder = AppSettings.languageFallbackOrder
        savedDefault = AppSettings.defaultLanguageCode
        savedBasic = AppSettings.basicPrayersLanguageCode
        AppSettings.setDefaultLanguageCode("en")
        order(mission, "arc", "he")
        PrayerPackStore.resetForTesting()
    }

    @After fun tearDown() {
        AppSettings.setLanguageFallbackOrder(savedOrder)
        AppSettings.setDefaultLanguageCode(savedDefault)
        AppSettings.setBasicPrayersLanguageCode(savedBasic)
        PrayerPackStore.resetForTesting()
        PrayerPackStore.initialize { name -> File("src/main/assets/$name.prosaryprayer").takeIf { it.exists() }?.inputStream() }
    }

    private fun order(vararg codes: String) = AppSettings.setLanguageFallbackOrder(
        codes.toList() + LanguageCatalog.all.map { it.code }.filter { it !in codes && it != "la" } + "la",
    )

    private fun content(
        text: String,
        aid: String? = null,
        marked: Boolean = false,
        key: String = "oratioFatimae",
    ): String = buildJsonObject {
        put("prayers", buildJsonObject { put(key, text) })
        if (aid != null) put("transliterations", buildJsonObject { put(key, aid) })
        if (marked) put("\$prayerTraditionByKey", buildJsonObject { put(key, "vicariate") })
    }.toString()

    private fun pack(id: String, languages: List<String>, contents: Map<String, String>): ByteArray {
        val bytes = ByteArrayOutputStream()
        ZipOutputStream(bytes).use { zip ->
            fun add(name: String, text: String) {
                zip.putNextEntry(ZipEntry(name)); zip.write(text.toByteArray()); zip.closeEntry()
            }
            add("manifest.json", buildJsonObject {
                put("schemaVersion", 1); put("id", id); put("kind", id); put("displayName", id)
                put("languages", JsonArray(languages.map(::JsonPrimitive))); put("hasCatalog", false)
            }.toString())
            add("devotion.json", """{"type":"steps","steps":[{"title":"Fixture","bodyKey":"oratioFatimae"}]}""")
            contents.forEach { (language, text) -> add("content/$language.json", text) }
        }
        return bytes.toByteArray()
    }

    private fun load(
        local: Map<String, String>,
        shared: Map<String, String> = emptyMap(),
        laterShared: Map<String, String> = emptyMap(),
        declared: List<String> = listOf("he", "arc", "en"),
    ) {
        PrayerPackStore.resetForTesting()
        val packs = mapOf(
            "rosary" to pack("rosary", shared.keys.toList(), shared),
            "angelus" to pack(target, declared, local),
            "stationsOfTheCross" to pack("laterFixture", laterShared.keys.toList(), laterShared),
        )
        PrayerPackStore.initialize { packs[it]?.inputStream() }
    }

    private fun body(key: String = "oratioFatimae") = PrayerPackStore.resolveBodyText(target, "fr", key)
    private fun aid(key: String = "oratioFatimae") = PrayerPackStore.transliteration(target, "fr", key)

    @Test fun rawPriorityAndContentProbesKeepBothTraditionSlots() {
        assertEquals(listOf("fr", mission, "arc", "he"), LanguageCatalog.fallbackChain("fr").take(4))
        assertEquals(listOf("fr", mission, "he", "arc", vicariate), LanguageCatalog.contentFallbackChain("fr").take(5))
        assertEquals(1, LanguageCatalog.contentFallbackChain("fr").count { it == "he" })
        order("he", "arc", mission)
        assertEquals(listOf("fr", "he", "arc", mission), LanguageCatalog.fallbackChain("fr").take(4))
        assertEquals(listOf("fr", vicariate, "he", "arc", mission), LanguageCatalog.contentFallbackChain("fr").take(5))
        assertEquals(listOf("tl-ph", "tl"), LanguageCatalog.fallbackChain("fil-PH").take(2))
    }

    @Test fun specificTraditionsRespectBothPriorityOrdersAndKeepTheirOwnAids() {
        load(mapOf(
            "he" to content("Vicariate wording", "Vicariate aid", marked = true),
            mission to content("Mission wording", "Mission aid"),
            "arc" to content("Aramaic wording", "Aramaic aid"),
        ), shared = mapOf("he" to content("Generic Hebrew wording", "Generic Hebrew aid")))
        assertEquals("Mission wording", body()); assertEquals("Mission aid", aid())
        order("he", "arc", mission)
        assertEquals("Vicariate wording", body()); assertEquals("Vicariate aid", aid())
    }

    @Test fun genericHebrewSharedBodyOccupiesTheHigherHebrewSlot() {
        load(mapOf(
            "he" to content("Vicariate wording", "Vicariate aid", marked = true),
            "arc" to content("Aramaic wording", "Aramaic aid"),
        ), shared = mapOf("he" to content("Generic Hebrew wording", "Generic Hebrew aid")))
        assertEquals("Generic Hebrew wording", body()); assertEquals("Generic Hebrew aid", aid())
        order("he", "arc", mission)
        assertEquals("Vicariate wording", body()); assertEquals("Vicariate aid", aid())
    }

    @Test fun missingGenericHebrewFallsToAramaicBeforeTheLowerVicariateSlot() {
        load(mapOf(
            "he" to content("Vicariate wording", "Vicariate aid", marked = true),
            "arc" to content("Aramaic wording", "Aramaic aid"),
        ))
        assertEquals("Aramaic wording", body()); assertEquals("Aramaic aid", aid())
        assertEquals("arc", PrayerPackStore.effectiveLanguage(target, "fr"))
        order("he", "arc", mission)
        assertEquals("he", PrayerPackStore.effectiveLanguage(target, "fr"))
        assertEquals("Vicariate wording", body())
    }

    @Test fun genericRepositoryHebrewRemainsGenericAndMapsToItsOriginatingHebrewSelection() {
        load(mapOf("he" to content("Repository Hebrew wording", "Repository Hebrew aid", key = "repositoryText"),
            "arc" to content("Aramaic wording", "Aramaic aid", key = "repositoryText")))
        assertEquals("Repository Hebrew wording", body("repositoryText"))
        assertEquals("Repository Hebrew aid", aid("repositoryText"))
        assertEquals(mission, PrayerPackStore.effectiveLanguage(target, "fr"))
        order("he", "arc", mission)
        assertEquals("he", PrayerPackStore.effectiveLanguage(target, "fr"))
        assertEquals("Repository Hebrew wording", body("repositoryText"))
    }

    @Test fun nativeVicariateSharedKeyWinsBeforeGenericHebrewWhenItsSlotIsFirst() {
        load(mapOf("he" to content("Generic Hebrew wording", "Generic Hebrew aid")))
        assertEquals("Generic Hebrew wording", body())
        assertEquals("Generic Hebrew aid", aid())
        order("he", "arc", mission)
        assertEquals(PrayerTranslations.byLanguage.getValue(vicariate)[PrayerKey.OratioFatimae], body())
        assertNull("Native text cannot borrow the generic source's reading aid", aid())
    }

    @Test fun genericHebrewOverlayAlsoServesAnExplicitMissionDeclaration() {
        load(mapOf("he" to content("Generic repository text", key = "repositoryText")), declared = listOf(mission))
        assertEquals(mission, PrayerPackStore.effectiveLanguage(target, "fr"))
        assertEquals("Generic repository text", body("repositoryText"))
    }

    @Test fun missingAidCannotBorrowFromAnotherTraditionOrLaterGlobalOverride() {
        load(mapOf(
            "he" to content("Vicariate wording", "Vicariate aid", marked = true),
            mission to content("Mission wording"),
            "arc" to content("Local Aramaic wording", "Local Aramaic aid"),
        ), laterShared = mapOf("arc" to content("Other Aramaic wording", "Other Aramaic aid")))
        assertEquals("Mission wording", body()); assertNull(aid())
        order("arc", mission, "he")
        assertEquals("Local Aramaic wording", body()); assertEquals("Local Aramaic aid", aid())
        assertEquals("Other Aramaic wording", PrayerTranslations.get("arc", PrayerKey.OratioFatimae))
        assertEquals("Other Aramaic aid", PrayerPackStore.transliteration("missingBundle", "arc", "oratioFatimae"))
    }

    @Test fun fallbackProbeChecksLocalPrayerBeforeNativeSharedTextAndSharesTitlesAtThatProbe() {
        load(mapOf("he" to content("Specific local wording", marked = true),
            "arc" to content("Local Aramaic wording")),
            shared = mapOf("arc" to content("Shared Aramaic title", key = "gloriaPatriTitle")))
        assertEquals("Local Aramaic wording", body())
        assertEquals("Shared Aramaic title", body("gloriaPatriTitle"))
        assertNull(aid())
    }

    @Test fun genericMysteriesStayAtTheFirstHebrewSlotWithoutSpecificPrayerLeakage() {
        load(mapOf("he" to """{"prayers":{"oratioFatimae":"Vicariate wording"},"${'$'}prayerTraditionByKey":{"oratioFatimae":"vicariate"},"mysteries":{"priorityMystery":{"title":"Generic title","description":"Generic description","transliteratedDescription":"Generic description aid"}}}""",
            "arc" to content("Aramaic wording")))
        val mystery = MysteryTranslations.get("fr", "priorityMystery")
        assertEquals("Generic title", mystery.title)
        assertEquals("Generic description", mystery.description)
        assertEquals("Generic description aid", mystery.transliteratedDescription)
        assertEquals("Aramaic wording", body())
    }

    @Test fun effectiveLanguageDoesNotPromoteUndeclaredGreekOverlayButKeepsMissionOverlay() {
        load(mapOf("he" to content("Vicariate wording", marked = true),
            "arc" to content("Aramaic wording"), "el" to content("Greek overlay"),
            mission to content("Mission overlay")))
        order("el", "arc", "he", mission)
        assertEquals("arc", PrayerPackStore.effectiveLanguage(target, "fr"))
        assertEquals("Greek overlay", body())
        assertEquals(mission, PrayerPackStore.effectiveLanguage(target, mission))
    }

    @Test fun internalVicariateProbeCannotBeSelectedOrPersisted() {
        assertFalse(LanguageCatalog.all.any { it.code == vicariate })
        assertFalse(LanguageCatalog.availableOptions(listOf("he")).any { it.code == vicariate })
        AppSettings.setDefaultLanguageCode(vicariate)
        AppSettings.setBasicPrayersLanguageCode(vicariate)
        AppSettings.setLanguageFallbackOrder(listOf(vicariate, mission, "arc", "he", "la"))
        assertEquals("he", AppSettings.defaultLanguageCode)
        assertEquals("he", AppSettings.basicPrayersLanguageCode)
        assertFalse(vicariate in AppSettings.languageFallbackOrder)
        assertFalse(vicariate in LanguageCatalog.fallbackChain("he"))
    }

    @Test fun nativeHebrewTablesSeparateSpecificPrayersFromThreeGenericMetadataKeys() {
        val generic = setOf(PrayerKey.DecadeOrdinalFormat, PrayerKey.RepetitionCounterConnector, PrayerKey.FructusMysteriiLabel)
        assertEquals(generic, PrayerTranslations.byLanguage.getValue("he").keys)
        assertTrue(PrayerKey.AveMaria in PrayerTranslations.byLanguage.getValue(vicariate))
        assertFalse(PrayerKey.AveMaria in PrayerTranslations.byLanguage.getValue("he"))
    }
}
