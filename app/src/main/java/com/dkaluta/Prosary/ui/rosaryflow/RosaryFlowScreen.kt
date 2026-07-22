package com.dkaluta.Prosary.ui.rosaryflow

import android.app.Activity
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
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
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.core.view.WindowInsetsCompat
import com.dkaluta.Prosary.R
import com.dkaluta.Prosary.models.LanguageCatalog
import com.dkaluta.Prosary.models.RosaryConfig
import com.dkaluta.Prosary.models.RosaryStep
import com.dkaluta.Prosary.services.LocalAppServices
import com.dkaluta.Prosary.typography.PrayerTypography
import com.dkaluta.Prosary.ui.theme.extraColors

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RosaryFlowScreen(configId: String, onBack: () -> Unit) {
    val services = LocalAppServices.current

    var config by remember { mutableStateOf<RosaryConfig?>(null) }
    var steps by remember { mutableStateOf<List<RosaryStep>>(emptyList()) }
    var currentIndex by remember { mutableIntStateOf(0) }
    var seasonColor by remember { mutableStateOf(Color.Transparent) }

    LaunchedEffect(configId) {
        val resolvedConfig = runCatching { services.presetStore.get(configId) }.getOrNull()
            ?: runCatching { services.presetStore.defaultPreset() }.getOrNull()
        if (resolvedConfig != null) {
            config = resolvedConfig
            steps = services.rosaryEngine.buildSteps(resolvedConfig)
            currentIndex = 0
            seasonColor = services.calendar.seasonColorToday()
        }
    }

    val currentStep = steps.getOrNull(currentIndex)
    val progress = if (steps.isEmpty()) 0f else (currentIndex + 1).toFloat() / steps.size
    val isLastStep = steps.isEmpty() || currentIndex == steps.size - 1
    val isRightToLeft = LanguageCatalog.resolve(config?.languageCode).isRightToLeft
    val beadLayout = remember(steps, currentIndex, config?.includeFinalSignOfCross) {
        BeadLayout.build(steps, currentIndex, config?.includeFinalSignOfCross ?: false)
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
                    title = { Text("Praying the Rosary") },
                    navigationIcon = {
                        IconButton(onClick = onBack) {
                            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                        }
                    },
                )
            },
        ) { paddingValues ->
            Column(modifier = Modifier.padding(paddingValues).fillMaxSize()) {
                Box(modifier = Modifier.fillMaxWidth().height(6.dp).background(seasonColor))

                Column(
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp)
                        .padding(top = if (isCompactHeight) 6.dp else 12.dp),
                ) {
                    LinearProgressIndicator(progress = { progress }, modifier = Modifier.fillMaxWidth())
                    if (steps.isNotEmpty()) {
                        Text(
                            "${currentIndex + 1} of ${steps.size}",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }

                if (currentStep != null) {
                    BoxWithConstraints(modifier = Modifier.weight(1f).fillMaxWidth()) {
                        // Regular/wide window (tablet, a wide split, landscape) gets the taller
                        // three-column layout; a narrow portrait phone keeps the single scrolling column.
                        val isWide = maxWidth >= 600.dp || maxHeight < 480.dp
                        if (isWide) {
                            WideContent(
                                step = currentStep,
                                languageCode = config?.languageCode,
                                beadLayout = beadLayout,
                                isRightToLeft = isRightToLeft,
                                availableHeight = maxHeight,
                            )
                        } else {
                            NarrowContent(
                                step = currentStep,
                                languageCode = config?.languageCode,
                                beadLayout = beadLayout,
                                isRightToLeft = isRightToLeft,
                            )
                        }
                    }
                } else {
                    Box(modifier = Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
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
                        onClick = { if (currentIndex > 0) currentIndex-- },
                        enabled = currentIndex > 0,
                        contentPadding = if (isCompactHeight) compactButtonPadding else ButtonDefaults.ContentPadding,
                    ) {
                        Text("Back")
                    }
                    Spacer(modifier = Modifier.weight(1f))
                    Button(
                        onClick = { if (isLastStep) onBack() else currentIndex++ },
                        contentPadding = if (isCompactHeight) compactButtonPadding else ButtonDefaults.ContentPadding,
                    ) {
                        Text(if (isLastStep) "Finish" else "Next")
                    }
                }
            }
        }
    }
}

@Composable
private fun NarrowContent(step: RosaryStep, languageCode: String?, beadLayout: BeadLayout, isRightToLeft: Boolean) {
    Column(modifier = Modifier.fillMaxSize()) {
        BeadProgressView(layout = beadLayout, isWide = false, modifier = Modifier.padding(top = 8.dp).fillMaxWidth())

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
                TextBlock(step = step, languageCode = languageCode)
            }
        }
    }
}

@Composable
private fun WideContent(
    step: RosaryStep,
    languageCode: String?,
    beadLayout: BeadLayout,
    isRightToLeft: Boolean,
    availableHeight: androidx.compose.ui.unit.Dp,
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

        BeadProgressView(
            layout = beadLayout,
            isWide = true,
            hasRoomForSingleMinorColumn = hasRoomForSingleMinorColumn,
        )

        CompositionLocalProvider(LocalLayoutDirection provides if (isRightToLeft) LayoutDirection.Rtl else LayoutDirection.Ltr) {
            Column(modifier = Modifier.weight(1f).fillMaxHeight().verticalScroll(rememberScrollState())) {
                TextBlock(step = step, languageCode = languageCode, modifier = Modifier.padding(16.dp))
            }
        }
    }
}

/** Decorative — the title/body text alongside it already conveys the same content. */
@Composable
private fun MysteryImage(imageKey: String, modifier: Modifier = Modifier) {
    val context = LocalContext.current
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
private fun TextBlock(step: RosaryStep, languageCode: String?, modifier: Modifier = Modifier) {
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

        Text(
            step.body,
            style = PrayerTypography.style(languageCode = languageCode, isScripture = step.isScripture),
        )
    }
}
