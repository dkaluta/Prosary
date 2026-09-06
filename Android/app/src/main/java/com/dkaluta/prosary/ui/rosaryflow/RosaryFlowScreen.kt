package com.dkaluta.prosary.ui.rosaryflow

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.SkipNext
import androidx.compose.material.icons.filled.SkipPrevious
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
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
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalLayoutDirection
import com.dkaluta.prosary.ui.shared.InterfaceNavigation
import com.dkaluta.prosary.ui.shared.PrayerNavigation
import androidx.compose.ui.Alignment
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import com.dkaluta.prosary.R
import com.dkaluta.prosary.models.LanguageCatalog
import com.dkaluta.prosary.models.Prayer
import com.dkaluta.prosary.models.PrayerRunKeys
import com.dkaluta.prosary.models.PrayerRunProgress
import com.dkaluta.prosary.models.PrayerRunProgressStore
import com.dkaluta.prosary.models.PrayerRunSignatures
import com.dkaluta.prosary.models.RosaryStep
import com.dkaluta.prosary.services.LocalAppServices
import com.dkaluta.prosary.ui.shared.PrayerLanguagePicker
import com.dkaluta.prosary.ui.shared.PrayerStepFlowScreen
import com.dkaluta.prosary.ui.shared.ResumePrayerDialog
import kotlinx.coroutines.launch

