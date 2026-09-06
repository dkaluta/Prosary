package com.dkaluta.prosary.ui.shared

import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.LayoutDirection
import com.dkaluta.prosary.models.LanguageCatalog

/** Navigation follows the interface even while the prayer body uses another script. */
object PrayerNavigation {
    fun direction(appLanguage: String): LayoutDirection =
        if (LanguageCatalog.uiLanguageCode(appLanguage).substringBefore('-') in setOf("he", "ar"))
            LayoutDirection.Rtl else LayoutDirection.Ltr
    fun iconScale(direction: LayoutDirection): Float = if (direction == LayoutDirection.Rtl) -1f else 1f
}

@Composable
fun InterfaceNavigation(content: @Composable () -> Unit) {
    val locale = LocalConfiguration.current.locales[0].toLanguageTag()
    CompositionLocalProvider(LocalLayoutDirection provides PrayerNavigation.direction(locale), content = content)
}
