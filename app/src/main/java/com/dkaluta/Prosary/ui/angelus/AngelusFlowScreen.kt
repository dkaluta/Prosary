package com.dkaluta.Prosary.ui.angelus

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.StarBorder
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.Color
import com.dkaluta.Prosary.models.LanguageCatalog
import com.dkaluta.Prosary.models.Prayer
import com.dkaluta.Prosary.models.PrayerKind
import com.dkaluta.Prosary.models.RosaryStep
import com.dkaluta.Prosary.services.AppServices
import com.dkaluta.Prosary.services.LocalAppServices
import com.dkaluta.Prosary.ui.shared.PrayerStepFlowScreen
import kotlinx.coroutines.launch

/** [prayer] is set when launched from a saved favorite (via PrayerDispatchScreen) — provides the
 * language and is tracked for the star button. Null when launched from Home with no Angelus
 * favorite saved yet, in which case it borrows the default Rosary preset's language. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AngelusFlowScreen(prayer: Prayer? = null, onBack: () -> Unit) {
    val services = LocalAppServices.current
    val scope = rememberCoroutineScope()

    var steps by remember { mutableStateOf<List<RosaryStep>>(emptyList()) }
    var currentIndex by remember { mutableIntStateOf(0) }
    var isRightToLeft by remember { mutableStateOf(false) }
    var seasonColor by remember { mutableStateOf(Color.Transparent) }
    var languageCode by remember { mutableStateOf<String?>(null) }
    var matchingFavoriteId by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(prayer) {
        languageCode = if (prayer != null) {
            prayer.resolvedLanguageCode
        } else {
            val default = runCatching { services.presetStore.defaultPreset() }.getOrNull()
            default?.languageCode
        }
        isRightToLeft = LanguageCatalog.resolve(languageCode).isRightToLeft
        steps = services.angelusEngine.buildSteps(languageCode)
        currentIndex = 0
        seasonColor = services.calendar.seasonColorToday()

        val all = runCatching { services.presetStore.all() }.getOrDefault(emptyList())
        val resolved = languageCode ?: LanguageCatalog.defaultCode
        matchingFavoriteId = all.firstOrNull { it.kind == PrayerKind.Angelus && it.resolvedLanguageCode == resolved }?.id
    }

    val currentStep = steps.getOrNull(currentIndex)

    PrayerStepFlowScreen(
        title = "The Angelus",
        step = currentStep,
        currentIndex = currentIndex,
        totalSteps = steps.size,
        seasonColor = seasonColor,
        isRightToLeft = isRightToLeft,
        languageCode = languageCode,
        canGoBack = currentIndex > 0,
        onBack = { if (currentIndex > 0) currentIndex-- },
        onNext = {
            if (steps.isEmpty() || currentIndex == steps.size - 1) onBack() else currentIndex++
        },
        onNavigateUp = onBack,
        topBarActions = {
            IconButton(onClick = {
                scope.launch {
                    matchingFavoriteId = toggleAngelusFavorite(services, matchingFavoriteId, languageCode)
                }
            }) {
                Icon(
                    if (matchingFavoriteId != null) Icons.Filled.Star else Icons.Filled.StarBorder,
                    contentDescription = if (matchingFavoriteId != null) "Remove from Favorites" else "Add to Favorites",
                )
            }
        },
    )
}

private suspend fun toggleAngelusFavorite(services: AppServices, currentFavoriteId: String?, languageCode: String?): String? {
    if (currentFavoriteId != null) {
        services.presetStore.get(currentFavoriteId)?.let { services.presetStore.delete(it) }
        return null
    }

    val resolved = languageCode ?: LanguageCatalog.defaultCode
    val langName = LanguageCatalog.all.firstOrNull { it.code == resolved }?.nativeName ?: resolved
    val all = runCatching { services.presetStore.all() }.getOrDefault(emptyList())
    val isFirst = all.none { it.kind == PrayerKind.Angelus }
    val newFavorite = Prayer(
        name = "Angelus ($langName)",
        kind = PrayerKind.Angelus,
        isDefault = isFirst,
        languageCode = resolved,
    )
    services.presetStore.save(newFavorite)
    return newFavorite.id
}
