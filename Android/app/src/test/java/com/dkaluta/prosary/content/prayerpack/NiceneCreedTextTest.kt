package com.dkaluta.prosary.content.prayerpack

import com.dkaluta.prosary.content.CreedPolicy
import com.dkaluta.prosary.content.NiceneCreedText
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.models.BasicPrayerCatalog
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.*
import org.junit.After
import org.junit.Assert.*
import org.junit.Test

class NiceneCreedTextTest {
    private val key = "symbolumNicaenum"
    private val latin = "qui ex Patre Filioque procedit"
    private val hebrew = "הַו דּמֶן אַבָא ובא ננפֶק"
    private val syriac = "ܗܰܘ ܕ݁ܡܶܢ ܐܰܒܳܐ ܘܒܐ ܢܢܦܶܩ"
    private data class Fixture(val text: String, val aid: String? = null, val policy: CreedPolicy? = null, val apostles: String? = null)

    @After fun restore() {
        PrayerPackStore.resetForTesting()
        PrayerPackStore.initialize { name -> File("src/main/assets/$name.prosaryprayer").takeIf { it.exists() }?.inputStream() }
    }

    @Test fun retiredToggleCannotAlterEitherSourcePolicyOrInitializeANewChoice() {
        load(mapOf("la" to Fixture(latin, policy = CreedPolicy(true, "unbracketed"))))
        AppSettings.includeFilioque = false
        AppSettings.initializeFilioqueFromSelection("el")
        assertEquals(latin, PrayerPackStore.resolveBodyText("rosary", "la", key))
        assertNull(AppSettings.includeFilioqueChoice)
        AppSettings.includeFilioque = true
        assertEquals(latin, PrayerPackStore.resolveBodyText("rosary", "la", key))
        assertNull(AppSettings.includeFilioqueChoice)
    }

    @Test fun actualFallbackSourceOwnsThePolicyRatherThanTheRequestedLanguage() {
        load(mapOf("la" to Fixture(latin, policy = CreedPolicy(true, "unbracketed"))))
        assertEquals(latin, PrayerPackStore.resolveBodyText("rosary", "el", key))
        assertFalse(PrayerPackStore.usesNiceneCreed("rosary", "el"))
        load(mapOf("arc" to Fixture(hebrew, syriac, CreedPolicy(false, "bracketed"))))
        assertTrue(PrayerPackStore.usesNiceneCreed("rosary", "arc"))
        assertEquals("הַו דּמֶן אַבָא [ובא] ננפֶק", PrayerPackStore.resolveBodyText("rosary", "arc", key))
        assertEquals("ܗܰܘ ܕ݁ܡܶܢ ܐܰܒܳܐ [ܘܒܐ] ܢܢܦܶܩ", PrayerPackStore.transliteration("rosary", "arc", key))
    }

    @Test fun unknownAndUntaggedImportsRetainExactWordingAndReadingAid() {
        load(mapOf("arc" to Fixture(hebrew, syriac)))
        assertEquals(hebrew, PrayerPackStore.resolveBodyText("rosary", "arc", key))
        assertEquals(syriac, PrayerPackStore.transliteration("rosary", "arc", key))
        assertNotNull(BasicPrayerCatalog.prayer("creed", "arc"))
        assertFalse(PrayerPackStore.usesNiceneCreed("rosary", "arc"))
        assertEquals("Unrecognized sourced body", NiceneCreedText.applyingPolicy(key, "Unrecognized sourced body", CreedPolicy(false, "absent")))
    }

