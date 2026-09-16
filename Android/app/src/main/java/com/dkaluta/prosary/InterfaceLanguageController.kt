package com.dkaluta.prosary

import android.content.Context
import android.content.res.Configuration
import android.os.Build
import android.os.LocaleList
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.os.LocaleListCompat
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.models.InterfaceLanguage
import java.util.Locale

/** Android owns locale persistence/recreation, including its system per-app language picker. */
object InterfaceLanguageController {
    fun synchronize(context: Context) {
        val selected = AppCompatDelegate.getApplicationLocales()[0]?.toLanguageTag().orEmpty()
        AppSettings.setInterfaceLanguageCode(selected)
        AppSettings.updateEffectiveInterfaceLanguage((0 until context.resources.configuration.locales.size()).map {
            context.resources.configuration.locales[it].toLanguageTag()
        })
    }

    fun select(code: String) {
        AppSettings.setInterfaceLanguageCode(code)
        AppCompatDelegate.setApplicationLocales(LocaleListCompat.forLanguageTags(InterfaceLanguage.platformCode(code)))
    }

    /** AppCompat applies locales to activities before Android 13; widgets need the same resources. */
    fun localizedContext(context: Context): Context {
        if (Build.VERSION.SDK_INT >= 33) return context
        val selected = InterfaceLanguage.platformCode(context.getSharedPreferences("prosary_settings", Context.MODE_PRIVATE)
            .getString(InterfaceLanguage.preferenceKey, "").orEmpty())
        if (selected.isEmpty()) return context
        val locale = Locale.forLanguageTag(selected)
        return context.createConfigurationContext(Configuration(context.resources.configuration).apply {
            setLocales(LocaleList(locale))
            setLayoutDirection(locale)
        })
    }
}
