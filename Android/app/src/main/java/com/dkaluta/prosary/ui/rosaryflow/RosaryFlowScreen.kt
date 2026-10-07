package com.dkaluta.prosary.ui.rosaryflow

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.SkipNext
import androidx.compose.material.icons.filled.SkipPrevious
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.TextButton
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.runtime.mutableStateOf
import androidx.compose.material3.Text
import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.runtime.Composable
import androidx.lifecycle.viewmodel.compose.viewModel
import com.dkaluta.prosary.ui.shared.RosaryPrayerSession
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.lifecycle.viewModelScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.ui.unit.dp
import com.dkaluta.prosary.ui.presets.OptionPickerField
import com.dkaluta.prosary.typography.HebrewDisplayText
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalLayoutDirection
import com.dkaluta.prosary.ui.shared.InterfaceNavigation
import com.dkaluta.prosary.ui.shared.PrayerNavigation
import androidx.compose.ui.Alignment
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import com.dkaluta.prosary.R
import com.dkaluta.prosary.models.LanguageCatalog
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.models.MysteryGroup
import com.dkaluta.prosary.models.Mystery
import com.dkaluta.prosary.models.MysteryCatalog
import com.dkaluta.prosary.models.MysterySelectionMode
import com.dkaluta.prosary.content.MysteryTranslations
import com.dkaluta.prosary.models.Prayer
import com.dkaluta.prosary.models.PrayerRunKeys
import com.dkaluta.prosary.models.PrayerRunProgressStore
import com.dkaluta.prosary.models.PrayerRunSignatures
import com.dkaluta.prosary.services.LocalAppServices
import com.dkaluta.prosary.ui.shared.PrayerLanguagePicker
import com.dkaluta.prosary.ui.shared.PrayerStepFlowScreen
import com.dkaluta.prosary.ui.shared.ResumePrayerDialog
import kotlinx.coroutines.launch

