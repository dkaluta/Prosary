package com.dkaluta.prosary

import com.dkaluta.prosary.content.audio.PrayerSpeechText
import com.dkaluta.prosary.content.prayerpack.DevotionAudioTrack
import kotlinx.serialization.json.Json
import org.junit.Assert.*
import org.junit.Test

class PrayerSpeechTextTest {
    @Test fun matchesPrayerLanguageWithoutSubstitutingLatinOrAramaic() {
        assertTrue(PrayerSpeechText.voiceMatches("en-GB", "en"))
        assertTrue(PrayerSpeechText.voiceMatches("he-IL", "he-x-gamliel"))
        assertTrue(PrayerSpeechText.voiceMatches("iw-IL", "he"))
        assertTrue(PrayerSpeechText.voiceMatches("fil-PH", "tl"))
        assertFalse(PrayerSpeechText.voiceMatches("en-US", "la"))
        assertFalse(PrayerSpeechText.voiceMatches("he-IL", "arc"))
        assertFalse(PrayerSpeechText.voiceMatches("en-US", ""))
    }

    @Test fun longTextFitsNativeLimitWithoutBreakingUnicodeOrLosingWords() {
        val original = "**" + List(80) { "Response 🔥." }.joinToString(" ") + "**"
        val chunks = PrayerSpeechText.chunks(original, 73)
        assertTrue(chunks.size > 1)
        assertTrue(chunks.all { it.length <= 73 })
        assertEquals(original.replace("**", ""), chunks.joinToString(" "))
        assertTrue(chunks.none { it.last().isHighSurrogate() || it.first().isLowSurrogate() })
        val unbroken = "🔥".repeat(20)
        assertEquals(unbroken, PrayerSpeechText.chunks(unbroken, 7).joinToString(""))
        assertEquals(emptyList<String>(), PrayerSpeechText.chunks(" \n ", 10))
    }

    @Test fun legacyAudioStaysNarrationAndMusicHasNoPrayerStepHints() {
        val legacy = Json.decodeFromString<DevotionAudioTrack>("""{"id":"en","language":"en","file":"audio/en.opus","chapters":[{"start":0,"title":"Opening","stepIndex":0}]}""")
        assertTrue(legacy.isNarration)
        val music = Json.decodeFromString<DevotionAudioTrack>("""{"id":"song","language":"en","file":"audio/song.opus","role":"music","chapters":[{"start":0,"title":"Opening song"}]}""")
        assertTrue(music.isMusic)
        assertFalse(music.isNarration)
        assertNull(music.chapters.first().stepIndex)
    }

    @Test fun hebrewDivineNamesAreSpokenAsAdonaiOrElohim() {
        assertEquals("אֲדֹנָי לְעֶזְרָתִי חוּשָׁה", PrayerSpeechText.spokenText("ה׳ לְעֶזְרָתִי חוּשָׁה", "he"))
        assertEquals("שִׁפְחַת אֲדֹנָי", PrayerSpeechText.spokenText("שִׁפְחַת ה׳", "he"))
        assertEquals("הִנֵּה יָמִים בָּאִים נְאֻם־אֲדֹנָי", PrayerSpeechText.spokenText("הִנֵּה יָמִים בָּאִים נְאֻם־יהוה", "he"))
        assertEquals("כֹּה אָמַר אֲדֹנָי אֱלֹהִים", PrayerSpeechText.spokenText("כֹּה אָמַר אֲדֹנָי יהוה", "he"))
        assertEquals("אדני אֱלֹהִים", PrayerSpeechText.spokenText("אדני יהוה", "he"))
        assertEquals("אֲדֹנָי וֵאלֹהִים", PrayerSpeechText.spokenText("אֲדֹנָי וַיהוה", "he"))
        assertEquals("לַאדֹנָי הָאָרֶץ", PrayerSpeechText.spokenText("לַיהוה הָאָרֶץ", "he"))
        assertEquals("בַּאדֹנָי חָסִיתִי", PrayerSpeechText.spokenText("בַּיהוה חָסִיתִי", "he"))
        assertEquals("וַאדֹנָי צִוָּה", PrayerSpeechText.spokenText("וַיהוה צִוָּה", "he"))
        assertEquals("מֵאדֹנָי", PrayerSpeechText.spokenText("מֵיהוה", "he"))
        assertEquals("לַאדֹנָי", PrayerSpeechText.spokenText("לַה׳", "he"))
        assertEquals("אֲדֹנָי", PrayerSpeechText.spokenText("יי", "he"))
        assertEquals("וַאדֹנָי", PrayerSpeechText.spokenText("וַיי", "he"))
        assertEquals("הוֹדוּ לַאדֹנָי כִּי־טוֹב", PrayerSpeechText.spokenText("הוֹדוּ לַיהוָה כִּי־טוֹב", "he"))
    }
}
