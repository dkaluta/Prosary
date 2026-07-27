package com.dkaluta.prosary.ui.shared

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
import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import com.dkaluta.prosary.models.LanguageCatalog
import com.dkaluta.prosary.models.Prayer
import com.dkaluta.prosary.models.PrayerKind
import com.dkaluta.prosary.models.RosaryStep
import com.dkaluta.prosary.services.AppServices
import com.dkaluta.prosary.services.LocalAppServices
import kotlinx.coroutines.launch

/** The single flow screen for every [PrayerKind.Custom] devotion (currently just Trisagion) —
 * mirrors AngelusFlowScreen/StationsFlowScreen's shape exactly, but reads its title/steps from
 * [PrayerPackStore]/[com.dkaluta.prosary.engine.PrayerEngine] instead of a per-devotion hardcoded
 * builder, so a new generic devotion needs no new screen at all.
 *
 * [prayer] is set when launched from an existing favorite (via PrayerDispatchScreen) — seeds the
 * star as already-favorited immediately, without waiting on the initial favorites fetch. A
 * generic devotion has no per-favorite language — like Angelus/Stations, it always follows the
 * app default. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CustomDevotionFlowScreen(devotionId: String, prayer: Prayer? = null, onBack: () -> Unit) {
    val services = LocalAppServices.current
    val scope = rememberCoroutineScope()

    var steps by remember { mutableStateOf<List<RosaryStep>>(emptyList()) }
    var currentIndex by remember { mutableIntStateOf(0) }
    var isRightToLeft by remember { mutableStateOf(false) }
    var languageCode by remember { mutableStateOf<String?>(null) }
    var matchingFavoriteId by remember { mutableStateOf(prayer?.id) }
    var displayName by remember { mutableStateOf(devotionId) }

    LaunchedEffect(prayer, devotionId) {
        displayName = PrayerPackStore.info(devotionId)?.displayName ?: devotionId
        languageCode = LanguageCatalog.resolve(LanguageCatalog.defaultSentinel).code
        isRightToLeft = LanguageCatalog.resolve(languageCode).isRightToLeft
        steps = services.engine.buildSteps(
            Prayer(kind = PrayerKind.Custom, languageCode = LanguageCatalog.defaultSentinel, customDevotionId = devotionId),
        )
        currentIndex = 0

        val all = runCatching { services.presetStore.all() }.getOrDefault(emptyList())
        matchingFavoriteId = all.firstOrNull { it.kind == PrayerKind.Custom && it.customDevotionId == devotionId }?.id
    }

    val currentStep = steps.getOrNull(currentIndex)

    PrayerStepFlowScreen(
        title = displayName,
        step = currentStep,
        currentIndex = currentIndex,
        totalSteps = steps.size,
        seasonColor = Color.Transparent,
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
                    matchingFavoriteId = toggleCustomDevotionFavorite(services, devotionId, displayName, matchingFavoriteId)
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

private suspend fun toggleCustomDevotionFavorite(
    services: AppServices,
    devotionId: String,
    displayName: String,
    currentFavoriteId: String?,
): String? {
    if (currentFavoriteId != null) {
        services.presetStore.get(currentFavoriteId)?.let { services.presetStore.delete(it) }
        return null
    }

    val newFavorite = Prayer(
        name = displayName,
        kind = PrayerKind.Custom,
        isDefault = true,
        languageCode = LanguageCatalog.defaultSentinel,
        customDevotionId = devotionId,
    )
    services.presetStore.save(newFavorite)
    return newFavorite.id
}
