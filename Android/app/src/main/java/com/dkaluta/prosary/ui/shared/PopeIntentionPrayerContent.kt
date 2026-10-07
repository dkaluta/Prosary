package com.dkaluta.prosary.ui.shared

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import com.dkaluta.prosary.R
import com.dkaluta.prosary.content.today.TodayInfoStore
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.models.LanguageCatalog
import com.dkaluta.prosary.models.RosaryStep
import com.dkaluta.prosary.content.today.PopeIntention

data class PopeIntentionPrayerPublication(
    val languageCode: String, val title: String, val text: String, val translationCredit: String?,
) {
    companion object {
        fun resolve(step: RosaryStep, intention: PopeIntention?, language: String,
            isEnabled: Boolean = false): PopeIntentionPrayerPublication? {
            if (!isEnabled || step.prayerKey != "intentioPontificis" || intention == null) return null
            val normalized = LanguageCatalog.uiLanguageCode(language)
            val requested = LanguageCatalog.baseLanguage(normalized) ?: normalized
            val complete = !intention.titleByLanguage?.get(requested).isNullOrBlank() &&
                !intention.textByLanguage?.get(requested).isNullOrBlank()
            val code = if (complete) requested else "en"
            return PopeIntentionPrayerPublication(code, intention.localizedTitle(code), intention.localizedText(code),
                intention.translationCreditByLanguage?.get(code)?.takeIf(String::isNotBlank))
        }
    }
}

@Composable
fun PopeIntentionPrayerContent(step: RosaryStep, languageCode: String?) {
    val publication = PopeIntentionPrayerPublication.resolve(step, TodayInfoStore.intention(),
        languageCode ?: AppSettings.effectiveInterfaceLanguageCode, AppSettings.showPopeIntentionInPrayers) ?: return
    val code = publication.languageCode
    CompositionLocalProvider(LocalLayoutDirection provides
        if (code == "he" || code == "ar") LayoutDirection.Rtl else LayoutDirection.Ltr) {
        Surface(shape = MaterialTheme.shapes.medium, color = MaterialTheme.colorScheme.surfaceContainer) {
            Column(Modifier.fillMaxWidth().padding(16.dp).testTag("publishedPopeIntention"),
                verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(publication.title, style = MaterialTheme.typography.titleMedium)
                Text(publication.text, style = MaterialTheme.typography.bodyLarge)
                Text(stringResource(R.string.prayer_pope_intention_source), style = MaterialTheme.typography.labelMedium)
                publication.translationCredit?.let {
                    Text(it, style = MaterialTheme.typography.labelSmall)
                }
            }
        }
    }
}
