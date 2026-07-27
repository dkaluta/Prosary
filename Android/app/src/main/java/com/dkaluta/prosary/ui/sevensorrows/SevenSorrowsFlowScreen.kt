package com.dkaluta.prosary.ui.sevensorrows

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
import com.dkaluta.prosary.ui.rosaryflow.BeadLayout
import com.dkaluta.prosary.ui.rosaryflow.BeadProgressView
import com.dkaluta.prosary.ui.shared.PrayerStepFlowScreen
import kotlinx.coroutines.launch

/** Combines AngelusFlowScreen's "launchable with no saved favorite" pattern (no options beyond
 * language, so there's nothing to configure before starting) with RosaryFlowScreen's bead-track
 * accessory (the Seven Sorrows is decade-based, unlike the Angelus/Stations of the Cross) — the
 * same combination FranciscanCrownFlowScreen uses. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SevenSorrowsFlowScreen(prayer: Prayer? = null, onBack: () -> Unit) {
    val services = LocalAppServices.current
    val scope = rememberCoroutineScope()

    var steps by remember { mutableStateOf<List<RosaryStep>>(emptyList()) }
    var currentIndex by remember { mutableIntStateOf(0) }
    var isRightToLeft by remember { mutableStateOf(false) }
    var seasonColor by remember { mutableStateOf(Color.Transparent) }
    var languageCode by remember { mutableStateOf<String?>(null) }
    var matchingFavoriteId by remember { mutableStateOf(prayer?.id) }

    LaunchedEffect(prayer) {
        languageCode = LanguageCatalog.resolve(LanguageCatalog.defaultSentinel).code
        isRightToLeft = LanguageCatalog.resolve(languageCode).isRightToLeft
        steps = services.engine.buildSteps(Prayer(kind = PrayerKind.SevenSorrows, languageCode = LanguageCatalog.defaultSentinel))
        currentIndex = 0
        seasonColor = services.calendar.seasonColorToday()

        val all = runCatching { services.presetStore.all() }.getOrDefault(emptyList())
        matchingFavoriteId = all.firstOrNull { it.kind == PrayerKind.SevenSorrows }?.id
    }

    val currentStep = steps.getOrNull(currentIndex)
    val beadLayout = remember(steps, currentIndex) {
        BeadLayout.build(steps, currentIndex, hasClosingCross = true)
    }

    PrayerStepFlowScreen(
        title = "Seven Sorrows",
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
        accessory = { isWide, hasRoomForSingleMinorColumn ->
            BeadProgressView(layout = beadLayout, isWide = isWide, hasRoomForSingleMinorColumn = hasRoomForSingleMinorColumn)
        },
        topBarActions = {
            IconButton(onClick = {
                scope.launch {
                    matchingFavoriteId = toggleSevenSorrowsFavorite(services, matchingFavoriteId)
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

private suspend fun toggleSevenSorrowsFavorite(services: AppServices, currentFavoriteId: String?): String? {
    if (currentFavoriteId != null) {
        services.presetStore.get(currentFavoriteId)?.let { services.presetStore.delete(it) }
        return null
    }

    val newFavorite = Prayer(
        name = PrayerKind.SevenSorrows.defaultName,
        kind = PrayerKind.SevenSorrows,
        isDefault = true,
        languageCode = LanguageCatalog.defaultSentinel,
    )
    services.presetStore.save(newFavorite)
    return newFavorite.id
}
