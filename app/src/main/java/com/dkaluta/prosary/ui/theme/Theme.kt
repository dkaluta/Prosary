package com.dkaluta.prosary.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color

/** Brand colors with no Material3 color-role equivalent, mirroring the iOS asset catalog's
 * BrandHeadline and BeadCurrent named colors. */
data class ProsaryExtraColors(
    val headline: Color,
    val beadCurrent: Color,
)

private val LocalProsaryExtraColors = staticCompositionLocalOf {
    ProsaryExtraColors(headline = BrandHeadlineLight, beadCurrent = BeadCurrentLight)
}

val MaterialTheme.extraColors: ProsaryExtraColors
    @Composable get() = LocalProsaryExtraColors.current

private val LightColors = lightColorScheme(
    primary = BrandPrimaryLight,
    onPrimary = Color.White,
    secondary = BrandPrimaryLight,
)

private val DarkColors = darkColorScheme(
    primary = BrandPrimaryDark,
    onPrimary = Color.Black,
    secondary = BrandPrimaryDark,
)

@Composable
fun ProsaryTheme(content: @Composable () -> Unit) {
    val isDark = isSystemInDarkTheme()
    val colorScheme = if (isDark) DarkColors else LightColors
    val extraColors = if (isDark) {
        ProsaryExtraColors(headline = BrandHeadlineDark, beadCurrent = BeadCurrentDark)
    } else {
        ProsaryExtraColors(headline = BrandHeadlineLight, beadCurrent = BeadCurrentLight)
    }

    CompositionLocalProvider(LocalProsaryExtraColors provides extraColors) {
        MaterialTheme(
            colorScheme = colorScheme,
            typography = ProsaryTypography,
            content = content,
        )
    }
}
