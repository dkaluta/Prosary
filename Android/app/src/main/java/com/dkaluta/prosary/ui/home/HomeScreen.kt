package com.dkaluta.prosary.ui.home

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Circle
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.dkaluta.prosary.content.prayerpack.CustomDevotionInfo
import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import com.dkaluta.prosary.models.MysteryGroup
import com.dkaluta.prosary.models.Prayer
import com.dkaluta.prosary.models.PrayerKind
import com.dkaluta.prosary.services.LocalAppServices
import com.dkaluta.prosary.ui.shared.PrayerCard
import com.dkaluta.prosary.ui.shared.colorForHex
import com.dkaluta.prosary.ui.shared.iconForSystemName
import com.dkaluta.prosary.ui.theme.extraColors

/** One devotion's rendering state for a Home card. See [HomeScreen]'s card list. */
private data class DevotionCard(
    val id: String,
    val icon: ImageVector,
    val title: String,
    val accentColor: Color,
    val subtitle: String,
    val testTag: String,
    val onClick: () -> Unit,
)

@Composable
fun HomeScreen(
    onOpenPrayer: (String) -> Unit,
    onOpenFavorites: () -> Unit,
    onOpenAbout: () -> Unit,
    onOpenSettings: () -> Unit,
    onOpenJesusPrayerSetup: () -> Unit,
    onOpenCustomDevotion: (String) -> Unit,
) {
    val services = LocalAppServices.current
    val isDarkTheme = isSystemInDarkTheme()

    var todayMysteryGroup by remember { mutableStateOf<MysteryGroup?>(null) }
    var defaultRosary by remember { mutableStateOf<Prayer?>(null) }
    var defaultJesusPrayer by remember { mutableStateOf<Prayer?>(null) }
    // One entry per discovered generic devotion (bundle id -> its favorite, if any).
    var defaultCustomDevotions by remember { mutableStateOf<Map<String, Prayer>>(emptyMap()) }

    LaunchedEffect(Unit) {
        todayMysteryGroup = services.calendar.mysteryGroupToday()
        val all = runCatching { services.presetStore.all() }.getOrDefault(emptyList())
        defaultRosary = all.firstOrNull { it.kind == PrayerKind.Rosary && it.isDefault }
            ?: all.firstOrNull { it.kind == PrayerKind.Rosary }
        defaultJesusPrayer = all.firstOrNull { it.kind == PrayerKind.JesusPrayer && it.isDefault }
            ?: all.firstOrNull { it.kind == PrayerKind.JesusPrayer }

        defaultCustomDevotions = PrayerPackStore.customDevotionIds().mapNotNull { bundleId ->
            val favorite = all.firstOrNull { it.kind == PrayerKind.Custom && it.customDevotionId == bundleId && it.isDefault }
                ?: all.firstOrNull { it.kind == PrayerKind.Custom && it.customDevotionId == bundleId }
            favorite?.let { bundleId to it }
        }.toMap()
    }

    val rosaryAccent = todayMysteryGroup?.color ?: MaterialTheme.colorScheme.primary
    val jesusPrayerAccent = if (isDarkTheme) Color(0xFFC62828) else Color(0xFF8B1A1A)

    val rosarySubtitle = buildString {
        todayMysteryGroup?.let { append("Today: ${it.displayName}") }
        defaultRosary?.let {
            if (isNotEmpty()) append(" • ")
            append(it.name)
        }
    }
    val jesusPrayerSubtitle = defaultJesusPrayer?.let { "${it.name} • ${it.jesusPrayer.targetDisplayName}" } ?: "Tap to set up"

    // Accent color for a generic devotion's card, honoring the manifest's light/dark pair.
    val fallbackAccent = MaterialTheme.colorScheme.primary
    fun customAccent(info: CustomDevotionInfo): Color {
        val hex = if (isDarkTheme) info.accentColorDarkHex ?: info.accentColorHex else info.accentColorHex
        return colorForHex(hex) ?: fallbackAccent
    }

    // One card per devotion: the Rosary first (the app's namesake), then every generic
    // (bundle-driven) devotion in pack-load order — icon/title/accent read from each bundle's
    // own manifest, nothing hardcoded here — and the Jesus Prayer (the counter-based odd one
    // out) last. Adding a devotion means shipping a bundle; this screen doesn't change.
    val devotionCards = buildList {
        add(
            DevotionCard(
                id = PrayerKind.Rosary.name,
                icon = Icons.Filled.Circle,
                title = PrayerKind.Rosary.displayName,
                accentColor = rosaryAccent,
                subtitle = rosarySubtitle,
                testTag = "rosaryCard",
                onClick = {
                    val prayer = defaultRosary
                    if (prayer != null) onOpenPrayer(prayer.id) else onOpenFavorites()
                },
            ),
        )

        for (bundleId in PrayerPackStore.customDevotionIds()) {
            val info = PrayerPackStore.info(bundleId) ?: continue
            add(
                DevotionCard(
                    id = "custom.$bundleId",
                    icon = iconForSystemName(info.iconSystemName),
                    title = info.localizedDisplayName,
                    accentColor = customAccent(info),
                    subtitle = defaultCustomDevotions[bundleId]?.name ?: "Tap to pray",
                    testTag = "${bundleId}Card",
                    onClick = {
                        val prayer = defaultCustomDevotions[bundleId]
                        if (prayer != null) onOpenPrayer(prayer.id) else onOpenCustomDevotion(bundleId)
                    },
                ),
            )
        }

        add(
            DevotionCard(
                id = PrayerKind.JesusPrayer.name,
                icon = Icons.Filled.Favorite,
                title = PrayerKind.JesusPrayer.displayName,
                accentColor = jesusPrayerAccent,
                subtitle = jesusPrayerSubtitle,
                testTag = "jesusPrayerCard",
                onClick = {
                    val prayer = defaultJesusPrayer
                    if (prayer != null) onOpenPrayer(prayer.id) else onOpenJesusPrayerSetup()
                },
            ),
        )
    }

    Box(modifier = Modifier.fillMaxSize().windowInsetsPadding(WindowInsets.safeDrawing)) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp),
            modifier = Modifier
                .align(Alignment.TopCenter)
                .widthIn(max = 480.dp)
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(24.dp),
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(4.dp),
                modifier = Modifier.padding(bottom = 4.dp),
            ) {
                Text(
                    "Prosary",
                    style = MaterialTheme.typography.headlineLarge,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.extraColors.headline,
                )
                Text(
                    "A companion for Catholic prayer",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                )
            }

            Column(verticalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth()) {
                for (card in devotionCards) {
                    PrayerCard(
                        icon = card.icon,
                        title = card.title,
                        subtitle = card.subtitle,
                        accentColor = card.accentColor,
                        onClick = card.onClick,
                        modifier = Modifier.testTag(card.testTag),
                    )
                }
            }

            HorizontalDivider(modifier = Modifier.padding(vertical = 4.dp))

            OutlinedButton(onClick = onOpenFavorites, modifier = Modifier.fillMaxWidth().height(52.dp)) {
                Text("My Favorites")
            }

            TextButton(onClick = onOpenSettings) {
                Text("Settings", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }

            TextButton(onClick = onOpenAbout) {
                Text("About", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}
