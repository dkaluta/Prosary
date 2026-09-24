package com.dkaluta.prosary.ui.shared

import android.app.Activity
import android.os.SystemClock
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.LruCache
import androidx.activity.compose.LocalActivity
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material.icons.filled.Translate
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import android.view.HapticFeedbackConstants
import androidx.compose.runtime.LaunchedEffect
import com.dkaluta.prosary.content.PrayerTranslations
import com.dkaluta.prosary.models.LanguageCatalog
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.Constraints
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.repeatOnLifecycle
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.text.selection.DisableSelection
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import com.dkaluta.prosary.R
import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.models.RosaryStep
import com.dkaluta.prosary.typography.HebrewDisplayText
import com.dkaluta.prosary.typography.PrayerTypography
import com.dkaluta.prosary.ui.theme.extraColors
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext

/**
 * Shared presentation chrome for any linear prayer flow: season-color bar, progress readout (a
 * fraction + "N of M" for a bounded flow, a bare running count for an open-ended one), wide
 * (tablet/landscape) vs narrow adaptive layout with RTL-aware scrolling text, and a
 * Back/Next-or-Finish footer. Used by RosaryFlowScreen (passing the bead track as its accessory)
 * and by devotions with no equivalent progress track at all (Angelus, Jesus Prayer), which pass
 * no accessory — the default no-op simply omits that slot rather than reserving empty space.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PrayerStepFlowScreen(
    title: String,
    step: RosaryStep?,
    currentIndex: Int,
    totalSteps: Int?,
    seasonColor: Color,
    isRightToLeft: Boolean,
    languageCode: String?,
    canGoBack: Boolean,
    onBack: () -> Unit,
    onNext: () -> Unit,
    onNavigateUp: () -> Unit,
    topBarActions: @Composable () -> Unit = {},
    accessory: @Composable (isWide: Boolean, hasRoomForSingleMinorColumn: Boolean) -> Unit = { _, _ -> },
    /** When set ("Pray" — the Jesus Prayer), a large round button below the text becomes the
     * flow's one big tap target and replaces the footer's Next entirely — for a counter flow,
     * advancing is the only action, so it deserves more than a corner button. */
    centralActionLabel: String? = null,
    /** The audio transport strip (AudioPlaybackBar), when the session has a narrated recording —
     * same optional-slot convention as [accessory]. Rendered above the footer divider. */
    audioBar: (@Composable () -> Unit)? = null,
    /** True while that recording is actually playing: the timer auto-advance stands down, since
     * the audio's chapters are driving the steps and two advance drivers would fight. */
    audioIsPlaying: Boolean = false,
    sessionPaused: Boolean = false,
    wideAccessoryWidth: Dp = 0.dp,
    prayerBundleId: String = "rosary",
    /** Basic-prayer navigation titles name the sourced prayer; user/devotion names do not. */
    titleFollowsPrayerScript: Boolean = false,
) {
    val chrome: PrayerFlowChromeState = viewModel()
    val interfaceDirection = LocalLayoutDirection.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val activity = LocalActivity.current
    DisposableEffect(chrome, lifecycleOwner) {
        onDispose { chrome.captureReadingAnchor() }
    }
    LaunchedEffect(chrome, lifecycleOwner) {
        snapshotFlow { chrome.reading.isScrollInProgress }.collect { scrolling ->
            if (scrolling) chrome.releaseReadingAnchor()
        }
    }
    // Matches the pre-load "no step yet" instant to "last step" so the footer doesn't flash a
    // "Next" label a moment before content briefly reads "Finish" (imperceptible in practice,
    // since loading is a near-instant in-memory lookup).
    val isLastStep = step == null || (totalSteps != null && currentIndex >= totalSteps - 1)

    // Seconds between automatic advances (hands-free praying); 0 = off. One app-wide setting
    // shared by every flow, so a choice made in the Rosary carries into the Stations.
    var autoAdvanceSeconds by remember { mutableIntStateOf(AppSettings.autoAdvanceSeconds) }
    var autoAdvanceMenuExpanded by rememberSaveable { mutableStateOf(false) }
    // A reading-aid choice belongs to this prayer run. Keep it through step changes and layout
    // recompositions, but discard it when this flow leaves composition.
    var showsTransliteration by rememberSaveable { mutableStateOf(false) }
    var initializedScriptLanguage by rememberSaveable { mutableStateOf<String?>(null) }
    var aramaicSessionScript by rememberSaveable { mutableStateOf<String?>(null) }
    val scriptLanguage = LanguageCatalog.fallbackChain(languageCode).firstOrNull()
    LaunchedEffect(scriptLanguage, step == null) {
        if (step != null && initializedScriptLanguage != scriptLanguage) {
            initializedScriptLanguage = scriptLanguage
            aramaicSessionScript = if (scriptLanguage == "arc") AppSettings.aramaicDefaultScript else null
        }
    }
    val usesAlternateText = if (step != null && aramaicSessionScript != null) {
        PrayerTranslations.initialTransliteration(languageCode, step.body, step.transliteratedBody,
            aramaicSessionScript!!) ?: showsTransliteration
    } else showsTransliteration
    val visibleBody = step?.let { if (usesAlternateText) it.transliteratedBody ?: it.body else it.body }.orEmpty()
    val visibleFlowTitle = if (titleFollowsPrayerScript) PrayerTranslations.flowTitle(title, languageCode,
        PrayerTypography.scriptOf(visibleBody) == PrayerTypography.Script.Syriac, prayerBundleId)
        else HebrewDisplayText.unpoint(title)
    val toggleTransliteration = {
        if (aramaicSessionScript != null) aramaicSessionScript = if (aramaicSessionScript == "Syrc") "Hebr" else "Syrc"
        else showsTransliteration = !showsTransliteration
    }

    // The identity is retained with the reader. A real step starts at its heading; folding
    // or recreating the Activity on that same step keeps the current paragraph and offset.
    LaunchedEffect(step?.id, currentIndex) {
        step?.let {
            val identity = if (centralActionLabel != null) it.id else "${it.id}:$currentIndex"
            chrome.showReading(identity)
        }
    }

    // A gentle tap when the step changes — tester-requested (Erez), off by default, app-wide
    // like autoAdvanceSeconds. Keyed to the step change rather than the button, so Back and a
    // timer advance feel the same as Next. The initial composition is skipped: opening a flow
    // is not a step change.
    val flowView = LocalView.current
    var hapticArmed by remember { mutableStateOf(false) }
    LaunchedEffect(currentIndex) {
        if (hapticArmed && AppSettings.hapticsOnAdvance && step != null) {
            flowView.performHapticFeedback(HapticFeedbackConstants.CONTEXT_CLICK)
        }
        hapticArmed = true
    }

    // Restarts whenever the step, the interval, or the loaded state changes — so tapping
    // Back/Next resets the countdown, and turning the setting off cancels it. Never fires on
    // the last step: auto-"Finish" would dismiss the whole flow mid-prayer. Suspended outright
    // while a recording plays (audioIsPlaying is a key, so pausing re-arms it).
    LaunchedEffect(lifecycleOwner, autoAdvanceSeconds, currentIndex, step != null, audioIsPlaying, sessionPaused) {
        if (autoAdvanceSeconds <= 0 || step == null || isLastStep || audioIsPlaying || sessionPaused) {
            chrome.cancelCountdown()
            return@LaunchedEffect
        }
        lifecycleOwner.lifecycle.repeatOnLifecycle(Lifecycle.State.STARTED) {
            try {
                val identity = "$currentIndex:$autoAdvanceSeconds"
                delay(chrome.remainingDelay(identity, autoAdvanceSeconds * 1000L, SystemClock.elapsedRealtime()))
                chrome.cancelCountdown()
                onNext()
            } finally {
                // Folding replaces the Activity briefly; an ordinary background/lock instead
                // pauses prayer and starts a fresh interval when the person returns.
                if (activity?.isChangingConfigurations != true &&
                    !lifecycleOwner.lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)) {
                    chrome.cancelCountdown()
                }
            }
        }
    }

    BoxWithConstraints(modifier = Modifier.fillMaxSize()) {
        // A landscape phone is wide but short (compact height), unlike a tablet/wide split which
        // has vertical room to spare — everything here shrinks in that case to keep the whole
        // layout, footer included, from growing taller than the screen.
        val isCompactHeight = maxHeight < 480.dp
        val compactButtonPadding = PaddingValues(horizontal = 16.dp, vertical = 6.dp)

        // Reclaims the status bar's vertical space in landscape (the system clock/battery row),
        // rather than hiding our own top bar — the title and back button stay put, only the OS
        // chrome above them disappears. Swiping down from the top still reveals it temporarily.
        val view = LocalView.current
        DisposableEffect(isCompactHeight) {
            val window = (view.context as? Activity)?.window
            if (window != null) {
                val controller = WindowCompat.getInsetsController(window, view)
                controller.systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                if (isCompactHeight) {
                    controller.hide(WindowInsetsCompat.Type.statusBars())
                } else {
                    controller.show(WindowInsetsCompat.Type.statusBars())
                }
            }
            onDispose {
                val w = (view.context as? Activity)?.window
                if (w != null) {
                    WindowCompat.getInsetsController(w, view).show(WindowInsetsCompat.Type.statusBars())
                }
            }
        }

        val flowActions: @Composable () -> Unit = {
            topBarActions()
            IconButton(onClick = { autoAdvanceMenuExpanded = true }) {
                Icon(
                    Icons.Filled.Timer,
                    contentDescription = stringResource(R.string.settings_auto_advance),
                    tint = if (autoAdvanceSeconds > 0) MaterialTheme.colorScheme.primary else LocalContentColor.current,
                )
            }
            DropdownMenu(
                expanded = autoAdvanceMenuExpanded,
                onDismissRequest = { autoAdvanceMenuExpanded = false },
            ) {
                for (seconds in listOf(0, 3, 5, 10, 15)) {
                    val label = if (seconds == 0) stringResource(R.string.auto_advance_off) else stringResource(R.string.auto_advance_every, seconds)
                    DropdownMenuItem(
                        text = { Text(label) },
                        leadingIcon = if (autoAdvanceSeconds == seconds) {
                            { Icon(Icons.Filled.Check, contentDescription = null) }
                        } else {
                            null
                        },
                        onClick = {
                            autoAdvanceMenuExpanded = false
                            autoAdvanceSeconds = seconds
                            AppSettings.setAutoAdvanceSeconds(seconds)
                        },
                    )
                }
            }
        }

        Scaffold(
            topBar = {
                if (maxWidth < 600.dp) {
                    Column(modifier = Modifier.background(MaterialTheme.colorScheme.surface)) {
                        Row(
                            modifier = Modifier.fillMaxWidth()
                                .windowInsetsPadding(TopAppBarDefaults.windowInsets),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            IconButton(onClick = onNavigateUp) {
                                Icon(Icons.AutoMirrored.Filled.ArrowBack,
                                    contentDescription = stringResource(R.string.common_back))
                            }
                            Text(
                                visibleFlowTitle,
                                style = PrayerTypography.headingStyleForText(visibleFlowTitle, MaterialTheme.typography.titleLarge),
                                modifier = Modifier.weight(1f).padding(vertical = 12.dp)
                                    .padding(end = 16.dp).testTag("prayerFlowTitle"),
                            )
                        }
                        Row(
                            modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState())
                                .padding(horizontal = 12.dp).testTag("prayerFlowActions"),
                            horizontalArrangement = Arrangement.End,
                            verticalAlignment = Alignment.CenterVertically,
                        ) { flowActions() }
                    }
                } else {
                    TopAppBar(
                        title = { Text(visibleFlowTitle,
                            style = PrayerTypography.headingStyleForText(visibleFlowTitle, MaterialTheme.typography.titleLarge),
                            modifier = Modifier.testTag("prayerFlowTitle")) },
                        navigationIcon = {
                            IconButton(onClick = onNavigateUp) {
                                Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.common_back))
                            }
                        },
                        actions = { flowActions() },
                    )
                }
            },
        ) { paddingValues ->
            Column(modifier = Modifier.padding(paddingValues).fillMaxSize()) {
                Box(modifier = Modifier.fillMaxWidth().height(6.dp).background(seasonColor))

                ProgressHeader(step = step, currentIndex = currentIndex, totalSteps = totalSteps,
                    isCompactHeight = isCompactHeight, languageCode = languageCode, showsTransliteration = usesAlternateText,
                    aramaicSessionScript = aramaicSessionScript)

                if (step != null) {
                    BoxWithConstraints(modifier = Modifier.weight(1f).fillMaxWidth()) {
                        // Regular/wide window (tablet, a wide split, landscape) gets the taller
                        // three-column layout; a narrow portrait phone keeps the single scrolling column.
                        val compact = maxHeight < 480.dp
                        val imageWidth = if (compact) 190.dp else 320.dp
                        val gap = if (compact) 16.dp else 24.dp
                        val horizontalPadding = if (compact) 28.dp else 68.dp
                        val minimumWidth = imageWidth + wideAccessoryWidth + 280.dp + horizontalPadding +
                            gap * (if (wideAccessoryWidth > 0.dp) 2 else 1)
                        val isWide = maxWidth >= maxOf(if (compact) 640.dp else 840.dp, minimumWidth)
                        AdaptivePrayerContent(
                            step = step,
                            languageCode = languageCode,
                            prayerBundleId = prayerBundleId,
                            isRightToLeft = isRightToLeft,
                            isWide = isWide,
                            wideAccessoryWidth = wideAccessoryWidth,
                            availableHeight = maxHeight,
                            chrome = chrome,
                            accessory = accessory,
                            showsTransliteration = usesAlternateText,
                            onToggleTransliteration = toggleTransliteration,
                            centralActionLabel = centralActionLabel,
                            onCentralAction = onNext,
                            keyboardSessionActive = !sessionPaused && !autoAdvanceMenuExpanded,
                            interfaceDirection = interfaceDirection,
                            canGoBack = canGoBack,
                            onBack = onBack,
                            onNext = onNext,
                        )
                    }
                } else {
                    Box(modifier = Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                }

                if (audioBar != null) {
                    Box(modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp).padding(bottom = 6.dp)) {
                        audioBar()
                    }
                }

                HorizontalDivider()

                // A counter flow's only action is its central button: a lone Back beside it
                // competes with the thing the screen exists for, and "undo one repetition"
                // isn't worth a permanent control (the top bar still leaves the session).
                if (centralActionLabel == null) {
                    InterfaceNavigation {
                        Row(
                            modifier = Modifier.fillMaxWidth().padding(
                                horizontal = 24.dp,
                                vertical = if (isCompactHeight) 8.dp else 16.dp,
                            ),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            OutlinedButton(
                                onClick = onBack,
                                enabled = canGoBack,
                                contentPadding = if (isCompactHeight) compactButtonPadding else ButtonDefaults.ContentPadding,
                            ) {
                                Text(stringResource(R.string.flow_back))
                            }
                            Spacer(modifier = Modifier.weight(1f))
                            Button(
                                onClick = onNext,
                                contentPadding = if (isCompactHeight) compactButtonPadding else ButtonDefaults.ContentPadding,
                            ) {
                                Text(if (isLastStep) stringResource(R.string.common_finish) else stringResource(R.string.common_next))
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ProgressHeader(step: RosaryStep?, currentIndex: Int, totalSteps: Int?, isCompactHeight: Boolean,
                           languageCode: String?, showsTransliteration: Boolean, aramaicSessionScript: String?) {
    Column(
        verticalArrangement = Arrangement.spacedBy(4.dp),
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp)
            .padding(top = if (isCompactHeight) 6.dp else 12.dp),
    ) {
        when {
            step == null -> LinearProgressIndicator(progress = { 0f }, modifier = Modifier.fillMaxWidth())
            totalSteps != null && totalSteps > 0 -> {
                LinearProgressIndicator(progress = { (currentIndex + 1).toFloat() / totalSteps }, modifier = Modifier.fillMaxWidth())
                val visibleBody = if (showsTransliteration) step.transliteratedBody ?: step.body else step.body
                val aramaic = PrayerTranslations.aramaicProgress(currentIndex + 1, totalSteps, languageCode,
                    aramaicSessionScript?.let { it == "Syrc" }
                        ?: (PrayerTypography.scriptOf(visibleBody) == PrayerTypography.Script.Syriac))
                Text(
                    aramaic ?: stringResource(R.string.flow_step_of, currentIndex + 1, totalSteps),
                    style = MaterialTheme.typography.bodySmall.copy(fontFamily = aramaic?.let {
                        PrayerTypography.styleForText(it, isScripture = false).fontFamily
                    }),
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.testTag("prayerProgress"),
                )
            }
            else -> Text(
                "${currentIndex + 1}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.testTag("prayerProgress"),
            )
        }
    }
}

@Composable
private fun AdaptivePrayerContent(
    step: RosaryStep,
    languageCode: String?,
    prayerBundleId: String,
    isRightToLeft: Boolean,
    isWide: Boolean,
    availableHeight: Dp,
    wideAccessoryWidth: Dp,
    chrome: PrayerFlowChromeState,
    accessory: @Composable (isWide: Boolean, hasRoomForSingleMinorColumn: Boolean) -> Unit,
    showsTransliteration: Boolean,
    onToggleTransliteration: () -> Unit,
    centralActionLabel: String? = null,
    onCentralAction: (() -> Unit)? = null,
    keyboardSessionActive: Boolean,
    interfaceDirection: LayoutDirection,
    canGoBack: Boolean,
    onBack: () -> Unit,
    onNext: () -> Unit,
) {
    val readingState = chrome.reading
    val keyboardModifier = prayerKeyboardNavigationModifier(
        sessionActive = keyboardSessionActive,
        interfaceDirection = interfaceDirection,
        canGoBack = canGoBack,
        onBack = onBack,
        onNext = onNext,
    )
    val compact = availableHeight < 480.dp
    val imageSide = if (compact) 190.dp else 320.dp
    val visibleBody = if (showsTransliteration) step.transliteratedBody ?: step.body else step.body
    val paragraphs = remember(visibleBody) { prayerParagraphs(visibleBody.parseBoldMarkdown()) }
    val bodyStyle = PrayerTypography.styleForText(visibleBody, isScripture = step.isScripture)

    // The reading child and its keyed items never move to a different composition branch.
    // Only measurement changes when the window crosses the breakpoint, so LazyListState keeps
    // the same paragraph and its offset rather than a raw pixel position in a different column.
    Layout(
        modifier = Modifier.fillMaxSize().testTag(if (isWide) "prayerWideLayout" else "prayerNarrowLayout"),
        content = {
            Box {
                if (isWide) {
                    MysteryImage(step.imageKey, Modifier.fillMaxSize().clip(RoundedCornerShape(16.dp)))
                }
            }
            Box(contentAlignment = Alignment.TopCenter, modifier = Modifier.testTag("prayerAccessory")) {
                accessory(isWide, availableHeight >= 300.dp)
            }
            CompositionLocalProvider(LocalLayoutDirection provides if (isRightToLeft) LayoutDirection.Rtl else LayoutDirection.Ltr) {
                SelectionContainer {
                    LazyColumn(
                        state = readingState,
                        horizontalAlignment = Alignment.CenterHorizontally,
                        contentPadding = PaddingValues(16.dp),
                        modifier = Modifier.fillMaxSize().testTag("prayerBody")
                            .then(keyboardModifier)
                            .onSizeChanged { chrome.restoreReadingAnchor() }
                            .pointerInput(chrome) {
                                awaitEachGesture {
                                    awaitFirstDown(requireUnconsumed = false)
                                    chrome.releaseReadingAnchor()
                                }
                            },
                    ) {
                        item(key = "artwork") {
                            // Retain this item even in the wide layout so every later item keeps
                            // its identity. Only the decorative image changes its presentation.
                            if (!isWide) {
                                MysteryImage(
                                    step.imageKey,
                                    Modifier.fillMaxWidth(0.75f).aspectRatio(1f)
                                        .clip(RoundedCornerShape(16.dp)),
                                )
                                Spacer(Modifier.height(16.dp))
                            }
                        }
                        item(key = "heading") {
                            PrayerTextHeader(
                                step, languageCode, visibleBody, showsTransliteration,
                                onToggleTransliteration, prayerBundleId,
                            )
                            Spacer(Modifier.height(8.dp))
                        }
                        itemsIndexed(paragraphs, key = { index, _ -> "paragraph:$index" }) { index, paragraph ->
                            Text(
                                paragraph,
                                style = bodyStyle,
                                modifier = Modifier.fillMaxWidth().testTag("prayerParagraph:$index"),
                            )
                        }
                        item(key = "counter") {
                            if (centralActionLabel != null && onCentralAction != null) {
                                DisableSelection {
                                    Button(
                                        onClick = onCentralAction,
                                        shape = CircleShape,
                                        modifier = Modifier.padding(top = 12.dp).size(104.dp),
                                    ) {
                                        Text(
                                            centralActionLabel,
                                            style = MaterialTheme.typography.titleMedium,
                                            fontWeight = FontWeight.Bold,
                                            textAlign = TextAlign.Center,
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        },
    ) { measurables, constraints ->
        val width = constraints.maxWidth
        val height = constraints.maxHeight
        if (isWide) {
            val start = (if (compact) 16.dp else 40.dp).roundToPx()
            val end = (if (compact) 12.dp else 28.dp).roundToPx()
            val top = (if (compact) 8.dp else 16.dp).roundToPx()
            val gap = (if (compact) 16.dp else 24.dp).roundToPx()
            val contentHeight = (height - top).coerceAtLeast(0)
            val side = imageSide.roundToPx().coerceAtMost(contentHeight)
            val artwork = measurables[0].measure(Constraints.fixed(side, side))
            val beads = measurables[1].measure(Constraints(
                maxWidth = wideAccessoryWidth.roundToPx().coerceAtLeast(0), maxHeight = contentHeight,
            ))
            val textStart = start + side + gap + if (beads.width > 0) beads.width + gap else 0
            val reading = measurables[2].measure(Constraints.fixed(
                (width - textStart - end).coerceAtLeast(0), contentHeight,
            ))
            layout(width, height) {
                artwork.placeRelative(start, top + (contentHeight - artwork.height) / 2)
                beads.placeRelative(start + side + gap, top + (contentHeight - beads.height) / 2)
                reading.placeRelative(textStart, top)
            }
        } else {
            val artwork = measurables[0].measure(Constraints.fixed(0, 0))
            val beads = measurables[1].measure(Constraints(maxWidth = width, maxHeight = height))
            val top = if (beads.height > 0) 8.dp.roundToPx() else 0
            val readingTop = (top + beads.height).coerceAtMost(height)
            val reading = measurables[2].measure(Constraints.fixed(width, height - readingTop))
            layout(width, height) {
                artwork.placeRelative(0, 0)
                beads.placeRelative((width - beads.width) / 2, top)
                reading.placeRelative(0, readingTop)
            }
        }
    }
}

/** Split only at blank lines, after parsing bold spans. Keeping separators and annotated
 * subsequences preserves every character and emphasis run, including spans across paragraphs. */
internal fun prayerParagraphs(body: AnnotatedString): List<AnnotatedString> {
    val result = mutableListOf<AnnotatedString>()
    var start = 0
    Regex("\\r?\\n[ \\t]*\\r?\\n(?:[ \\t]*\\r?\\n)*").findAll(body.text).forEach { separator ->
        val end = separator.range.last + 1
        result += body.subSequence(start, end)
        start = end
    }
    if (start < body.length || result.isEmpty()) result += body.subSequence(start, body.length)
    return result
}

internal const val PRAYER_IMAGE_MAX_DIMENSION = 2_048

/** BitmapFactory samples by powers of two. Choose the smallest sample whose decoded width and
 * height are both bounded, using Long arithmetic so hostile image dimensions cannot overflow. */
internal fun prayerImageSampleSize(
    width: Int,
    height: Int,
    maxDimension: Int = PRAYER_IMAGE_MAX_DIMENSION,
): Int {
    if (width <= 0 || height <= 0 || maxDimension <= 0) return 1
    val longest = maxOf(width, height).toLong()
    var sampleSize = 1L
    while (longest > maxDimension.toLong() * sampleSize) sampleSize *= 2L
    return sampleSize.coerceAtMost(Int.MAX_VALUE.toLong()).toInt()
}

/** Reads dimensions without pixel allocation, then decodes at a bounded resolution. */
private fun decodePrayerImage(data: ByteArray): Bitmap? {
    val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    BitmapFactory.decodeByteArray(data, 0, data.size, options)
    if (options.outWidth <= 0 || options.outHeight <= 0) return null
    options.inSampleSize = prayerImageSampleSize(options.outWidth, options.outHeight)
    options.inJustDecodeBounds = false
    return BitmapFactory.decodeByteArray(data, 0, data.size, options)
}

/** A bounded cache for decoded prayer artwork. The source JPEGs stay lazy in their packs and a
 * small working set avoids decoding the same adjacent steps repeatedly. Images are sampled to a
 * 2048-pixel maximum dimension before pixel allocation, so an imported oversized JPEG cannot
 * transiently exhaust the heap before the LRU rejects it. Evicted bitmaps are not recycled
 * because Compose may still be drawing one during a cache transition. */
private object PrayerImageCache {
    private val maxSizeKiB = (
        minOf(16L * 1024L * 1024L, Runtime.getRuntime().maxMemory() / 16L) / 1024L
        ).coerceAtLeast(1024L).toInt()

    private val cache = object : LruCache<String, Bitmap>(maxSizeKiB) {
        override fun sizeOf(key: String, value: Bitmap): Int =
            ((value.allocationByteCount.toLong() + 1023L) / 1024L).coerceAtMost(Int.MAX_VALUE.toLong()).toInt()
    }

    fun cached(cacheKey: String): ImageBitmap? = cache.get(cacheKey)?.asImageBitmap()

    fun load(request: PrayerPackStore.ImageRequest): ImageBitmap? {
        cache.get(request.cacheKey)?.let { return it.asImageBitmap() }
        val data = request.read() ?: return null
        val bitmap = decodePrayerImage(data) ?: return null
        cache.put(request.cacheKey, bitmap)
        return bitmap.asImageBitmap()
    }
}

/** Decorative — the title/body text alongside it already conveys the same content. Prayer
 * artwork lives once, inside .prosaryprayer packs; missing/invalid custom artwork falls back to
 * the tiny generated cross resource. Loading and decoding run off the UI thread. */
@Composable
internal fun MysteryImage(imageKey: String, modifier: Modifier = Modifier) {
    val request = PrayerPackStore.imageRequest(imageKey)
    val cacheKey = request?.cacheKey
    val cachedBitmap = remember(cacheKey) { cacheKey?.let(PrayerImageCache::cached) }
    val packBitmap by produceState<ImageBitmap?>(initialValue = cachedBitmap, cacheKey) {
        // produceState retains its state object while a key restarts the producer, so explicitly
        // replace the previous source's bitmap before loading the new winner.
        value = cachedBitmap
        if (value == null && request != null) {
            value = withContext(Dispatchers.IO) {
                PrayerImageCache.load(request)
            }
        }
    }
    val bitmap = packBitmap
    if (bitmap != null) {
        androidx.compose.foundation.Image(
            bitmap = bitmap,
            contentDescription = null,
            contentScale = ContentScale.Crop,
            modifier = modifier,
        )
        return
    }
    androidx.compose.foundation.Image(
        painter = painterResource(id = R.drawable.cross_placeholder),
        contentDescription = null,
        contentScale = ContentScale.Crop,
        modifier = modifier,
    )
}

@Composable
private fun PrayerTextHeader(
    step: RosaryStep,
    languageCode: String?,
    visibleBody: String,
    showsTransliteration: Boolean,
    onToggleTransliteration: () -> Unit,
    prayerBundleId: String,
) {
    val visibleTitle = PrayerTranslations.flowTitle(step.title, languageCode,
        PrayerTypography.scriptOf(visibleBody) == PrayerTypography.Script.Syriac, prayerBundleId)
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp),
        modifier = Modifier.fillMaxWidth(),
    ) {
        DisableSelection {
            step.subtitle?.let { subtitle ->
                val visibleSubtitle = PrayerTranslations.flowTitle(subtitle, languageCode,
                    PrayerTypography.scriptOf(visibleBody) == PrayerTypography.Script.Syriac, prayerBundleId)
                Text(
                    visibleSubtitle,
                    style = PrayerTypography.headingStyleForText(visibleSubtitle, MaterialTheme.typography.bodyMedium),
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                )
            }
            Text(
                visibleTitle,
                style = PrayerTypography.headingStyleForText(visibleTitle, MaterialTheme.typography.titleLarge),
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.extraColors.headline,
                textAlign = TextAlign.Center,
                modifier = Modifier.testTag("prayerStepTitle"),
            )
        }
        step.acclamation?.let { acclamation ->
            Text(
                acclamation.parseBoldMarkdown(),
                style = PrayerTypography.styleForText(acclamation, isScripture = false),
            )
        }
        if (step.transliteratedBody != null) {
            DisableSelection {
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                    IconButton(onClick = onToggleTransliteration) {
                        Icon(
                            Icons.Filled.Translate,
                            contentDescription = stringResource(R.string.flow_show_transliteration),
                            tint = if (showsTransliteration) MaterialTheme.colorScheme.primary else LocalContentColor.current,
                        )
                    }
                }
            }
        }
    }
}