/** Takes a resolved [Prayer] directly — the caller (PrayerDispatchScreen) already loaded it, so
 * this screen no longer needs its own "resolve id, fall back to default" logic. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RosaryFlowScreen(prayer: Prayer, onBack: () -> Unit) {
    val services = LocalAppServices.current
    val context = LocalContext.current
    val runKey = remember(prayer.id) { PrayerRunKeys.rosary(prayer.id) }
    val baseConfigurationSignature = PrayerRunSignatures.rosary(prayer.rosary)

    val session = viewModel(key = runKey) { RosaryPrayerSession(prayer) }
    val scope = session.viewModelScope
    var steps by session.steps
    var currentIndex by session.currentIndex
    var seasonColor by session.seasonColor
    var chosenLanguage by session.chosenLanguage
    var languageCode by session.languageCode
    var languageMenuExpanded by session.languageMenuExpanded
    var pendingResume by session.pendingResume
    var runReady by session.runReady
    var sessionOptions by session.rosaryOptions
    var navigationGroup by session.navigationGroup
    var navigationOrder by session.navigationOrder
    var showsMysteryPicker by session.showsMysteryPicker
    var pickerGroup by session.pickerGroup
    val requiresMysteryChoice = prayer.rosary.mysterySelectionMode == MysterySelectionMode.ChooseOnLaunch && navigationGroup == null
    val configurationSignature = PrayerRunSignatures.rosary(prayer.rosary, navigationGroup, navigationOrder)

    LaunchedEffect(prayer.id, baseConfigurationSignature) {
        if (session.loadedSignature == baseConfigurationSignature) return@LaunchedEffect
        val saved = PrayerRunProgressStore.progress(context, runKey)
        val candidateOptions = prayer.rosary.navigationOptions(saved?.rosaryNavigationGroup, saved?.rosaryNavigationOrder)
        val candidateLanguage = saved?.languageCode ?: prayer.languageCode
        val candidateSteps = services.engine.buildSteps(prayer.copy(languageCode = candidateLanguage, rosary = candidateOptions ?: prayer.rosary))
        val validRun = saved?.takeIf {
            candidateOptions != null && it.canResume(
                candidateSteps.size,
                sameLocalDayOnly = true,
                expectedConfigurationSignature = PrayerRunSignatures.rosary(prayer.rosary, it.rosaryNavigationGroup, it.rosaryNavigationOrder),
            )
        }
        // An expired/stale bookmark must not override the preset's current language merely
        // because its language is read before validation.
        val sessionLanguage = validRun?.languageCode ?: prayer.languageCode
        sessionOptions = if (validRun != null) candidateOptions!! else prayer.rosary.copy()
        navigationGroup = validRun?.rosaryNavigationGroup
        navigationOrder = validRun?.rosaryNavigationOrder
        val built = if (validRun != null) {
            candidateSteps
        } else {
            services.engine.buildSteps(prayer.copy(languageCode = sessionLanguage, rosary = sessionOptions))
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
        showsMysteryPicker = validRun == null && prayer.rosary.mysterySelectionMode == MysterySelectionMode.ChooseOnLaunch
        pickerGroup = null
        session.loadedSignature = baseConfigurationSignature
    }

    val resolvedLanguage = LanguageCatalog.resolve(chosenLanguage).code
    fun chooseMystery(mystery: Mystery) {
        val existing = steps.indexOfFirst { it.mystery == mystery }
        if (prayer.rosary.mysterySelectionMode != MysterySelectionMode.ChooseOnLaunch && existing >= 0) {
            currentIndex = existing
            showsMysteryPicker = false
            return
        }
        val group = mystery.group.name.lowercase(java.util.Locale.ROOT)
        val order = if (prayer.rosary.mysterySelectionMode == MysterySelectionMode.SingleMystery ||
            prayer.rosary.mysterySelectionMode == MysterySelectionMode.ChooseOnLaunch) mystery.order else null
        val options = prayer.rosary.navigationOptions(group, order) ?: return
        val beginAtOpening = requiresMysteryChoice
        sessionOptions = options
        navigationGroup = group
        navigationOrder = order
        steps = services.engine.buildSteps(prayer.copy(languageCode = chosenLanguage, rosary = options))
        currentIndex = if (beginAtOpening) 0 else steps.indexOfFirst { it.mystery == mystery }.coerceAtLeast(0)
        showsMysteryPicker = false
    }
    fun chooseEntireSet(group: MysteryGroup) {
        val rawGroup = group.name.lowercase(java.util.Locale.ROOT)
        val options = prayer.rosary.navigationOptions(rawGroup, null) ?: return
        val beginAtOpening = requiresMysteryChoice
        sessionOptions = options
        navigationGroup = rawGroup
        navigationOrder = null
        steps = services.engine.buildSteps(prayer.copy(languageCode = chosenLanguage, rosary = options))
        currentIndex = if (beginAtOpening) 0 else steps.indexOfFirst { it.mystery?.group == group }.coerceAtLeast(0)
        showsMysteryPicker = false
    }
    if (showsMysteryPicker) {
        AlertDialog(
            onDismissRequest = { if (!requiresMysteryChoice) showsMysteryPicker = false },
            title = { Text(stringResource(R.string.flow_choose_mystery)) },
            text = {
                val setLabel = stringResource(R.string.flow_mystery_set)
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    OptionPickerField<MysteryGroup?>(label = setLabel, options = MysteryGroup.entries,
                        selected = pickerGroup, optionLabel = { it?.let { group -> context.getString(group.displayNameRes) } ?: "—" },
                        onSelect = { pickerGroup = it }, modifier = Modifier.testTag("mysterySetSelector"))
                    pickerGroup?.let { group ->
                        LazyColumn {
                            item {
                                TextButton(onClick = { chooseEntireSet(group) }, modifier = Modifier.testTag("chooseMystery.entireSet")) {
                                    Text(stringResource(R.string.flow_entire_set))
                                }
                            }
                            items(MysteryCatalog.forGroup(group)) { mystery ->
                                TextButton(onClick = { chooseMystery(mystery) },
                                    modifier = Modifier.testTag("chooseMystery.${group.name.lowercase(java.util.Locale.ROOT)}.${mystery.order}")) {
                                    Text(HebrewDisplayText.unpoint(MysteryTranslations.get(LanguageCatalog.uiLanguageCode(), mystery.imageKey).title))
                                }
                            }
                        }
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = {
                    showsMysteryPicker = false
                    if (requiresMysteryChoice) onBack()
                }) { Text(stringResource(R.string.common_cancel)) }
            },
        )
    }
    LaunchedEffect(resolvedLanguage) {
        if (languageCode == resolvedLanguage) return@LaunchedEffect
        if (steps.isNotEmpty()) {
            val position = currentIndex
            // AppCompat retains this session across a locale recreation. Refresh inherited
            // text without reloading its bookmark or discarding the active position.
            languageCode = resolvedLanguage
            steps = services.engine.buildSteps(prayer.copy(languageCode = resolvedLanguage, rosary = sessionOptions))
            currentIndex = position.coerceIn(0, (steps.size - 1).coerceAtLeast(0))
        }
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
                rosaryNavigationGroup = navigationGroup,
                rosaryNavigationOrder = navigationOrder,
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
                sessionOptions = prayer.rosary.copy()
                navigationGroup = null
                navigationOrder = null
                pickerGroup = null
                steps = services.engine.buildSteps(prayer.copy(languageCode = chosenLanguage, rosary = sessionOptions))
                showsMysteryPicker = prayer.rosary.mysterySelectionMode == MysterySelectionMode.ChooseOnLaunch
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
                rosaryNavigationGroup = navigationGroup,
                rosaryNavigationOrder = navigationOrder,
            )
        }
        onBack()
    }

    fun finish() {
        PrayerRunProgressStore.clear(context, runKey)
        runReady = false
        onBack()
    }

    BackHandler(onBack = ::leave)

    PrayerStepFlowScreen(
        title = stringResource(R.string.rosary_praying),
        step = currentStep,
        currentIndex = currentIndex,
        sessionPaused = !runReady || showsMysteryPicker || pendingResume != null,
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
        wideAccessoryWidth = beadWideWidth(beadLayout),
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
                            onClick = {
                                nextMystery?.let { target ->
                                    if (target == steps.size) finish() else currentIndex = target
                                }
                            },
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
            IconButton(onClick = { pickerGroup = null; showsMysteryPicker = true }) {
                Icon(Icons.AutoMirrored.Filled.List, contentDescription = stringResource(R.string.flow_choose_mystery))
            }
            PrayerLanguagePicker(
                devotionId = "rosary",
                chosenLanguage = chosenLanguage,
                expanded = languageMenuExpanded,
                onExpandedChange = { languageMenuExpanded = it },
                onSelect = { raw ->
                    val position = currentIndex
                    chosenLanguage = raw
                    languageCode = LanguageCatalog.resolve(raw).code
                    steps = services.engine.buildSteps(prayer.copy(languageCode = raw, rosary = sessionOptions))
                    currentIndex = position.coerceIn(0, (steps.size - 1).coerceAtLeast(0))
                    // A saved preset remembers an in-prayer language choice just like a custom
                    // devotion; an ad-hoc Prayer simply has no matching row and is left alone.
                    scope.launch {
                        services.presetStore.get(prayer.id)?.let { saved ->
                            services.presetStore.updateIfPresent(saved.copy(languageCode = raw))
                        }
                    }
                },
            )
        },
    )
}
