package com.dkaluta.prosary.ui.shared

import androidx.activity.compose.BackHandler
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.StarBorder
import androidx.compose.foundation.layout.Row
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Text
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import com.dkaluta.prosary.R
import com.dkaluta.prosary.content.audio.AudioPlaybackController
import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import com.dkaluta.prosary.models.FavoriteDevotions
import com.dkaluta.prosary.models.CustomDevotionLanguageSwitch
import com.dkaluta.prosary.models.DevotionEntryContext
import com.dkaluta.prosary.models.LanguageCatalog
import com.dkaluta.prosary.models.MultiDayRun
import com.dkaluta.prosary.models.MultiDayRuns
import com.dkaluta.prosary.models.MultiDayStatus
import com.dkaluta.prosary.reminders.ReminderScheduler
import com.dkaluta.prosary.models.Prayer
import com.dkaluta.prosary.models.PrayerKind
import com.dkaluta.prosary.models.PrayerRunKeys
import com.dkaluta.prosary.models.PrayerRunProgress
import com.dkaluta.prosary.models.PrayerRunProgressStore
import com.dkaluta.prosary.models.PrayerRunSignatures
import com.dkaluta.prosary.models.RosaryStep
import com.dkaluta.prosary.services.AppServices
import com.dkaluta.prosary.services.LocalAppServices
import com.dkaluta.prosary.ui.rosaryflow.BeadLayout
import com.dkaluta.prosary.ui.rosaryflow.BeadProgressView
import com.dkaluta.prosary.typography.HebrewDisplayText
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

