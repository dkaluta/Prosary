package com.dkaluta.prosary.ui.rosaryflow

import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import com.dkaluta.prosary.R
import com.dkaluta.prosary.models.LanguageCatalog
import com.dkaluta.prosary.models.Prayer
import com.dkaluta.prosary.models.RosaryStep
import com.dkaluta.prosary.services.LocalAppServices
import com.dkaluta.prosary.ui.shared.PrayerStepFlowScreen

/** Takes a resolved [Prayer] directly — the caller (PrayerDispatchScreen) already loaded it, so
 * this screen no longer needs its own "resolve id, fall back to default" logic. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RosaryFlowScreen(prayer: Prayer, onBack: () -> Unit) {
    val services = LocalAppServices.current

    var steps by remember { mutableStateOf<List<RosaryStep>>(emptyList()) }
    var currentIndex by remember { mutableIntStateOf(0) }
    var seasonColor by remember { mutableStateOf(Color.Transparent) }

    LaunchedEffect(prayer.id) {
        steps = services.engine.buildSteps(prayer)
        currentIndex = 0
        seasonColor = services.calendar.seasonColorToday()
    }

    val currentStep = steps.getOrNull(currentIndex)
    val isRightToLeft = LanguageCatalog.resolve(prayer.languageCode).isRightToLeft
    val beadLayout = remember(steps, currentIndex, prayer.rosary.includeFinalSignOfCross) {
        BeadLayout.build(steps, currentIndex, prayer.rosary.includeFinalSignOfCross)
    }

    PrayerStepFlowScreen(
        title = stringResource(R.string.rosary_praying),
        step = currentStep,
        currentIndex = currentIndex,
        totalSteps = steps.size,
        seasonColor = seasonColor,
        isRightToLeft = isRightToLeft,
        languageCode = prayer.resolvedLanguageCode,
        canGoBack = currentIndex > 0,
        onBack = { if (currentIndex > 0) currentIndex-- },
        onNext = {
            if (steps.isEmpty() || currentIndex == steps.size - 1) onBack() else currentIndex++
        },
        onNavigateUp = onBack,
        accessory = { isWide, hasRoomForSingleMinorColumn ->
            BeadProgressView(layout = beadLayout, isWide = isWide, hasRoomForSingleMinorColumn = hasRoomForSingleMinorColumn)
        },
    )
}
