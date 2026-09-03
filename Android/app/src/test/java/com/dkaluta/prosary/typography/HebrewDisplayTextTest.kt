package com.dkaluta.prosary.typography

import org.junit.Assert.assertEquals
import org.junit.Test

class HebrewDisplayTextTest {
    @Test
    fun removesNiqqudAndCantillationButKeepsHebrewPunctuation() {
        assertEquals(
            "בשורת־יוחנן ג׳ 16–17׃ נ",
            HebrewDisplayText.unpoint("בְּשׂוֹרַ֨ת־יוֹחָנָן ג׳ 16–17׃ נ"),
        )
    }

    @Test
    fun leavesOtherScriptsUntouched() {
        assertEquals(
            "Glória Patri — ܫܽܘܒܚܳܐ",
            HebrewDisplayText.unpoint("Glória Patri — ܫܽܘܒܚܳܐ"),
        )
    }
}
