package com.dkaluta.prosary.ui.shared

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material.icons.filled.Check
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
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.Color
import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import com.dkaluta.prosary.models.LanguageCatalog
import com.dkaluta.prosary.models.Prayer
import com.dkaluta.prosary.models.PrayerKind
import com.dkaluta.prosary.models.RosaryStep
import com.dkaluta.prosary.services.AppServices
import com.dkaluta.prosary.services.LocalAppServices
import com.dkaluta.prosary.ui.rosaryflow.BeadLayout
import com.dkaluta.prosary.ui.rosaryflow.BeadProgressView
import kotlinx.coroutines.launch

/** The single flow screen for every [PrayerKind.Custom] devotion — mirrors the hardcoded flow
 * screens' shape exactly, but reads its title/steps from [PrayerPackStore]/
 * [com.dkaluta.prosary.engine.PrayerEngine] instead of a per-devotion hardcoded builder, so a
 * new generic devotion needs no new screen at all. A decade/bead-structured ("rosary" type)
 * devotion gets the same bead track as the Rosary; flat devotions (no step carries a
 * decadeIndex) get none.
 *
 * [prayer] is set when launched from an existing favorite (via PrayerDispatchScreen) — seeds the
 * star as already-favorited immediately, without waiting on the initial favorites fetch. A
 * generic devotion has no per-favorite language — it always follows the app default. */
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

    LaunchedEffect(prayer, devotionId, variantId) {
        displayName = PrayerPackStore.info(devotionId)?.localizedDisplayName ?: devotionId
        val resolvedLanguageCode = LanguageCatalog.resolve(LanguageCatalog.defaultSentinel).code
        languageCode = resolvedLanguageCode
        isRightToLeft = LanguageCatalog.resolve(resolvedLanguageCode).isRightToLeft
        steps = services.engine.buildSteps(
            Prayer(
                kind = PrayerKind.Custom, languageCode = resolvedLanguageCode,
                customDevotionId = devotionId, variantId = variantId,
            ),
        )
        currentIndex = 0
        seasonColor = services.calendar.seasonColorToday()

        if (matchingFavoriteId == null) {
            val all = runCatching { services.presetStore.all() }.getOrDefault(emptyList())
            val favorite = all.firstOrNull { it.kind == PrayerKind.Custom && it.customDevotionId == devotionId }
            matchingFavoriteId = favorite?.id
            if (favorite?.variantId != variantId && variantId == null) {
                variantId = favorite?.variantId
            }
        }
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
        onBack = { if (currentIndex > 0) currentIndex-- },
        onNext = {
            if (steps.isEmpty() || currentIndex == steps.size - 1) onBack() else currentIndex++
        },
        onNavigateUp = onBack,
        accessory = if (showsBeadTrack) {
            { isWide, hasRoomForSingleMinorColumn ->
                BeadProgressView(layout = beadLayout, isWide = isWide, hasRoomForSingleMinorColumn = hasRoomForSingleMinorColumn)
            }
        } else {
            { _, _ -> }
        },
        topBarActions = {
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