    @Test fun unavailableApostlesEntryStaysHiddenWhileLegacyRosaryStepsUseSameSourceNicene() {
        load(mapOf("uk" to Fixture("що від Отця [і Сина] ісходить", policy = CreedPolicy(false, "bracketed"), apostles = "Historical Apostles body"),
            "la" to Fixture(latin, policy = CreedPolicy(true, "unbracketed"), apostles = "Latin Apostles body")))
        assertNull(BasicPrayerCatalog.prayer("creed", "uk"))
        assertTrue(PrayerPackStore.usesNiceneCreed("rosary", "uk"))
        assertFalse(PrayerPackStore.usesNiceneCreed("rosary", "la"))
        assertNotNull(BasicPrayerCatalog.prayer("niceneCreed", "uk"))
        assertEquals("що від Отця [і Сина] ісходить", PrayerPackStore.resolveBodyText("rosary", "uk", "symbolumApostolorum"))
        assertEquals("що від Отця [і Сина] ісходить", com.dkaluta.prosary.content.PrayerTranslations.get("uk", com.dkaluta.prosary.content.PrayerKey.SymbolumApostolorum))
        assertEquals("Nicene source title", PrayerPackStore.resolveBodyText("rosary", "uk", "symbolumApostolorumTitle"))
        assertEquals("Latin Apostles body", PrayerPackStore.resolveBodyText("rosary", "la", "symbolumApostolorum"))
        assertNotNull(BasicPrayerCatalog.prayer("creed", "la"))
    }

    @Test fun unavailableEasternCreedNeverFallsThroughToALatinApostlesBody() {
        load(mapOf("arc" to Fixture(hebrew, policy = CreedPolicy(false, "bracketed")),
            "la" to Fixture(latin, policy = CreedPolicy(true, "unbracketed"), apostles = "Latin Apostles body")))
        assertNull(BasicPrayerCatalog.prayer("creed", "arc"))
        assertEquals("הַו דּמֶן אַבָא [ובא] ננפֶק", PrayerPackStore.resolveBodyText("rosary", "arc", "symbolumApostolorum"))
    }

    @Test fun missionAndUkrainianBracketOnlyTheSuppliedProcessionPhrase() {
        val mission = "אֲשֶׁר נֶאֱצַל מִן הָאָב (וּמִן הַבֵּן). ועם הבן נעבד"
        assertEquals("אֲשֶׁר נֶאֱצַל מִן הָאָב [וּמִן הַבֵּן]. ועם הבן נעבד", NiceneCreedText.applyingPolicy(key, mission, CreedPolicy(false, "bracketed")))
        val ukrainian = "що від Отця [і Сина] ісходить"
        assertEquals(ukrainian, NiceneCreedText.applyingPolicy(key, ukrainian, CreedPolicy(false, "bracketed")))
        assertEquals("що від Отця ісходить", NiceneCreedText.applyingPolicy(key, ukrainian, CreedPolicy(false, "absent")))
        assertEquals("що від Отця і Сина ісходить", NiceneCreedText.applyingPolicy(key, ukrainian, CreedPolicy(false, "unbracketed")))
    }

    @Test fun omittedGreekSourceAndUnrelatedFatherSonTextCannotGainInventedClauses() {
        val greek = "τὸ ἐκ τοῦ Πατρὸς ἐκπορευόμενον"
        assertEquals(greek, NiceneCreedText.applyingPolicy(key, greek, CreedPolicy(false, "unbracketed")))
        assertEquals(latin, NiceneCreedText.applyingPolicy("anotherPrayer", latin, CreedPolicy(false, "absent")))
        assertEquals("qui ex Patre procedit", NiceneCreedText.applyingPolicy(key, "qui ex Patre procedit", CreedPolicy(true, "unbracketed")))
    }

