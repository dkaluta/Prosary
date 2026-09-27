package com.dkaluta.prosary.ui.theme

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.platform.LocalContext
import com.dkaluta.prosary.models.AppColor
import com.dkaluta.prosary.models.AppSettings

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

internal fun appColorScheme(color: AppColor, isDark: Boolean): ColorScheme {
    val primary = Color(if (isDark) color.dark else color.light)
    val onPrimary = if (isDark) Color.Black else Color.White
    val container = lerp(primary, if (isDark) Color.Black else Color.White, if (isDark) 0.75f else 0.88f)
    val onContainer = if (isDark) Color.White else lerp(primary, Color.Black, 0.25f)
    val base = if (isDark) darkColorScheme() else lightColorScheme()
    return base.copy(
        primary = primary, onPrimary = onPrimary,
        primaryContainer = container, onPrimaryContainer = onContainer,
        secondary = primary, onSecondary = onPrimary,
        secondaryContainer = container, onSecondaryContainer = onContainer,
        tertiary = primary, onTertiary = onPrimary,
        tertiaryContainer = container, onTertiaryContainer = onContainer,
        inversePrimary = Color(if (isDark) color.light else color.dark),
        surfaceTint = primary,
    )
}

@Composable
fun ProsaryTheme(content: @Composable () -> Unit) {
    val isDark = isSystemInDarkTheme()
    val colorScheme = if (Build.VERSION.SDK_INT >= 31 && AppSettings.useSystemColors) {
        val context = LocalContext.current
        if (isDark) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
    } else appColorScheme(AppColor.resolve(AppSettings.appColor), isDark)
    val extraColors = ProsaryExtraColors(
        headline = colorScheme.primary,
        beadCurrent = colorScheme.primary,
    )

    CompositionLocalProvider(LocalProsaryExtraColors provides extraColors) {
        MaterialTheme(
            colorScheme = colorScheme,
            typography = ProsaryTypography,
            content = content,
        )
    }
}
