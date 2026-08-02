package com.dkaluta.prosary.ui.shared

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.Language
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.StarBorder
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Text
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
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import com.dkaluta.prosary.content.audio.AudioPlaybackController
import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import com.dkaluta.prosary.models.LanguageCatalog
import com.dkaluta.prosary.models.Prayer
import com.dkaluta.prosary.models.PrayerKind
import com.dkaluta.prosary.models.RosaryStep
import com.dkaluta.prosary.services.AppServices
import com.dkaluta.prosary.services.LocalAppServices
import com.dkaluta.prosary.ui.rosaryflow.BeadLayout
import com.dkaluta.prosary.ui.rosaryflow.BeadProgressView
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

/** The single flow screen for every [PrayerKind.Custom] devotion — mirrors the hardcoded flow
 * screens' shape exactly, but reads its title/steps from [PrayerPackStore]/
 * [com.dkaluta.prosary.engine.PrayerEngine] instead of a per-devotion hardcoded builder, so a
 * new generic devotion needs no new screen at all. A decade/bead-structured ("rosary" type)
 * devotion gets the same bead track as the Rosary; flat devotions (no step carries a
 * decadeIndex) get none.
 *
 * [prayer] is set when launched from an existing favorite (via PrayerDispatchScreen) — seeds the
 * star as already-favorited immediately, without waiting on the initial favorites fetch. The
 * session language follows the favorite's languageCode (sentinel = the app default), switchable
 * in place from the toolbar's language menu — testers assumed generic devotions shipped fewer
 * languages than they do when the only switch was the app-level setting. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CustomDevotionFlowScreen(devotionId: String, prayer: Prayer? = null, onBack: () -> Unit) {
    val services = LocalAppServices.current
    val scope = rememberCoroutineScope()

    var steps by remember { mutableStateOf<List<RosaryStep>>(emptyList()) }
    var currentIndex by remember { mutableIntStateOf(0) }
    var isRightToLeft by remember { mutableStateOf(false) }
    var seasonColor by remember { mutableStateOf(Color.Transparent) }
    var languageCode by remember { mutableStateOf<String?>(null) }
    var matchingFavoriteId by remember { mutableStateOf(prayer?.id) }
    var displayName by remember { mutableStateOf(devotionId) }
    var variantId by remember { mutableStateOf(prayer?.variantId) }
    var variantMenuExpanded by remember { mutableStateOf(false) }
    /** The favorite's raw language choice: an explicit code, or the sentinel ("follow the
     * app-level default setting"). [languageCode] is always the resolved code. */
    var chosenLanguage by remember { mutableStateOf(prayer?.languageCode ?: LanguageCatalog.defaultSentinel) }
    var languageMenuExpanded by remember { mutableStateOf(false) }
    /** Multi-day devotions: the day this session prays (0-based; sourced from the favorite). */
    var dayIndex by remember { mutableIntStateOf(prayer?.dayIndex ?: 0) }
    var dayMenuExpanded by remember { mutableStateOf(false) }

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
    fun pickAudioTrack(currentStepIndex: Int) {
        val defaultVariantId = PrayerPackStore.definition(devotionId)?.variants?.firstOrNull()?.id
        val effectiveVariant = variantId ?: defaultVariantId
        val match = PrayerPackStore.audioTracks(devotionId).firstOrNull {
            it.language == languageCode && (it.variantId ?: defaultVariantId) == effectiveVariant
        }
        if (match != null) {
            if (audio.track?.id != match.id || !audio.isLoaded) {
                audio.load(context, devotionId, match)
                if (audio.didRestorePosition) {
                    // Resumed mid-recording: pull the page to the restored chapter instead of
                    // yanking the recording back to the step-0 chapter.
                    val hint = audio.currentChapterIndex
                        ?.let { audio.track?.chapters?.getOrNull(it)?.stepIndex }
                    if (hint != null && hint in steps.indices) currentIndex = hint
                } else {
                    alignAudioToStep(currentStepIndex)
                }
            }
        } else {
            audio.stop()
        }
    }

    LaunchedEffect(prayer, devotionId, variantId, dayIndex) {
        displayName = PrayerPackStore.info(devotionId)?.localizedDisplayName ?: devotionId

        // The favorite (when one exists) carries the language and variant to pray in, so it
        // loads before the first build rather than after it.
        if (matchingFavoriteId == null && prayer == null) {
            val all = runCatching { services.presetStore.all() }.getOrDefault(emptyList())
            val favorite = all.firstOrNull { it.kind == PrayerKind.Custom && it.customDevotionId == devotionId }
            matchingFavoriteId = favorite?.id
            if (favorite != null) {
                chosenLanguage = favorite.languageCode
                if (variantId == null && favorite.variantId != null) {
                    variantId = favorite.variantId
                }
                dayIndex = favorite.dayIndex ?: 0
            }
        }

        val resolved = LanguageCatalog.resolve(chosenLanguage)
        languageCode = resolved.code
        isRightToLeft = resolved.isRightToLeft
        steps = services.engine.buildSteps(
            Prayer(
                kind = PrayerKind.Custom, languageCode = chosenLanguage,
                customDevotionId = devotionId, variantId = variantId, dayIndex = dayIndex,
            ),
        )
        currentIndex = 0
        seasonColor = services.calendar.seasonColorToday()
        pickAudioTrack(0)
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
    val hasClosingCross = PrayerPackStore.definition(devotionId)?.hasClosingCross ?: false
    val beadLayout = remember(steps, currentIndex) {
        BeadLayout.build(steps, currentIndex, hasClosingCross = hasClosingCross)
    }

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
                // Finishing a multi-day session advances the favorite to the next day (staying
                // on the last once complete) — tomorrow opens where the novena left off.
                val days = PrayerPackStore.definition(devotionId)?.days.orEmpty()
                if (days.size > 1) persistDayIndex(minOf(dayIndex + 1, days.size - 1))
                onBack()
            } else {
                currentIndex++
                alignAudioToStep(currentIndex)
            }
        },
        onNavigateUp = onBack,
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
            // change a generic devotion's language, and testers didn't find it. Mirrors the
            // variant menu: rebuilds the session in place (keeping the position — the step
            // sequence is identical across languages) and persists to the matching favorite.
            val bundleLanguages = PrayerPackStore.info(devotionId)?.languages.orEmpty()
            if (bundleLanguages.size > 1) {
                IconButton(onClick = { languageMenuExpanded = true }) {
                    Icon(Icons.Filled.Language, contentDescription = "Prayer language")
                }
                DropdownMenu(expanded = languageMenuExpanded, onDismissRequest = { languageMenuExpanded = false }) {
                    val choices = listOf(LanguageCatalog.defaultSentinel to "App setting") +
                        bundleLanguages.mapNotNull { code ->
                            LanguageCatalog.all.firstOrNull { it.code == code }?.let { it.code to it.nativeName }
                        }
                    for ((raw, name) in choices) {
                        DropdownMenuItem(
                            text = { Text(name) },
                            leadingIcon = if (chosenLanguage == raw) {
                                { Icon(Icons.Filled.Check, contentDescription = null) }
                            } else {
                                null
                            },
                            onClick = {
                                languageMenuExpanded = false
                                chosenLanguage = raw
                                val resolved = LanguageCatalog.resolve(raw)
                                languageCode = resolved.code
                                isRightToLeft = resolved.isRightToLeft
                                val position = currentIndex
                                steps = services.engine.buildSteps(
                                    Prayer(
                                        kind = PrayerKind.Custom, languageCode = raw,
                                        customDevotionId = devotionId, variantId = variantId,
                                        dayIndex = dayIndex,
                                    ),
                                )
                                currentIndex = position.coerceIn(0, (steps.size - 1).coerceAtLeast(0))
                                pickAudioTrack(currentIndex)
                                matchingFavoriteId?.let { id ->
                                    scope.launch {
                                        services.presetStore.get(id)?.let { favorite ->
                                            services.presetStore.save(favorite.copy(languageCode = raw))
                                        }
                                    }
                                }
                            },
                        )
                    }
                }
            }
            // Day picker — multi-day ("days"-type) devotions only: jump to any day; finishing
            // a session advances the favorite to the next one automatically.
            val days = PrayerPackStore.definition(devotionId)?.days.orEmpty()
            if (days.size > 1) {
                IconButton(onClick = { dayMenuExpanded = true }) {
                    Icon(Icons.Filled.DateRange, contentDescription = "Day")
                }
                DropdownMenu(expanded = dayMenuExpanded, onDismissRequest = { dayMenuExpanded = false }) {
                    days.forEachIndexed { index, day ->
                        val label = day.period?.let { "$it — ${day.localizedName}" } ?: day.localizedName
                        DropdownMenuItem(
                            text = { Text(label) },
                            leadingIcon = if (index == dayIndex) {
                                { Icon(Icons.Filled.Check, contentDescription = null) }
                            } else {
                                null
                            },
                            onClick = {
                                dayMenuExpanded = false
                                dayIndex = index
                                persistDayIndex(index)
                            },
                        )
                    }
                }
            }
            // Variant switcher — only for bundles declaring alternate step-sets (e.g. the
            // Stations' traditional vs. scriptural forms). Switching rebuilds the session from
            // step 0 (via the LaunchedEffect keyed on variantId) and persists the choice to the
            // matching favorite when one exists.
            val variants = PrayerPackStore.definition(devotionId)?.variants
            if (variants != null && variants.size > 1) {
                IconButton(onClick = { variantMenuExpanded = true }) {
                    Icon(Icons.AutoMirrored.Filled.MenuBook, contentDescription = "Choose form")
                }
                DropdownMenu(expanded = variantMenuExpanded, onDismissRequest = { variantMenuExpanded = false }) {
                    for (variant in variants) {
                        val isCurrent = variant.id == (variantId ?: variants.first().id)
                        DropdownMenuItem(
                            text = { Text(variant.localizedName) },
                            leadingIcon = if (isCurrent) {
                                { Icon(Icons.Filled.Check, contentDescription = null) }
                            } else {
                                null
                            },
                            onClick = {
                                variantMenuExpanded = false
                                val newVariantId = if (variant.id == variants.first().id) null else variant.id
                                variantId = newVariantId
                                matchingFavoriteId?.let { id ->
                                    scope.launch {
                                        services.presetStore.get(id)?.let { favorite ->
                                            services.presetStore.save(favorite.copy(variantId = newVariantId))
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
                    matchingFavoriteId = toggleCustomDevotionFavorite(services, devotionId, displayName, matchingFavoriteId)
                }
            }) {
                Icon(
                    if (matchingFavoriteId != null) Icons.Filled.Star else Icons.Filled.StarBorder,
                    contentDescription = if (matchingFavoriteId != null) "Remove from Favorites" else "Add to Favorites",
                )
            }
        },
    )
}

private suspend fun toggleCustomDevotionFavorite(
    services: AppServices,
    devotionId: String,
    displayName: String,
    currentFavoriteId: String?,
): String? {
    if (currentFavoriteId != null) {
        services.presetStore.get(currentFavoriteId)?.let { services.presetStore.delete(it) }
        return null
    }

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
