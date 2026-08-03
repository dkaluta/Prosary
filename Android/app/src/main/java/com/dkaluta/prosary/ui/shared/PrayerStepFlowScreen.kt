package com.dkaluta.prosary.ui.shared

import android.app.Activity
import android.graphics.BitmapFactory
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
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
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
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
import com.dkaluta.prosary.typography.PrayerTypography
import com.dkaluta.prosary.ui.theme.extraColors
import kotlinx.coroutines.delay

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
) {
    // Matches the pre-load "no step yet" instant to "last step" so the footer doesn't flash a
    // "Next" label a moment before content briefly reads "Finish" (imperceptible in practice,
    // since loading is a near-instant in-memory lookup).
    val isLastStep = step == null || (totalSteps != null && currentIndex >= totalSteps - 1)

    // Seconds between automatic advances (hands-free praying); 0 = off. One app-wide setting
    // shared by every flow, so a choice made in the Rosary carries into the Stations.
    var autoAdvanceSeconds by remember { mutableIntStateOf(AppSettings.autoAdvanceSeconds) }
    var autoAdvanceMenuExpanded by remember { mutableStateOf(false) }

    // Restarts whenever the step, the interval, or the loaded state changes — so tapping
    // Back/Next resets the countdown, and turning the setting off cancels it. Never fires on
    // the last step: auto-"Finish" would dismiss the whole flow mid-prayer. Suspended outright
    // while a recording plays (audioIsPlaying is a key, so pausing re-arms it).
    LaunchedEffect(autoAdvanceSeconds, currentIndex, step != null, audioIsPlaying) {
        if (autoAdvanceSeconds > 0 && step != null && !isLastStep && !audioIsPlaying) {
            delay(autoAdvanceSeconds * 1000L)
            onNext()
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

        Scaffold(
            topBar = {
                TopAppBar(
                    title = { Text(title) },
                    navigationIcon = {
                        IconButton(onClick = onNavigateUp) {
                            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.common_back))
                        }
                    },
                    actions = {
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
                            for (seconds in listOf(0, 3, 5, 10)) {
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
                    },
                )
            },
        ) { paddingValues ->
            Column(modifier = Modifier.padding(paddingValues).fillMaxSize()) {
                Box(modifier = Modifier.fillMaxWidth().height(6.dp).background(seasonColor))

                ProgressHeader(step = step, currentIndex = currentIndex, totalSteps = totalSteps, isCompactHeight = isCompactHeight)

                if (step != null) {
                    BoxWithConstraints(modifier = Modifier.weight(1f).fillMaxWidth()) {
                        // Regular/wide window (tablet, a wide split, landscape) gets the taller
                        // three-column layout; a narrow portrait phone keeps the single scrolling column.
                        val isWide = maxWidth >= 600.dp || maxHeight < 480.dp
                        if (isWide) {
                            WideContent(
                                step = step,
                                languageCode = languageCode,
                                isRightToLeft = isRightToLeft,
                                availableHeight = maxHeight,
                                accessory = accessory,
                                centralActionLabel = centralActionLabel,
                                onCentralAction = onNext,
                            )
                        } else {
                            NarrowContent(
                                step = step,
                                languageCode = languageCode,
                                isRightToLeft = isRightToLeft,
                                accessory = accessory,
                                centralActionLabel = centralActionLabel,
                                onCentralAction = onNext,
                            )
                        }
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
                        Text(stringResource(R.string.common_back))
                    }
                    Spacer(modifier = Modifier.weight(1f))
                    if (centralActionLabel == null) {
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

@Composable
private fun ProgressHeader(step: RosaryStep?, currentIndex: Int, totalSteps: Int?, isCompactHeight: Boolean) {
    Column(
        verticalArrangement = Arrangement.spacedBy(4.dp),
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp)
            .padding(top = if (isCompactHeight) 6.dp else 12.dp),
    ) {
        when {
            step == null -> LinearProgressIndicator(progress = { 0f }, modifier = Modifier.fillMaxWidth())
            totalSteps != null && totalSteps > 0 -> {
                LinearProgressIndicator(progress = { (currentIndex + 1).toFloat() / totalSteps }, modifier = Modifier.fillMaxWidth())
                Text(
                    stringResource(R.string.flow_step_of, currentIndex + 1, totalSteps),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            else -> Text(
                "${currentIndex + 1}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun NarrowContent(
    step: RosaryStep,
    languageCode: String?,
    isRightToLeft: Boolean,
    accessory: @Composable (isWide: Boolean, hasRoomForSingleMinorColumn: Boolean) -> Unit,
    centralActionLabel: String? = null,
    onCentralAction: (() -> Unit)? = null,
) {
    Column(modifier = Modifier.fillMaxSize()) {
        // The extra top padding + full-width modifier live here (applied to whatever the
        // accessory renders) rather than on each call site, so a devotion with no accessory at
        // all (Angelus, Jesus Prayer) doesn't need to think about this either — an empty
        // composable inside just takes no space.
        Box(modifier = Modifier.padding(top = 8.dp).fillMaxWidth(), contentAlignment = Alignment.TopCenter) {
            accessory(false, true)
        }

        CompositionLocalProvider(LocalLayoutDirection provides if (isRightToLeft) LayoutDirection.Rtl else LayoutDirection.Ltr) {
            Column(
                verticalArrangement = Arrangement.spacedBy(16.dp),
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(16.dp),
            ) {
                MysteryImage(
                    imageKey = step.imageKey,
                    modifier = Modifier
                        .fillMaxWidth(0.75f)
                        .aspectRatio(1f)
                        .align(Alignment.CenterHorizontally)
                        .clip(RoundedCornerShape(16.dp)),
                )
                TextBlock(
                    step = step, languageCode = languageCode,
                    centralActionLabel = centralActionLabel, onCentralAction = onCentralAction,
                )
            }
        }
    }
}

@Composable
private fun WideContent(
    step: RosaryStep,
    languageCode: String?,
    isRightToLeft: Boolean,
    availableHeight: Dp,
    accessory: @Composable (isWide: Boolean, hasRoomForSingleMinorColumn: Boolean) -> Unit,
    centralActionLabel: String? = null,
    onCentralAction: (() -> Unit)? = null,
) {
    val isCompactHeight = availableHeight < 480.dp
    val imageSide = if (isCompactHeight) 190.dp else 320.dp
    val hasRoomForSingleMinorColumn = availableHeight >= 300.dp

    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(if (isCompactHeight) 16.dp else 24.dp),
        modifier = Modifier
            .fillMaxSize()
            .padding(start = if (isCompactHeight) 16.dp else 40.dp, end = if (isCompactHeight) 12.dp else 28.dp)
            .padding(top = if (isCompactHeight) 8.dp else 16.dp),
    ) {
        MysteryImage(
            imageKey = step.imageKey,
            modifier = Modifier.size(imageSide).clip(RoundedCornerShape(16.dp)),
        )

        accessory(true, hasRoomForSingleMinorColumn)

        CompositionLocalProvider(LocalLayoutDirection provides if (isRightToLeft) LayoutDirection.Rtl else LayoutDirection.Ltr) {
            Column(modifier = Modifier.weight(1f).fillMaxHeight().verticalScroll(rememberScrollState())) {
                TextBlock(
                    step = step, languageCode = languageCode, modifier = Modifier.padding(16.dp),
                    centralActionLabel = centralActionLabel, onCentralAction = onCentralAction,
                )
            }
        }
    }
}

/** Decorative — the title/body text alongside it already conveys the same content. Prefers a
 * loaded .prosaryprayer pack's own image data over the drawable resources, so a devotion with a
 * shipped pack (currently Rosary/Angelus) renders that pack's artwork; devotions without one fall
 * through to drawable resources exactly as before this existed. */
@Composable
private fun MysteryImage(imageKey: String, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val packBitmap = remember(imageKey) {
        PrayerPackStore.imageData(imageKey)?.let { data ->
            BitmapFactory.decodeByteArray(data, 0, data.size)?.asImageBitmap()
        }
    }
    if (packBitmap != null) {
        androidx.compose.foundation.Image(
            bitmap = packBitmap,
            contentDescription = null,
            contentScale = ContentScale.Crop,
            modifier = modifier,
        )
        return
    }
    val resId = remember(imageKey) {
        context.resources.getIdentifier(imageKey, "drawable", context.packageName)
            .takeIf { it != 0 } ?: R.drawable.cross_placeholder
    }
    androidx.compose.foundation.Image(
        painter = painterResource(id = resId),
        contentDescription = null,
        contentScale = ContentScale.Crop,
        modifier = modifier,
    )
}

@Composable
private fun TextBlock(
    step: RosaryStep,
    languageCode: String?,
    modifier: Modifier = Modifier,
    centralActionLabel: String? = null,
    onCentralAction: (() -> Unit)? = null,
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp),
        modifier = modifier.fillMaxWidth(),
    ) {
        step.subtitle?.let { subtitle ->
            Text(
                subtitle,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )
        }

        Text(
            step.title,
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.extraColors.headline,
            textAlign = TextAlign.Center,
        )

        step.acclamation?.let { acclamation ->
            // The versicle/response is a prayer, not part of the reading — it keeps the
            // regular prayer typeface even when the body below is scripture.
            Text(
                acclamation.parseBoldMarkdown(),
                style = PrayerTypography.style(languageCode = languageCode, isScripture = false),
            )
        }

        if (step.transliteratedBody != null) {
            // The v0.7 reading aid: swap the body for its transliteration. Sticky across
            // steps — someone praying along in an unfamiliar script wants it on all session.
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                IconButton(onClick = { TransliterationState.shows = !TransliterationState.shows }) {
                    Icon(
                        Icons.Filled.Translate,
                        contentDescription = stringResource(R.string.flow_show_transliteration),
                        tint = if (TransliterationState.shows) MaterialTheme.colorScheme.primary else LocalContentColor.current,
                    )
                }
            }
            Text(
                (if (TransliterationState.shows) step.transliteratedBody!! else step.body).parseBoldMarkdown(),
                style = PrayerTypography.style(languageCode = languageCode, isScripture = step.isScripture),
            )
        } else {
            Text(
                step.body.parseBoldMarkdown(),
                style = PrayerTypography.style(languageCode = languageCode, isScripture = step.isScripture),
            )
        }

        if (centralActionLabel != null && onCentralAction != null) {
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


/** Session-sticky transliteration toggle (v0.7): object state so it survives step
 * recompositions without threading a parameter through every flow caller. */
private object TransliterationState {
    var shows by androidx.compose.runtime.mutableStateOf(false)
}
