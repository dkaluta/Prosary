package com.dkaluta.Prosary.ui.jesusprayer

import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.Color
import com.dkaluta.Prosary.content.PrayerKey
import com.dkaluta.Prosary.content.PrayerTranslations
import com.dkaluta.Prosary.models.JesusPrayerProgress
import com.dkaluta.Prosary.models.JesusPrayerTarget
import com.dkaluta.Prosary.models.LanguageCatalog
import com.dkaluta.Prosary.models.RosaryStep
import com.dkaluta.Prosary.services.LocalAppServices
import com.dkaluta.Prosary.ui.shared.PrayerStepFlowScreen

/**
 * Unlike the Rosary/Angelus, there's no engine here building a list of steps — every repetition
 * prays the exact same fixed line, so a single synthesized [RosaryStep] plus a [JesusPrayerProgress]
 * counter is the whole model.
 *
 * [onNavigateUp] (the top app bar's back arrow) and [onFinish] are deliberately distinct: this
 * screen sits two levels deep in the nav graph (Home → Setup → Flow), so a plain "pop one level"
 * back arrow correctly returns to Setup, but finishing a session should return all the way to
 * Home like every other devotion's Finish does — [onFinish] is wired to a pop-to-Home in
 * ProsaryApp.kt rather than a single [onNavigateUp]-style pop.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun JesusPrayerFlowScreen(target: JesusPrayerTarget, onNavigateUp: () -> Unit, onFinish: () -> Unit) {
    val services = LocalAppServices.current

    var progress by remember { mutableStateOf(JesusPrayerProgress(target = target)) }
    var isRightToLeft by remember { mutableStateOf(false) }
    var seasonColor by remember { mutableStateOf(Color.Transparent) }
    var languageCode by remember { mutableStateOf<String?>(null) }
    var hasLoaded by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        // Same language source AngelusFlowScreen uses — no config of its own, so it borrows the
        // user's usual prayer language.
        val preset = runCatching { services.presetStore.defaultPreset() }.getOrNull()
        languageCode = preset?.languageCode
        isRightToLeft = LanguageCatalog.resolve(languageCode).isRightToLeft
        seasonColor = services.calendar.seasonColorToday()
        hasLoaded = true
    }

    val currentStep = if (hasLoaded) {
        RosaryStep(
            title = "Jesus Prayer",
            body = PrayerTranslations.get(languageCode, PrayerKey.OratioIesu),
            imageOverrideKey = "jesus_portrait",
        )
    } else {
        null
    }

    PrayerStepFlowScreen(
        title = "The Jesus Prayer",
        step = currentStep,
        currentIndex = progress.currentIndex,
        totalSteps = progress.targetCount,
        seasonColor = seasonColor,
        isRightToLeft = isRightToLeft,
        languageCode = languageCode,
        canGoBack = progress.canGoBack,
        onBack = { progress = progress.goBack() },
        onNext = {
            if (progress.isLastRep) onFinish() else progress = progress.goNext()
        },
        onNavigateUp = onNavigateUp,
        topBarActions = {
            // Unbounded has no target, so it never reaches "Finish" via the footer's Next button
            // (see JesusPrayerProgress.isLastRep) — this is the only way to end that session.
            if (target is JesusPrayerTarget.Unbounded) {
                TextButton(onClick = onFinish) { Text("Finish") }
            }
        },
    )
}
