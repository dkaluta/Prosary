package com.dkaluta.prosary.ui.jesusprayer

import androidx.activity.compose.BackHandler
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.PushPin
import androidx.compose.material.icons.outlined.PushPin
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.lifecycle.viewmodel.compose.viewModel
import com.dkaluta.prosary.ui.shared.JesusPrayerSession
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.lifecycle.viewModelScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import com.dkaluta.prosary.R
import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import com.dkaluta.prosary.models.JesusPrayerOptions
import com.dkaluta.prosary.models.JesusPrayerProgress
import com.dkaluta.prosary.models.JesusPrayerTarget
import com.dkaluta.prosary.models.LanguageCatalog
import com.dkaluta.prosary.models.Prayer
import com.dkaluta.prosary.models.PrayerKind
import com.dkaluta.prosary.models.FavoriteDevotions
import com.dkaluta.prosary.models.PrayerRunKeys
import com.dkaluta.prosary.models.PrayerRunProgressStore
import com.dkaluta.prosary.models.PrayerRunSignatures
import com.dkaluta.prosary.models.RosaryStep
import com.dkaluta.prosary.services.AppServices
import com.dkaluta.prosary.services.LocalAppServices
import com.dkaluta.prosary.ui.shared.PrayerStepFlowScreen
import com.dkaluta.prosary.ui.shared.ResumePrayerDialog
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
    val context = LocalContext.current
    val effectiveTarget = prayer?.jesusPrayer?.target ?: target
    val runKey = remember(prayer?.id, effectiveTarget) {
        PrayerRunKeys.jesus(prayer?.id, effectiveTarget)
    }
    val configurationSignature = remember(effectiveTarget) {
        PrayerRunSignatures.jesus(effectiveTarget)
    }

    val session = viewModel(key = runKey) { JesusPrayerSession(prayer, effectiveTarget) }
    val scope = session.viewModelScope
    var progress by session.progress
    var isRightToLeft by session.isRightToLeft
    var seasonColor by session.seasonColor
    var languageCode by session.languageCode
    var hasLoaded by session.hasLoaded
    var matchingFavoriteId by session.matchingFavoriteId
    var isPinned by session.isPinned
    var chosenLanguage by session.chosenLanguage
    var pendingResume by session.pendingResume
    var runReady by session.runReady

    LaunchedEffect(prayer, effectiveTarget, runKey) {
        if (hasLoaded) return@LaunchedEffect
        val all = runCatching { services.presetStore.all() }.getOrDefault(emptyList())
        val defaultJP = all.firstOrNull { it.kind == PrayerKind.JesusPrayer && it.isDefault }
            ?: all.firstOrNull { it.kind == PrayerKind.JesusPrayer }
        val configuredLanguage = prayer?.languageCode
            ?: defaultJP?.languageCode
            ?: LanguageCatalog.defaultSentinel
        val saved = PrayerRunProgressStore.progress(context, runKey)
        progress = JesusPrayerProgress(target = effectiveTarget)
        val validRun = saved?.takeIf {
            it.canResume(
                progress.targetCount ?: Int.MAX_VALUE,
                expectedConfigurationSignature = configurationSignature,
            )
        }
        chosenLanguage = validRun?.languageCode ?: configuredLanguage
        languageCode = LanguageCatalog.resolve(chosenLanguage).code
        isRightToLeft = LanguageCatalog.resolve(languageCode ?: LanguageCatalog.defaultCode).isRightToLeft
        seasonColor = services.calendar.seasonColorToday()
        pendingResume = validRun
        runReady = validRun == null
        if (saved != null && validRun == null) {
            PrayerRunProgressStore.clear(context, runKey)
        }
        hasLoaded = true

        val resolved = languageCode ?: LanguageCatalog.defaultCode
        matchingFavoriteId = all.firstOrNull {
            it.kind == PrayerKind.JesusPrayer && it.resolvedLanguageCode == resolved && it.jesusPrayer.target == effectiveTarget
        }?.id
        isPinned = FavoriteDevotions.contains(context, "jesusPrayer", impliedDevotionPins(all))
    }

    LaunchedEffect(runReady, progress.currentIndex, chosenLanguage, runKey, configurationSignature) {
        if (!runReady) return@LaunchedEffect
        if (progress.currentIndex > 0) {
            PrayerRunProgressStore.save(
                context,
                runKey,
                progress.currentIndex,
                chosenLanguage,
                configurationSignature,
            )
        } else {
            PrayerRunProgressStore.clear(context, runKey)
        }
    }

    val currentStep = if (hasLoaded) {
        RosaryStep(
            id = runKey,
            title = stringResource(R.string.kind_jesus_prayer),
            body = PrayerPackStore.resolveBodyText("rosary", languageCode, "oratioIesu"),
            transliteratedBody = PrayerPackStore.transliteration("rosary", languageCode, "oratioIesu"),
            imageOverrideKey = "christ_pantocrator",
        )
    } else {
        null
    }

    pendingResume?.let { saved ->
        ResumePrayerDialog(
            progress = saved,
            totalSteps = progress.targetCount,
            onContinue = {
                progress = progress.copy(currentIndex = saved.stepIndex)
                pendingResume = null
                runReady = true
            },
            onRestart = {
                PrayerRunProgressStore.clear(context, runKey)
                progress = progress.copy(currentIndex = 0)
                pendingResume = null
                runReady = true
            },
        )
    }

    fun leave() {
        if (runReady && progress.currentIndex > 0) {
            PrayerRunProgressStore.save(
                context,
                runKey,
                progress.currentIndex,
                chosenLanguage,
                configurationSignature,
            )
        }
        onNavigateUp()
    }

    fun finish() {
        runReady = false
        PrayerRunProgressStore.clear(context, runKey)
        onFinish()
    }

    BackHandler(onBack = ::leave)

    PrayerStepFlowScreen(
        title = stringResource(R.string.jp_title),
        centralActionLabel = stringResource(R.string.common_pray),
        step = currentStep,
        currentIndex = progress.currentIndex,
        sessionPaused = !runReady,
        totalSteps = progress.targetCount,
        seasonColor = seasonColor,
        isRightToLeft = isRightToLeft,
        languageCode = languageCode,
        canGoBack = progress.canGoBack,
        onBack = { progress = progress.goBack() },
        onNext = {
            if (progress.isLastRep) finish() else progress = progress.goNext()
        },
        onNavigateUp = ::leave,
        topBarActions = {
            IconButton(onClick = {
                scope.launch {
                    val all = services.presetStore.all()
                    val implied = impliedDevotionPins(all)
                    val wasPinned = FavoriteDevotions.contains(context, "jesusPrayer", implied)
                    if (!wasPinned && matchingFavoriteId == null) {
                        matchingFavoriteId = createJesusPrayerFavorite(context, services, languageCode, effectiveTarget)
                    }
                    FavoriteDevotions.toggle(context, "jesusPrayer", implied)
                    isPinned = !wasPinned
                }
            }) {
                Icon(
                    if (isPinned) Icons.Filled.PushPin else Icons.Outlined.PushPin,
                    contentDescription = if (isPinned) stringResource(R.string.home_remove_from_pray) else stringResource(R.string.home_add_to_pray),
                )
            }
            // The footer button never turns into "Finish" for an unbounded session (see
            // JesusPrayerProgress.isLastRep) — this is the only way to end that session.
            if (effectiveTarget is JesusPrayerTarget.Unbounded) {
                TextButton(onClick = ::finish) { Text(stringResource(R.string.common_finish)) }
            }
        },
    )
}

