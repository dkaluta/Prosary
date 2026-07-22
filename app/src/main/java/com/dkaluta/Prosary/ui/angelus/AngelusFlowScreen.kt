package com.dkaluta.Prosary.ui.angelus

import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.Color
import com.dkaluta.Prosary.models.LanguageCatalog
import com.dkaluta.Prosary.models.RosaryStep
import com.dkaluta.Prosary.services.LocalAppServices
import com.dkaluta.Prosary.ui.shared.PrayerStepFlowScreen

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AngelusFlowScreen(onBack: () -> Unit) {
    val services = LocalAppServices.current

    var steps by remember { mutableStateOf<List<RosaryStep>>(emptyList()) }
    var currentIndex by remember { mutableIntStateOf(0) }
    var isRightToLeft by remember { mutableStateOf(false) }
    var seasonColor by remember { mutableStateOf(Color.Transparent) }
    var languageCode by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(Unit) {
        // Same language source HomeScreen already reads for the default Rosary preset — the
        // Angelus has no config of its own, so it borrows the user's usual prayer language
        // instead of introducing a separate picker.
        val preset = runCatching { services.presetStore.defaultPreset() }.getOrNull()
        languageCode = preset?.languageCode
        isRightToLeft = LanguageCatalog.resolve(languageCode).isRightToLeft
        steps = services.angelusEngine.buildSteps(languageCode)
        currentIndex = 0
        seasonColor = services.calendar.seasonColorToday()
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
    )
}
