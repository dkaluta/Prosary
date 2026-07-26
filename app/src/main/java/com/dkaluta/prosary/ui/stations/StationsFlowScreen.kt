package com.dkaluta.prosary.ui.stations

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
import com.dkaluta.prosary.models.LanguageCatalog
import com.dkaluta.prosary.models.Prayer
import com.dkaluta.prosary.models.PrayerKind
import com.dkaluta.prosary.models.RosaryStep
import com.dkaluta.prosary.services.AppServices
import com.dkaluta.prosary.services.LocalAppServices
import com.dkaluta.prosary.ui.shared.PrayerStepFlowScreen
import kotlinx.coroutines.launch

/** [prayer] is set when launched from a saved favorite (via PrayerDispatchScreen) — provides the
 * language and is tracked for the star button. Null when launched from Home with no Stations
 * favorite saved yet, in which case it uses the app default language. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StationsFlowScreen(prayer: Prayer? = null, onBack: () -> Unit) {
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
            val all = runCatching { services.presetStore.all() }.getOrDefault(emptyList())
            val default = all.firstOrNull { it.kind == PrayerKind.StationsOfTheCross && it.isDefault }
                ?: all.firstOrNull { it.kind == PrayerKind.StationsOfTheCross }
            default?.resolvedLanguageCode
        }
        isRightToLeft = LanguageCatalog.resolve(languageCode).isRightToLeft
        steps = services.engine.buildSteps(Prayer(kind = PrayerKind.StationsOfTheCross, languageCode = languageCode ?: LanguageCatalog.defaultSentinel))
        currentIndex = 0
        seasonColor = services.calendar.seasonColorToday()

        val all = runCatching { services.presetStore.all() }.getOrDefault(emptyList())
        val resolved = languageCode ?: LanguageCatalog.defaultCode
        matchingFavoriteId = all.firstOrNull { it.kind == PrayerKind.StationsOfTheCross && it.resolvedLanguageCode == resolved }?.id
    }

    val currentStep = steps.getOrNull(currentIndex)

    PrayerStepFlowScreen(
        title = "Stations of the Cross",
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
                    matchingFavoriteId = toggleStationsFavorite(services, matchingFavoriteId, languageCode)
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

private suspend fun toggleStationsFavorite(services: AppServices, currentFavoriteId: String?, languageCode: String?): String? {
    if (currentFavoriteId != null) {
        services.presetStore.get(currentFavoriteId)?.let { services.presetStore.delete(it) }
        return null
    }

    val resolved = languageCode ?: LanguageCatalog.defaultCode
    val langName = LanguageCatalog.all.firstOrNull { it.code == resolved }?.nativeName ?: resolved
    val all = runCatching { services.presetStore.all() }.getOrDefault(emptyList())
    val isFirst = all.none { it.kind == PrayerKind.StationsOfTheCross }
    val newFavorite = Prayer(
        name = "Stations of the Cross ($langName)",
        kind = PrayerKind.StationsOfTheCross,
        isDefault = isFirst,
        languageCode = resolved,
    )
    services.presetStore.save(newFavorite)
    return newFavorite.id
}