private fun impliedDevotionPins(prayers: List<Prayer>): List<String> = prayers.mapNotNull {
    when (it.kind) {
        PrayerKind.Rosary -> "rosary"
        PrayerKind.JesusPrayer -> "jesusPrayer"
        PrayerKind.Custom -> it.customDevotionId
    }
}

private suspend fun createJesusPrayerFavorite(
    context: android.content.Context,
    services: AppServices,
    languageCode: String?,
    target: JesusPrayerTarget,
): String? {
    val resolved = languageCode ?: LanguageCatalog.defaultCode
    val langName = LanguageCatalog.pickerLanguageName(resolved)
    val targetLabel = when (target) {
        is JesusPrayerTarget.Count -> context.getString(R.string.jp_times_prefix, target.value)
        JesusPrayerTarget.Unbounded -> context.getString(R.string.jp_unbounded)
    }
    val all = runCatching { services.presetStore.all() }.getOrDefault(emptyList())
    val isFirst = all.none { it.kind == PrayerKind.JesusPrayer }
    val newFavorite = Prayer(
        name = context.getString(R.string.jp_favorite_name, targetLabel, langName),
        kind = PrayerKind.JesusPrayer,
        isDefault = isFirst,
        languageCode = resolved,
        jesusPrayer = JesusPrayerOptions(target = target),
    )
    services.presetStore.save(newFavorite)
    return newFavorite.id
}