/** The single flow screen for every [PrayerKind.Custom] devotion. It reads its title and
 * structure from [PrayerPackStore]/[com.dkaluta.prosary.engine.PrayerEngine], so a new generic
 * devotion needs no new screen. A decade/bead-structured ("rosary" type)
 * devotion gets the same bead track as the Rosary; flat devotions (no step carries a
 * decadeIndex) get none.
 *
 * [prayer] is set when launched from an existing saved configuration (via PrayerDispatchScreen),
 * avoiding a second store read. The session language follows its languageCode (sentinel = the app default), switchable
 * in place from the toolbar's language menu — testers assumed generic devotions shipped fewer
 * languages than they do when the only switch was the app-level setting. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CustomDevotionFlowScreen(
    devotionId: String,
    prayer: Prayer? = null,
    /** Explicit handoffs (Rosary → Litany) retain the just-prayed language and closing form. */
    initialVariantId: String? = null,
    initialLanguageCode: String? = null,
    onBack: () -> Unit,
    /** Opens another devotion in place of this one — how a finished series hands over to the
     * one its bundle suggests. Null (previews, tests) just closes the flow. */
    onOpenDevotion: ((String) -> Unit)? = null,
) {
    val services = LocalAppServices.current
    val scope = rememberCoroutineScope()

    var steps by remember { mutableStateOf<List<RosaryStep>>(emptyList()) }
    var currentIndex by remember { mutableIntStateOf(0) }
    var isRightToLeft by remember { mutableStateOf(false) }
    var seasonColor by remember { mutableStateOf(Color.Transparent) }
    var languageCode by remember { mutableStateOf<String?>(null) }
    var matchingFavoriteId by remember { mutableStateOf(prayer?.id) }
    var displayName by remember { mutableStateOf(devotionId) }
    val variantFollowsEntry = DevotionEntryContext.locksVariant(devotionId)
    var variantId by remember { mutableStateOf(DevotionEntryContext.initialVariant(devotionId, initialVariantId, prayer?.variantId)) }
    var variantMenuExpanded by remember { mutableStateOf(false) }
    /** The favorite's raw language choice: an explicit code, or the sentinel ("follow the
     * app-level default setting"). [languageCode] is always the resolved code. */
    var chosenLanguage by remember { mutableStateOf(initialLanguageCode ?: prayer?.languageCode ?: LanguageCatalog.defaultSentinel) }
    /** The favorite's bundle option overrides. Keep them in the session model so both the
     * generated flow and its continuation signature follow the configuration being prayed. */
    var customOptions by remember(prayer?.id, devotionId) {
        mutableStateOf(prayer?.customOptions.orEmpty())
    }
    var languageMenuExpanded by remember { mutableStateOf(false) }
    /** Multi-day devotions: the day this session prays (0-based; sourced from the favorite). */
    var dayIndex by remember { mutableIntStateOf(prayer?.dayIndex ?: 0) }
    var dayMenuExpanded by remember { mutableStateOf(false) }
    /** Set when a day was missed: the day that should have happened and the one today calls for. */
    var missedDayChoice by remember { mutableStateOf<Pair<Int, Int>?>(null) }
    var isPinned by remember { mutableStateOf(false) }
    /** Set when the last day of a series is finished and the bundle's suggestedNext resolves to
     * something this device actually has. */
    var completionSuggestion by remember { mutableStateOf<Pair<String, String>?>(null) }
    var pendingResume by remember(prayer?.id, devotionId) { mutableStateOf<PrayerRunProgress?>(null) }
    var checkedRunKey by remember(prayer?.id, devotionId) { mutableStateOf<String?>(null) }
    var runReady by remember(prayer?.id, devotionId) { mutableStateOf(false) }
    var resetAudioOnNextRebuild by remember(prayer?.id, devotionId) { mutableStateOf(false) }

    fun persistDayIndex(value: Int) {
        matchingFavoriteId?.let { id ->
            scope.launch {
                services.presetStore.get(id)?.let { favorite ->
                    services.presetStore.save(favorite.copy(dayIndex = value))
                }
            }
        }
    }

    val context = LocalContext.current
    val audio = remember { AudioPlaybackController() }
    DisposableEffect(Unit) { onDispose { audio.stop() } }

    /** After a manual Back/Next (or a fresh load), bring the recording to the chapter that
     * narrates the step at [index] — when one does; steps between chapter hints leave the
     * audio where it is. */
    fun alignAudioToStep(index: Int) {
        val chapters = audio.track?.chapters ?: return
        val target = chapters.indexOfFirst { it.stepIndex == index }
        if (target >= 0 && audio.currentChapterIndex != target) audio.seekToChapter(target)
    }

    /** The recording for this session, if the bundle ships one: language must match, and the
     * track's variant (null = the bundle's single/default form) must match the session's.
     * First declared match wins — audio.json order is the author's preference order. */
    fun pickAudioTrack(currentStepIndex: Int, allowStoredPosition: Boolean = true) {
        val definition = PrayerPackStore.definition(devotionId)
        val defaultVariantId = definition?.effectiveVariantId(null, languageCode)
            ?: definition?.variants?.firstOrNull()?.id
        val effectiveVariant = variantId ?: defaultVariantId
        val match = PrayerPackStore.audioTracks(devotionId).firstOrNull {
            it.language == languageCode && (it.variantId ?: defaultVariantId) == effectiveVariant
        }
        if (match != null) {
            if (audio.track?.id != match.id || !audio.isLoaded) {
                audio.load(context, devotionId, match)
                if (audio.didRestorePosition && allowStoredPosition) {
                    // Resumed mid-recording: pull the page to the restored chapter instead of
                    // yanking the recording back to the step-0 chapter.
                    val hint = audio.currentChapterIndex
                        ?.let { audio.track?.chapters?.getOrNull(it)?.stepIndex }
                    if (hint != null && hint in steps.indices) currentIndex = hint
                } else {
                    if (!allowStoredPosition) audio.seek(0.0)
                    alignAudioToStep(currentStepIndex)
                }
            } else if (!allowStoredPosition) {
                audio.seek(0.0)
                alignAudioToStep(currentStepIndex)
            }
        } else {
            audio.stop()
        }
    }

    LaunchedEffect(prayer, devotionId, variantId, dayIndex) {
        displayName = PrayerPackStore.info(devotionId)?.localizedDisplayName ?: devotionId

        // The favorite (when one exists) carries the language and variant to pray in, so it
        // loads before the first build rather than after it.
        if (matchingFavoriteId == null && prayer == null && initialVariantId == null && initialLanguageCode == null) {
            val all = runCatching { services.presetStore.all() }.getOrDefault(emptyList())
            val favorite = all.firstOrNull { it.kind == PrayerKind.Custom && it.customDevotionId == devotionId }
            matchingFavoriteId = favorite?.id
            if (favorite != null) {
                chosenLanguage = favorite.languageCode
                customOptions = favorite.customOptions
                if (!variantFollowsEntry && variantId == null && favorite.variantId != null) {
                    variantId = favorite.variantId
                }
                dayIndex = favorite.dayIndex ?: 0
            }
        }
        isPinned = FavoriteDevotions.contains(context, devotionId, impliedPinnedIds(services))

        // A series decides its own day: today's if it is unprayed, the same day again if it was
        // already prayed today, and a choice when one was missed.
        val definition = PrayerPackStore.definition(devotionId)
        val days = definition?.days.orEmpty()
        if (days.size > 1 && (definition?.dayProgression ?: "series") == "series") {
            val run = MultiDayRuns.run(context, devotionId)
            when (val resumption = run?.resumption(days.size) ?: MultiDayRun.Resumption.Start) {
                is MultiDayRun.Resumption.Start -> dayIndex = 0
                is MultiDayRun.Resumption.Resume -> dayIndex = resumption.day
                is MultiDayRun.Resumption.Choose -> {
                    dayIndex = resumption.missed
                    missedDayChoice = resumption.missed to resumption.next
                }
                is MultiDayRun.Resumption.Complete -> dayIndex = days.size - 1
            }
            // Praying twice in one day re-prays that day rather than eating tomorrow's.
            if (run != null && run.hasPrayedToday()) {
                run.prayedDays.lastOrNull()?.let { dayIndex = it }
            }
        }

        val candidateRunKey = PrayerRunKeys.custom(devotionId, variantId, dayIndex)
        val savedRun = if (checkedRunKey != candidateRunKey) {
            PrayerRunProgressStore.progress(context, candidateRunKey)
        } else {
            null
        }
        val configuredLanguage = chosenLanguage
        val candidateLanguage = savedRun?.languageCode ?: configuredLanguage
        val candidateResolvedLanguage = PrayerPackStore.effectiveLanguage(devotionId, candidateLanguage)
        val candidateEffectiveVariantId = definition?.effectiveVariantId(
            variantId,
            candidateResolvedLanguage,
        )
        val signature = PrayerRunSignatures.custom(
            devotionId,
            candidateEffectiveVariantId,
            dayIndex,
            customOptions,
        )
        fun build(language: String) = services.engine.buildSteps(
            Prayer(
                kind = PrayerKind.Custom, languageCode = language,
                customDevotionId = devotionId, variantId = variantId, dayIndex = dayIndex,
                customOptions = customOptions,
            ),
        )
        val candidateSteps = build(candidateLanguage)
        val validRun = if (checkedRunKey != candidateRunKey) {
            savedRun?.takeIf {
                (initialLanguageCode == null || it.languageCode == configuredLanguage) && it.canResume(
                    candidateSteps.size,
                    expectedConfigurationSignature = signature,
                )
            }
        } else {
            null
        }
        // Only a valid bookmark may supply the session language. A stale one (for example,
        // after editing a favorite's options) falls back to the favorite's current language.
        val sessionLanguage = validRun?.languageCode ?: configuredLanguage
        chosenLanguage = sessionLanguage
        languageCode = PrayerPackStore.effectiveLanguage(devotionId, sessionLanguage)
        displayName = PrayerPackStore.info(devotionId)?.displayNameIn(languageCode ?: sessionLanguage) ?: devotionId
        isRightToLeft = LanguageCatalog.resolve(languageCode ?: LanguageCatalog.defaultCode).isRightToLeft
        val built = if (sessionLanguage == candidateLanguage) candidateSteps else build(sessionLanguage)
        steps = built
        currentIndex = 0
        seasonColor = services.calendar.seasonColorToday()
        if (checkedRunKey != candidateRunKey) {
            checkedRunKey = candidateRunKey
            pendingResume = validRun
            runReady = validRun == null
            if (savedRun != null && validRun == null) {
                PrayerRunProgressStore.clear(context, candidateRunKey)
            }
        }
        pickAudioTrack(
            0,
            allowStoredPosition = pendingResume == null && !resetAudioOnNextRebuild,
        )
        resetAudioOnNextRebuild = false
        if (pendingResume != null) currentIndex = 0
    }

    val currentRunKey = PrayerRunKeys.custom(devotionId, variantId, dayIndex)
    val currentEffectiveVariantId = PrayerPackStore.definition(devotionId)
        ?.effectiveVariantId(variantId, languageCode)
    val configurationSignature = PrayerRunSignatures.custom(
        devotionId,
        currentEffectiveVariantId,
        dayIndex,
        customOptions,
    )

    fun switchDay(newDayIndex: Int) {
        val targetRunKey = PrayerRunKeys.custom(devotionId, variantId, newDayIndex)
        PrayerRunProgressStore.clear(context, currentRunKey)
        PrayerRunProgressStore.clear(context, targetRunKey)
        pendingResume = null
        if (newDayIndex == dayIndex) {
            currentIndex = 0
            audio.seek(0.0)
            runReady = true
        } else {
            resetAudioOnNextRebuild = true
            runReady = false
            dayIndex = newDayIndex
        }
        persistDayIndex(newDayIndex)
    }
    LaunchedEffect(
        runReady,
        currentIndex,
        chosenLanguage,
        steps.size,
        currentRunKey,
        configurationSignature,
    ) {
        if (!runReady || steps.isEmpty()) return@LaunchedEffect
        if (currentIndex in 1 until steps.size) {
            PrayerRunProgressStore.save(
                context,
                currentRunKey,
                currentIndex,
                chosenLanguage,
                configurationSignature,
            )
        } else if (currentIndex == 0) {
            PrayerRunProgressStore.clear(context, currentRunKey)
        }
    }

    // MediaPlayer has no position listener — this coarse tick mirrors its clock into the
    // controller's observable time while playing (4 Hz: plenty for the bar and chapters).
    LaunchedEffect(audio.isPlaying) {
        while (isActive && audio.isPlaying) {
            audio.refreshTime()
            delay(250)
        }
    }

    // The recording's chapters drive the text while it plays: entering a chapter that carries
    // a stepIndex hint turns the page. Hints are advisory (the built sequence is option- and
    // calendar-dependent), so out-of-range ones are ignored rather than trusted.
    LaunchedEffect(audio.currentChapterIndex) {
        val chapterIndex = audio.currentChapterIndex ?: return@LaunchedEffect
        val hint = audio.track?.chapters?.getOrNull(chapterIndex)?.stepIndex ?: return@LaunchedEffect
        if (hint in steps.indices && currentIndex != hint) currentIndex = hint
    }

    val currentStep = steps.getOrNull(currentIndex)
    val showsBeadTrack = steps.any { it.decadeIndex != null }
    // Per form, not per bundle: one recension of a chaplet can end with the cross where
    // another does not, and the bead track draws a closing bead on the strength of this.
    val hasClosingCross = PrayerPackStore.definition(devotionId)?.let {
        it.resolvedRosary(it.effectiveVariantId(variantId, languageCode)).hasClosingCross
    } ?: false
    val beadLayout = remember(steps, currentIndex) {
        BeadLayout.build(steps, currentIndex, hasClosingCross = hasClosingCross)
    }

    pendingResume?.let { saved ->
        ResumePrayerDialog(
            progress = saved,
            totalSteps = steps.size,
            onContinue = {
                currentIndex = saved.stepIndex
                alignAudioToStep(saved.stepIndex)
                missedDayChoice = null
                pendingResume = null
                runReady = true
            },
            onRestart = {
                PrayerRunProgressStore.clear(context, currentRunKey)
                currentIndex = 0
                audio.seek(0.0)
                missedDayChoice = null
                pendingResume = null
                runReady = true
            },
        )
    }

    completionSuggestion?.let { (suggestedId, suggestedName) ->
        AlertDialog(
            onDismissRequest = { completionSuggestion = null; onBack() },
            title = { Text(stringResource(R.string.multi_day_completed_title, suggestedName)) },
            confirmButton = {
                TextButton(onClick = {
                    completionSuggestion = null
                    onOpenDevotion?.invoke(suggestedId) ?: onBack()
                }) { Text(stringResource(R.string.multi_day_pray_next, suggestedName)) }
            },
            dismissButton = {
                TextButton(onClick = { completionSuggestion = null; onBack() }) {
                    Text(stringResource(R.string.multi_day_not_now))
                }
            },
        )
    }

    // A missed day is a real choice, not an error: take the day that should have happened,
    // stay with the calendar, or start the run over.
    if (pendingResume == null) missedDayChoice?.let { (missed, next) ->
        AlertDialog(
            onDismissRequest = { missedDayChoice = null },
            title = { Text(stringResource(R.string.multi_day_missed_title)) },
            confirmButton = {
                    TextButton(onClick = {
                        switchDay(missed)
                        missedDayChoice = null
                }) { Text(stringResource(R.string.multi_day_pray_missed, missed + 1)) }
            },
            dismissButton = {
                Row {
                    TextButton(onClick = {
                        switchDay(next)
                        missedDayChoice = null
                    }) { Text(stringResource(R.string.multi_day_pray_today, next + 1)) }
                    TextButton(onClick = {
                        MultiDayRuns.startFresh(context, devotionId)
                        ReminderScheduler.refreshSeries(context, devotionId)
                        switchDay(0)
                        missedDayChoice = null
                    }) { Text(stringResource(R.string.multi_day_start_over)) }
                }
            },
        )
    }

    fun leave() {
        if (runReady && currentIndex in 1 until steps.size) {
            PrayerRunProgressStore.save(
                context,
                currentRunKey,
                currentIndex,
                chosenLanguage,
                configurationSignature,
            )
        }
        onBack()
    }

    BackHandler(onBack = ::leave)

    PrayerStepFlowScreen(
        title = displayName,
        step = currentStep,
        currentIndex = currentIndex,
        totalSteps = steps.size,
        seasonColor = seasonColor,
        isRightToLeft = isRightToLeft,
        languageCode = languageCode,
        canGoBack = currentIndex > 0,
        onBack = {
            if (currentIndex > 0) {
                currentIndex--
                alignAudioToStep(currentIndex)
            }
        },
        onNext = {
            if (steps.isEmpty() || currentIndex == steps.size - 1) {
                PrayerRunProgressStore.clear(context, currentRunKey)
                // Finishing a multi-day session advances the favorite to the next day (staying
                // on the last once complete) — tomorrow opens where the novena left off.
                val definition = PrayerPackStore.definition(devotionId)
                val days = definition?.days.orEmpty()
                if (days.size > 1) {
                    // A series advances by calendar day, so record *which* day was prayed and
                    // let the run decide what comes next — praying twice today must not skip
                    // tomorrow's day.
                    if ((definition?.dayProgression ?: "series") == "series") {
                        MultiDayRuns.recordPrayed(context, devotionId, dayIndex)
                        // The remaining days keep their prompts; the finished ones lose theirs.
                        ReminderScheduler.refreshSeries(context, devotionId)

                        // The last day earns the bundle's parting suggestion — but only when it
                        // names a devotion this device has, so a hand-written series can point
                        // at its author's other work without leaving a dead end elsewhere.
                        val run = MultiDayRuns.run(context, devotionId)
                        val suggestion = MultiDayStatus.suggestedNext(devotionId)
                        if (run?.isComplete(days.size) == true && suggestion != null) {
                            persistDayIndex(minOf(dayIndex + 1, days.size - 1))
                            completionSuggestion = suggestion
                            return@PrayerStepFlowScreen
                        }
                    }
                    persistDayIndex(minOf(dayIndex + 1, days.size - 1))
                }
                onBack()
            } else {
                currentIndex++
                alignAudioToStep(currentIndex)
            }
        },
        onNavigateUp = ::leave,
        audioBar = if (audio.isLoaded) {
            {
                val track = audio.track
                val titles = remember(track) {
                    track?.chapters?.map { chapter ->
                        chapter.title
                            ?: chapter.titleKey?.let { PrayerPackStore.resolveBodyText(devotionId, track.language, it) }
                            ?: ""
                    }.orEmpty()
                }
                AudioPlaybackBar(controller = audio, seasonColor = seasonColor, chapterTitles = titles)
            }
        } else {
            null
        },
        audioIsPlaying = audio.isPlaying,
        accessory = if (showsBeadTrack) {
            { isWide, hasRoomForSingleMinorColumn ->
                BeadProgressView(layout = beadLayout, isWide = isWide, hasRoomForSingleMinorColumn = hasRoomForSingleMinorColumn)
            }
        } else {
            { _, _ -> }
        },
        topBarActions = {
            // Language switcher — the app-level prayer-language setting was the only way to
            // change a generic devotion's language, and testers didn't find it. Keep the current
            // position when the form is unchanged; a language-owned form starts at step zero.
            PrayerLanguagePicker(
                devotionId = devotionId,
                chosenLanguage = chosenLanguage,
                expanded = languageMenuExpanded,
                onExpandedChange = { languageMenuExpanded = it },
                onSelect = { raw ->
                    val definition = PrayerPackStore.definition(devotionId)
                    val previousEffectiveVariantId = definition
                        ?.effectiveVariantId(variantId, languageCode)
                    val nextLanguageCode = PrayerPackStore.effectiveLanguage(devotionId, raw)
                    val nextEffectiveVariantId = definition
                        ?.effectiveVariantId(variantId, nextLanguageCode)
                    chosenLanguage = raw
                    languageCode = nextLanguageCode
                    displayName = PrayerPackStore.info(devotionId)?.displayNameIn(nextLanguageCode) ?: devotionId
                    isRightToLeft = LanguageCatalog.resolve(languageCode ?: LanguageCatalog.defaultCode).isRightToLeft
                    val position = currentIndex
                    steps = services.engine.buildSteps(
                        Prayer(
                            kind = PrayerKind.Custom, languageCode = raw,
                            customDevotionId = devotionId, variantId = variantId,
                            dayIndex = dayIndex,
                            customOptions = customOptions,
                        ),
                    )
                    currentIndex = CustomDevotionLanguageSwitch.indexAfterSwitch(
                        position,
                        previousEffectiveVariantId,
                        nextEffectiveVariantId,
                        steps.size,
                    )
                    if (previousEffectiveVariantId != nextEffectiveVariantId) {
                        PrayerRunProgressStore.clear(context, currentRunKey)
                        pendingResume = null
                        runReady = true
                    }
                    pickAudioTrack(currentIndex, allowStoredPosition = false)
                    matchingFavoriteId?.let { id ->
                        scope.launch {
                            services.presetStore.get(id)?.let { favorite ->
                                services.presetStore.save(favorite.copy(languageCode = raw))
                            }
                        }
                    }
                },
            )
            // Day picker — multi-day ("days"-type) devotions only: jump to any day; finishing
            // a session advances the favorite to the next one automatically.
            val days = PrayerPackStore.definition(devotionId)?.days.orEmpty()
            if (days.size > 1) {
                IconButton(onClick = { dayMenuExpanded = true }) {
                    Icon(Icons.Filled.DateRange, contentDescription = stringResource(R.string.flow_day))
                }
                DropdownMenu(expanded = dayMenuExpanded, onDismissRequest = { dayMenuExpanded = false }) {
                    days.forEachIndexed { index, day ->
                        val label = HebrewDisplayText.unpoint(
                            day.period?.let { "$it — ${day.localizedName}" } ?: day.localizedName,
                        )
                        DropdownMenuItem(
                            text = { Text(label) },
                            leadingIcon = if (index == dayIndex) {
                                { Icon(Icons.Filled.Check, contentDescription = null) }
                            } else {
                                null
                            },
                            onClick = {
                                dayMenuExpanded = false
                                if (dayIndex != index) {
                                    switchDay(index)
                                }
                            },
                        )
                    }
                }
            }
            // Variant switcher — only for bundles declaring alternate step-sets (e.g. the
            // Stations' traditional vs. scriptural forms). Switching rebuilds the session from
            // step 0 (via the LaunchedEffect keyed on variantId) and persists the choice to the
            // matching favorite when one exists.
            val flowDefinition = PrayerPackStore.definition(devotionId)
            val variants = flowDefinition?.variants
            if (!variantFollowsEntry && variants != null && variants.size > 1) {
                // "No explicit choice" resolves per the prayer language (a rite can declare a
                // form its own), so both the checkmark and the persistence baseline use the
                // effective default.
                val defaultVariantId =
                    flowDefinition.effectiveVariantId(null, languageCode) ?: variants.first().id
                IconButton(onClick = { variantMenuExpanded = true }) {
                    Icon(Icons.AutoMirrored.Filled.MenuBook, contentDescription = stringResource(R.string.flow_choose_form))
                }
                DropdownMenu(expanded = variantMenuExpanded, onDismissRequest = { variantMenuExpanded = false }) {
                    for (variant in variants) {
                        val isCurrent = variant.id == (variantId ?: defaultVariantId)
                        DropdownMenuItem(
                            text = { Text(variant.localizedName) },
                            leadingIcon = if (isCurrent) {
                                { Icon(Icons.Filled.Check, contentDescription = null) }
                            } else {
                                null
                            },
                            onClick = {
                                variantMenuExpanded = false
                                val newVariantId = if (variant.id == defaultVariantId) null else variant.id
                                if (variantId != newVariantId) {
                                    val targetRunKey = PrayerRunKeys.custom(
                                        devotionId,
                                        newVariantId,
                                        dayIndex,
                                    )
                                    PrayerRunProgressStore.clear(context, currentRunKey)
                                    PrayerRunProgressStore.clear(context, targetRunKey)
                                    pendingResume = null
                                    runReady = false
                                    resetAudioOnNextRebuild = true
                                    variantId = newVariantId
                                    matchingFavoriteId?.let { id ->
                                        scope.launch {
                                            services.presetStore.get(id)?.let { favorite ->
                                                services.presetStore.save(favorite.copy(variantId = newVariantId))
                                            }
                                        }
                                    }
                                }
                            },
                        )
                    }
                }
            }
            IconButton(onClick = {
                scope.launch {
                    // Pinning is what puts a devotion on Pray; the Prayer alongside it only
                    // carries this devotion's language/variant/day, so unpinning leaves those
                    // settings intact.
                    val implied = impliedPinnedIds(services)
                    FavoriteDevotions.toggle(context, devotionId, implied)
                    isPinned = FavoriteDevotions.contains(context, devotionId, implied)
                    if (isPinned && matchingFavoriteId == null) {
                        matchingFavoriteId = createCustomDevotionFavorite(services, devotionId, displayName)
                    }
                }
            }, modifier = Modifier.testTag("pinDevotionButton")) {
                Icon(
                    if (isPinned) Icons.Filled.Star else Icons.Filled.StarBorder,
                    contentDescription = if (isPinned) stringResource(R.string.home_remove_from_pray) else stringResource(R.string.home_add_to_pray),
                )
            }
        },
    )
}

/** A devotion counts as pinned by default when it already has a saved configuration — the same
 * fallback the Pray tab uses, so the star agrees with what that tab shows. */
private suspend fun impliedPinnedIds(services: AppServices): List<String> =
    runCatching { services.presetStore.all() }.getOrDefault(emptyList()).mapNotNull { prayer ->
        when (prayer.kind) {
            PrayerKind.Rosary -> "rosary"
            PrayerKind.JesusPrayer -> "jesusPrayer"
            PrayerKind.Custom -> prayer.customDevotionId
        }
    }

private suspend fun createCustomDevotionFavorite(
    services: AppServices,
    devotionId: String,
    displayName: String,
): String {
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
