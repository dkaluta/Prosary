package com.dkaluta.Prosary.ui.jesusprayer

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.StarBorder
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.Color
import com.dkaluta.Prosary.content.PrayerKey
import com.dkaluta.Prosary.content.PrayerTranslations
import com.dkaluta.Prosary.models.JesusPrayerOptions
import com.dkaluta.Prosary.models.JesusPrayerProgress
import com.dkaluta.Prosary.models.JesusPrayerTarget
import com.dkaluta.Prosary.models.LanguageCatalog
import com.dkaluta.Prosary.models.Prayer
import com.dkaluta.Prosary.models.PrayerKind
import com.dkaluta.Prosary.models.RosaryStep
import com.dkaluta.Prosary.services.AppServices
import com.dkaluta.Prosary.services.LocalAppServices
import com.dkaluta.Prosary.ui.shared.PrayerStepFlowScreen
import kotlinx.coroutines.launch

/**
 * Unlike the Rosary/Angelus, there's no engine here building a list of steps — every repetition
 * prays the exact same fixed line, so a single synthesized [RosaryStep] plus a [JesusPrayerProgress]
 * counter is the whole model.
 *
 * [onNavigateUp] (the top app bar's back arrow) and [onFinish] are deliberately distinct: this
 * screen sits two levels deep in the nav graph (Home → Setup → Flow), so a plain "pop one level"
 * back arrow correctly returns to Setup, but finishing a session should return all the way to
 * Home like every other devotion's Finish does — [onFinish] is wired to a pop-to-Home in
 * ProsaryApp.kt rather than a single [onNavigateUp]-style pop. When launched from a saved
 * favorite instead (one nav level), both are wired to the same simple "pop once".
 *
 * [prayer] is set when launched from a saved favorite — its own target overrides [target] and its
 * language is used, mirroring iOS's `effectiveTarget`.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun JesusPrayerFlowScreen(
    target: JesusPrayerTarget = JesusPrayerTarget.Count(33),
    prayer: Prayer? = null,
    onNavigateUp: () -> Unit,
    onFinish: () -> Unit,
) {
    val services = LocalAppServices.current
    val scope = rememberCoroutineScope()
    val effectiveTarget = prayer?.jesusPrayer?.target ?: target

    var progress by remember { mutableStateOf(JesusPrayerProgress(target = effectiveTarget)) }
    var isRightToLeft by remember { mutableStateOf(false) }
    var seasonColor by remember { mutableStateOf(Color.Transparent) }
    var languageCode by remember { mutableStateOf<String?>(null) }
    var hasLoaded by remember { mutableStateOf(false) }
    var matchingFavoriteId by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(prayer) {
        languageCode = if (prayer != null) {
            prayer.resolvedLanguageCode
        } else {
            val all = runCatching { services.presetStore.all() }.getOrDefault(emptyList())
            val defaultJP = all.firstOrNull { it.kind == PrayerKind.JesusPrayer && it.isDefault }
                ?: all.firstOrNull { it.kind == PrayerKind.JesusPrayer }
            defaultJP?.resolvedLanguageCode
        }
        isRightToLeft = LanguageCatalog.resolve(languageCode ?: LanguageCatalog.defaultCode).isRightToLeft
        seasonColor = services.calendar.seasonColorToday()
        hasLoaded = true

        val all = runCatching { services.presetStore.all() }.getOrDefault(emptyList())
        val resolved = languageCode ?: LanguageCatalog.defaultCode
        matchingFavoriteId = all.firstOrNull {
            it.kind == PrayerKind.JesusPrayer && it.resolvedLanguageCode == resolved && it.jesusPrayer.target == effectiveTarget
        }?.id
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
            IconButton(onClick = {
                scope.launch {
                    matchingFavoriteId = toggleJesusPrayerFavorite(services, matchingFavoriteId, languageCode, effectiveTarget)
                }
            }) {
                Icon(
                    if (matchingFavoriteId != null) Icons.Filled.Star else Icons.Filled.StarBorder,
                    contentDescription = if (matchingFavoriteId != null) "Remove from Favorites" else "Add to Favorites",
                )
            }
            // The footer button never turns into "Finish" for an unbounded session (see
            // JesusPrayerProgress.isLastRep) — this is the only way to end that session.
            if (effectiveTarget is JesusPrayerTarget.Unbounded) {
                TextButton(onClick = onFinish) { Text("Finish") }
            }
        },
    )
}

private suspend fun toggleJesusPrayerFavorite(
    services: AppServices,
    currentFavoriteId: String?,
    languageCode: String?,
    target: JesusPrayerTarget,
): String? {
    if (currentFavoriteId != null) {
        services.presetStore.get(currentFavoriteId)?.let { services.presetStore.delete(it) }
        return null
    }

    val resolved = languageCode ?: LanguageCatalog.defaultCode
    val langName = LanguageCatalog.all.firstOrNull { it.code == resolved }?.nativeName ?: resolved
    val targetLabel = when (target) {
        is JesusPrayerTarget.Count -> "× ${target.value}"
        JesusPrayerTarget.Unbounded -> "Unbounded"
    }
    val all = runCatching { services.presetStore.all() }.getOrDefault(emptyList())
    val isFirst = all.none { it.kind == PrayerKind.JesusPrayer }
    val newFavorite = Prayer(
        name = "Jesus Prayer $targetLabel ($langName)",
        kind = PrayerKind.JesusPrayer,
        isDefault = isFirst,
        languageCode = resolved,
        jesusPrayer = JesusPrayerOptions(target = target),
    )
    services.presetStore.save(newFavorite)
    return newFavorite.id
}