    @Test fun sharedEasternCreedKeepsItsSourceBodyAidAndPolicyAfterItsPackIsRemoved() {
        val baseContents = mapOf("la" to Fixture(latin, policy = CreedPolicy(true, "unbracketed"), apostles = "Latin Apostles body"))
        load(baseContents)
        val withoutImportedCreed = PrayerPackStore.resolveBodyText("otherDevotion", "arc", "symbolumApostolorum")
        val directory = java.nio.file.Files.createTempDirectory("prosary-creed-removal").toFile()
        PrayerPackStore.installedPacksDirectory = directory
        try {
            val sourceId = "importedEasternCreed"
            PrayerPackStore.installPack(pack(sourceId, mapOf("arc" to
                Fixture(hebrew, syriac, CreedPolicy(false, "bracketed"), "Historical Apostles body"))))
            val consumerId = "otherDevotion"
            PrayerPackStore.installPack(archive(mapOf(
                "manifest.json" to """{"id":"$consumerId","displayName":"Other Devotion","languages":["arc"],"hasCatalog":false}""",
                "devotion.json" to """{"type":"steps","steps":[{"title":"Creed","bodyKey":"symbolumApostolorum"}]}""",
                "content/arc.json" to """{"prayers":{"otherBody":"Other sourced prayer"}}""",
            )))
            // A later Nicene-only override cannot replace the legacy key's authored source.
            PrayerPackStore.installPack(pack("otherCreedSource", mapOf("arc" to Fixture("Another sourced Nicene body"))))
            val prayer = com.dkaluta.prosary.models.Prayer(kind = com.dkaluta.prosary.models.PrayerKind.Custom,
                languageCode = "arc", customDevotionId = consumerId)
            fun assertSameSourceCreed() {
                val step = com.dkaluta.prosary.engine.PrayerEngine().buildSteps(prayer).single()
                assertEquals("הַו דּמֶן אַבָא [ובא] ננפֶק", step.body)
                assertEquals("ܗܰܘ ܕ݁ܡܶܢ ܐܰܒܳܐ [ܘܒܐ] ܢܢܦܶܩ", step.transliteratedBody)
                assertTrue(PrayerPackStore.usesNiceneCreed(consumerId, "arc"))
            }
            assertSameSourceCreed()
            PrayerPackStore.removeInstalledPack(sourceId)
            assertFalse(File(directory, "$sourceId.prosaryprayer").exists())
            assertNull(PrayerPackStore.info(sourceId))
            assertSameSourceCreed()

            // The retained override is process-local and disappears on the next catalog load.
            PrayerPackStore.resetForTesting()
            PrayerPackStore.installedPacksDirectory = directory
            val base = pack("rosary", baseContents)
            PrayerPackStore.initialize { if (it == "rosary") base.inputStream() else null }
            val reloaded = com.dkaluta.prosary.engine.PrayerEngine().buildSteps(prayer).single()
            assertEquals(withoutImportedCreed, reloaded.body)
            assertNull(reloaded.transliteratedBody)
        } finally {
            directory.deleteRecursively()
        }
    }

    private fun load(contents: Map<String, Fixture>) {
        val bytes = pack("rosary", contents)
        PrayerPackStore.resetForTesting()
        PrayerPackStore.initialize { name -> if (name == "rosary") bytes.inputStream() else null }
    }

    private fun pack(id: String, contents: Map<String, Fixture>): ByteArray = archive(buildMap {
        val builtin = if (id == "rosary") "\"builtinKind\":\"rosary\"," else ""
        put("manifest.json", """{"id":"$id",${builtin}"displayName":"Fixture","languages":${Json.encodeToString(contents.keys.toList())},"hasCatalog":false}""")
        put("devotion.json", """{"type":"steps","steps":[{"titleKey":"symbolumApostolorumTitle","bodyKey":"symbolumApostolorum"}]}""")
        contents.forEach { (language, fixture) -> put("content/$language.json", buildJsonObject {
            put("prayers", buildJsonObject {
                put(key, fixture.text); put("symbolumNicaenumTitle", "Nicene source title")
                fixture.apostles?.let { put("symbolumApostolorum", it); put("symbolumApostolorumTitle", "Apostles source title") }
            })
            fixture.aid?.let { put("transliterations", buildJsonObject { put(key, it) }) }
            fixture.policy?.let { put("\$creedPolicy", Json.encodeToJsonElement(it)) }
        }.toString()) }
    })

    private fun archive(entries: Map<String, String>): ByteArray {
        val bytes = ByteArrayOutputStream()
        ZipOutputStream(bytes).use { zip ->
            entries.forEach { (name, text) -> zip.putNextEntry(ZipEntry(name)); zip.write(text.toByteArray()); zip.closeEntry() }
        }
        return bytes.toByteArray()
    }
}
