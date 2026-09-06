package com.dkaluta.prosary.typography

import org.junit.Assert.*
import org.junit.Test

class SystemSansFontProbeTest {
    @Test fun stockRobotoAndNotoAreRecognizedButOtherFamiliesAreNot() {
        assertEquals(true, SystemSansFontProbe.matchesFontFiles(listOf("Roboto-Regular.ttf"), "Roboto"))
        assertEquals(true, SystemSansFontProbe.matchesFontFiles(listOf("RobotoFlex-Regular.ttf"), "Roboto"))
        assertEquals(true, SystemSansFontProbe.matchesFontFiles(listOf("NotoSansHebrew-Regular.ttf"), "NotoSansHebrew"))
        assertEquals(false, SystemSansFontProbe.matchesFontFiles(listOf("SamsungOne.ttf"), "Roboto"))
        assertEquals(false, SystemSansFontProbe.matchesFontFiles(listOf("RobotoSerif-Regular.ttf"), "Roboto"))
        assertEquals(false, SystemSansFontProbe.matchesFontFiles(listOf("Roboto-Regular.ttf", "Decorative.ttf"), "Roboto"))
    }

    @Test fun unidentifiableFontsKeepTheFallbackAvailable() {
        assertNull(SystemSansFontProbe.matchesFontFiles(emptyList(), "Roboto"))
        assertNull(SystemSansFontProbe.matchesFontFiles(listOf(null), "Roboto"))
        assertTrue(SystemSansFontProbe.shouldOfferBundledFont(null, false))
        assertTrue(SystemSansFontProbe.shouldOfferBundledFont(false, false))
        assertFalse(SystemSansFontProbe.shouldOfferBundledFont(true, false))
    }

    @Test fun anExistingSelectionNeverDisappearsAfterADeviceFontChange() {
        assertTrue(SystemSansFontProbe.shouldOfferBundledFont(true, true))
    }
}
