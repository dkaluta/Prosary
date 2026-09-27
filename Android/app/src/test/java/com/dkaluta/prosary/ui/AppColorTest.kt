package com.dkaluta.prosary.ui

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import com.dkaluta.prosary.models.AppColor
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.ui.theme.appColorScheme
import org.junit.Assert.*
import org.junit.Test

class AppColorTest {
    @Test fun absentOrUnknownPaletteUsesBlueAndSelectionsAreStable() {
        assertEquals(AppColor.Blue, AppColor.resolve(null))
        assertEquals(AppColor.Blue, AppColor.resolve("old-color"))
        val previous = AppSettings.appColor
        try {
            for (color in AppColor.entries) {
                AppSettings.setAppColor(color.id)
                assertEquals(color.id, AppSettings.appColor)
            }
            AppSettings.setAppColor("not-a-color")
            assertEquals("blue", AppSettings.appColor)
        } finally { AppSettings.setAppColor(previous) }
    }

    @Test fun everyManualPaletteKeepsTextAndControlsLegibleInBothAppearances() {
        fun contrast(first: Color, second: Color): Float {
            val a = first.luminance() + 0.05f
            val b = second.luminance() + 0.05f
            return maxOf(a, b) / minOf(a, b)
        }
        for (color in AppColor.entries) for (dark in listOf(false, true)) {
            val scheme = appColorScheme(color, dark)
            assertEquals(Color(if (dark) color.dark else color.light), scheme.primary)
            for ((foreground, background) in listOf(
                scheme.onPrimary to scheme.primary,
                scheme.onSecondary to scheme.secondary,
                scheme.onTertiary to scheme.tertiary,
                scheme.onPrimaryContainer to scheme.primaryContainer,
                scheme.onSecondaryContainer to scheme.secondaryContainer,
                scheme.onTertiaryContainer to scheme.tertiaryContainer,
                scheme.primary to scheme.surface,
            )) {
                assertTrue("$color, dark=$dark: ${contrast(foreground, background)}", contrast(foreground, background) >= 4.5f)
            }
        }
        assertEquals(Color(0xFF8B681B), appColorScheme(AppColor.White, false).primary)
    }
}
