package com.dkaluta.prosary.widgets

import android.content.Context
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.models.BasicPrayerCatalog
import com.dkaluta.prosary.models.LanguageCatalog
import com.dkaluta.prosary.ui.shared.DevotionDirectory

/** Source identities are re-resolved from installed content whenever a widget updates. */
internal data class WidgetPrayerChoice(val identity: String, val title: String, val subtitle: String? = null) {
    val templatePath: String? get() = identity.split(':', limit = 2).takeIf {
        it.size == 2 && it[0] in setOf("devotion", "basic")
    }?.let { "template/${it[0]}/${it[1]}" }
}

internal object CatalogWidgetPrayers {
    fun all(context: Context): List<WidgetPrayerChoice> {
        val interfaceLanguage = context.resources.configuration.locales[0].toLanguageTag()
        val basicLanguage = LanguageCatalog.resolve(AppSettings.basicPrayersLanguageCode).code
        return DevotionDirectory.all(context).map {
            WidgetPrayerChoice("devotion:${it.id}", it.title, it.interfaceTitle)
        } + BasicPrayerCatalog.all.map {
            val title = BasicPrayerCatalog.cardTitle(it, basicLanguage, interfaceLanguage)
            WidgetPrayerChoice("basic:${it.id}", title.primary, title.interfaceSubtitle)
        }
    }
}
