package com.dkaluta.prosary.models

import androidx.compose.ui.graphics.Color
import org.junit.Assert.*
import org.junit.Test

class CustomAccentColorTest {
    @Test fun validColorsNormalizeAndMalformedInputsUseNoCustomOverride() {
        assertEquals("#A1B2C3", CustomAccentColor.normalize(" a1b2c3 "))
        assertEquals("#A1B2C3", CustomAccentColor.normalize("#a1b2c3"))
        for (input in listOf("", "#fff", "#FF112233", "zz1122", "#1234567")) {
            assertEquals("", CustomAccentColor.normalize(input))
            assertNull(CustomAccentColor.color(input))
        }
    }

    @Test fun whiteBlackAndSaturatedAccentsRemainReadableAcrossBothNativeThemes() {
        for (hex in listOf("#FFFFFF", "#000000", "#FFFF00", "#0000FF", "#00FF00", "#FF0000", "#888888")) {
            val raw = requireNotNull(CustomAccentColor.color(hex))
            for (dark in listOf(false, true)) {
                val accent = CustomAccentColor.readableAccent(raw, dark)
                val surface = if (dark) Color(0xFF141218) else Color(0xFFFFFBFE)
                assertTrue("$hex dark=$dark", CustomAccentColor.contrast(accent, surface) >= 4.5f)
                assertTrue(CustomAccentColor.contrast(accent, CustomAccentColor.foreground(accent)) >= 4.5f)
            }
        }
    }
}