/** Takes a resolved [Prayer] directly — the caller (PrayerDispatchScreen) already loaded it, so
 * this screen no longer needs its own "resolve id, fall back to default" logic. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RosaryFlowScreen(prayer: Prayer, onBack: () -> Unit, onOpenDevotion: (String, String?, String?) -> Unit) {
    val services = LocalAppServices.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val runKey = remember(prayer.id) { PrayerRunKeys.rosary(prayer.id) }
    val configurationSignature = PrayerRunSignatures.rosary(prayer.rosary)

    var steps by remember(prayer.id) { mutableStateOf<List<RosaryStep>>(emptyList()) }
    var currentIndex by remember(prayer.id) { mutableIntStateOf(0) }
    var seasonColor by remember(prayer.id) { mutableStateOf(Color.Transparent) }
    var chosenLanguage by remember(prayer.id) { mutableStateOf(prayer.languageCode) }
    var languageCode by remember(prayer.id) { mutableStateOf(prayer.resolvedLanguageCode) }
    var languageMenuExpanded by remember(prayer.id) { mutableStateOf(false) }
    var pendingResume by remember(prayer.id) { mutableStateOf<PrayerRunProgress?>(null) }
    var runReady by remember(prayer.id) { mutableStateOf(false) }
    var showsLitanyOffer by remember(prayer.id) { mutableStateOf(false) }

    LaunchedEffect(prayer.id, configurationSignature) {
        val saved = PrayerRunProgressStore.progress(context, runKey)
        val candidateLanguage = saved?.languageCode ?: prayer.languageCode
        val candidateSteps = services.engine.buildSteps(prayer.copy(languageCode = candidateLanguage))
        val validRun = saved?.takeIf {
            it.canResume(
                candidateSteps.size,
                sameLocalDayOnly = true,
                expectedConfigurationSignature = configurationSignature,
            )
        }
        // An expired/stale bookmark must not override the preset's current language merely
        // because its language is read before validation.
        val sessionLanguage = validRun?.languageCode ?: prayer.languageCode
        val built = if (sessionLanguage == candidateLanguage) {
            candidateSteps
        } else {
            services.engine.buildSteps(prayer.copy(languageCode = sessionLanguage))
        }
        chosenLanguage = sessionLanguage
        languageCode = LanguageCatalog.resolve(sessionLanguage).code
        steps = built
        currentIndex = 0
        seasonColor = services.calendar.seasonColorToday()
        pendingResume = validRun
        if (saved != null && pendingResume == null) {
            PrayerRunProgressStore.clear(context, runKey)
        }
        runReady = pendingResume == null
    }

    // Step zero has nothing useful to resume; every later page is written immediately so the
    // Android process can be killed after Navigate Up without losing the user's place.
    LaunchedEffect(runReady, currentIndex, chosenLanguage, steps.size, runKey, configurationSignature) {
        if (!runReady || steps.isEmpty()) return@LaunchedEffect
        if (currentIndex in 1 until steps.size) {
            PrayerRunProgressStore.save(
                context,
                runKey,
                currentIndex,
                chosenLanguage,
                configurationSignature,
            )
        } else if (currentIndex == 0) {
            PrayerRunProgressStore.clear(context, runKey)
        }
    }

    val currentStep = steps.getOrNull(currentIndex)
    val isRightToLeft = LanguageCatalog.resolve(languageCode).isRightToLeft
    val beadLayout = remember(steps, currentIndex, prayer.rosary.includeFinalSignOfCross) {
        BeadLayout.build(steps, currentIndex, prayer.rosary.includeFinalSignOfCross)
    }
    val previousMystery = remember(steps, currentIndex) {
        MysteryStepNavigation.previous(steps, currentIndex)
    }
    val nextMystery = remember(steps, currentIndex) {
        MysteryStepNavigation.next(steps, currentIndex)
    }

    pendingResume?.let { saved ->
        ResumePrayerDialog(
            progress = saved,
            totalSteps = steps.size,
            onContinue = {
                currentIndex = saved.stepIndex
                pendingResume = null
                runReady = true
            },
            onRestart = {
                PrayerRunProgressStore.clear(context, runKey)
                currentIndex = 0
                pendingResume = null
                runReady = true
            },
        )
    }

    fun leave() {
        if (runReady && currentIndex in 1 until steps.size) {
            PrayerRunProgressStore.save(
                context,
                runKey,
                currentIndex,
                chosenLanguage,
                configurationSignature,
            )
        }
        onBack()
    }

    fun finish() {
        PrayerRunProgressStore.clear(context, runKey)
        runReady = false
        if (PrayerPackStore.definition("litanyOfLoreto") != null) showsLitanyOffer = true else onBack()
    }

    if (showsLitanyOffer) {
        AlertDialog(
            onDismissRequest = { showsLitanyOffer = false; onBack() },
            title = { Text(stringResource(R.string.common_done)) },
            text = { Text(stringResource(R.string.rosary_litany_offer)) },
            confirmButton = { TextButton(onClick = {
                showsLitanyOffer = false
                onOpenDevotion("litanyOfLoreto", "afterRosary", languageCode)
            }) { Text(stringResource(R.string.rosary_pray_litany)) } },
            dismissButton = { TextButton(onClick = { showsLitanyOffer = false; onBack() }) {
                Text(stringResource(R.string.common_finish))
            } },
        )
    }

    BackHandler(onBack = ::leave)

    PrayerStepFlowScreen(
        title = stringResource(R.string.rosary_praying),
        step = currentStep,
        currentIndex = currentIndex,
        totalSteps = steps.size,
        seasonColor = seasonColor,
        isRightToLeft = isRightToLeft,
        languageCode = languageCode,
        canGoBack = currentIndex > 0,
        onBack = { if (currentIndex > 0) currentIndex-- },
        onNext = {
            if (steps.isEmpty() || currentIndex == steps.size - 1) finish() else currentIndex++
        },
        onNavigateUp = ::leave,
        accessory = { isWide, hasRoomForSingleMinorColumn ->
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                BeadProgressView(
                    layout = beadLayout,
                    isWide = isWide,
                    hasRoomForSingleMinorColumn = hasRoomForSingleMinorColumn,
                )
                InterfaceNavigation {
                    val iconScale = PrayerNavigation.iconScale(LocalLayoutDirection.current)
                    Row {
                        IconButton(
                            onClick = { previousMystery?.let { currentIndex = it } },
                            enabled = previousMystery != null,
                        ) {
                            Icon(
                                Icons.Filled.SkipPrevious,
                                modifier = Modifier.graphicsLayer { scaleX = iconScale },
                                contentDescription = stringResource(R.string.flow_previous_mystery),
                            )
                        }
                        IconButton(
                            onClick = { nextMystery?.let { currentIndex = it } },
                            enabled = nextMystery != null,
                        ) {
                            Icon(
                                Icons.Filled.SkipNext,
                                modifier = Modifier.graphicsLayer { scaleX = iconScale },
                                contentDescription = stringResource(R.string.flow_next_mystery),
                            )
                        }
                    }
                }
            }
        },
        topBarActions = {
            PrayerLanguagePicker(
                devotionId = "rosary",
                chosenLanguage = chosenLanguage,
                expanded = languageMenuExpanded,
                onExpandedChange = { languageMenuExpanded = it },
                onSelect = { raw ->
                    val position = currentIndex
                    chosenLanguage = raw
                    languageCode = LanguageCatalog.resolve(raw).code
                    steps = services.engine.buildSteps(prayer.copy(languageCode = raw))
                    currentIndex = position.coerceIn(0, (steps.size - 1).coerceAtLeast(0))
                    // A saved preset remembers an in-prayer language choice just like a custom
                    // devotion; an ad-hoc Prayer simply has no matching row and is left alone.
                    scope.launch {
                        services.presetStore.get(prayer.id)?.let { saved ->
                            services.presetStore.save(saved.copy(languageCode = raw))
                        }
                    }
                },
            )
        },
    )
}
