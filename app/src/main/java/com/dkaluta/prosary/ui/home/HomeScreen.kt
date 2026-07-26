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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.DirectionsWalk
import androidx.compose.material.icons.filled.Circle
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.WaterDrop
import androidx.compose.material.icons.filled.WbSunny
import androidx.compose.material.icons.filled.WorkspacePremium
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
import com.dkaluta.prosary.models.MysteryGroup
import com.dkaluta.prosary.models.Prayer
import com.dkaluta.prosary.models.PrayerKind
import com.dkaluta.prosary.services.LocalAppServices
import com.dkaluta.prosary.ui.shared.PrayerCard
import com.dkaluta.prosary.ui.theme.extraColors

/** One devotion's rendering state for a Home card. Adding a new devotion means adding one entry
 * to [HomeScreen]'s card list — the accent/subtitle/launch logic for each kind can still be as
 * bespoke as it needs to be (e.g. Rosary's mystery-of-the-day accent color), but the composable
 * body itself no longer hand-rolls a [PrayerCard] block per kind. */
private data class DevotionCard(
    val kind: PrayerKind,
    val icon: ImageVector,
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
    onOpenAngelus: () -> Unit,
    onOpenStationsOfTheCross: () -> Unit,
    onOpenFranciscanCrown: () -> Unit,
    onOpenSevenSorrows: () -> Unit,
    onOpenDivineMercyChaplet: () -> Unit,
    onOpenJesusPrayerSetup: () -> Unit,
) {
    val services = LocalAppServices.current

    var todayMysteryGroup by remember { mutableStateOf<MysteryGroup?>(null) }
    var defaultRosary by remember { mutableStateOf<Prayer?>(null) }
    var defaultAngelus by remember { mutableStateOf<Prayer?>(null) }
    var defaultJesusPrayer by remember { mutableStateOf<Prayer?>(null) }
    var defaultStations by remember { mutableStateOf<Prayer?>(null) }
    var defaultFranciscanCrown by remember { mutableStateOf<Prayer?>(null) }
    var defaultSevenSorrows by remember { mutableStateOf<Prayer?>(null) }
    var defaultDivineMercy by remember { mutableStateOf<Prayer?>(null) }

    LaunchedEffect(Unit) {
        todayMysteryGroup = services.calendar.mysteryGroupToday()
        val all = runCatching { services.presetStore.all() }.getOrDefault(emptyList())
        defaultRosary = all.firstOrNull { it.kind == PrayerKind.Rosary && it.isDefault }
            ?: all.firstOrNull { it.kind == PrayerKind.Rosary }
        defaultAngelus = all.firstOrNull { it.kind == PrayerKind.Angelus && it.isDefault }
            ?: all.firstOrNull { it.kind == PrayerKind.Angelus }
        defaultJesusPrayer = all.firstOrNull { it.kind == PrayerKind.JesusPrayer && it.isDefault }
            ?: all.firstOrNull { it.kind == PrayerKind.JesusPrayer }
        defaultStations = all.firstOrNull { it.kind == PrayerKind.StationsOfTheCross && it.isDefault }
            ?: all.firstOrNull { it.kind == PrayerKind.StationsOfTheCross }
        defaultFranciscanCrown = all.firstOrNull { it.kind == PrayerKind.FranciscanCrown && it.isDefault }
            ?: all.firstOrNull { it.kind == PrayerKind.FranciscanCrown }
        defaultSevenSorrows = all.firstOrNull { it.kind == PrayerKind.SevenSorrows && it.isDefault }
            ?: all.firstOrNull { it.kind == PrayerKind.SevenSorrows }
        defaultDivineMercy = all.firstOrNull { it.kind == PrayerKind.DivineMercyChaplet && it.isDefault }
            ?: all.firstOrNull { it.kind == PrayerKind.DivineMercyChaplet }
    }

    val rosaryAccent = todayMysteryGroup?.color ?: MaterialTheme.colorScheme.primary
    // Fixed accent colors for the other cards, matching iOS's HomeView.
    val angelusAccent = Color(0xFF8B6914)
    val jesusPrayerAccent = Color(0xFF8B1A1A)
    val stationsAccent = Color(0xFF5C2D91)
    val franciscanCrownAccent = Color(0xFF6B4226)
    val sevenSorrowsAccent = Color(0xFF6B0F1A)
    val divineMercyAccent = Color(0xFFC41E3A)

    val rosarySubtitle = buildString {
        todayMysteryGroup?.let { append("Today: ${it.displayName}") }
        defaultRosary?.let {
            if (isNotEmpty()) append(" • ")
            append(it.name)
        }
    }
    val angelusSubtitle = defaultAngelus?.name ?: "Tap to pray"
    val jesusPrayerSubtitle = defaultJesusPrayer?.let { "${it.name} • ${it.jesusPrayer.targetDisplayName}" } ?: "Tap to set up"
    val stationsSubtitle = defaultStations?.name ?: "Tap to pray"
    val franciscanCrownSubtitle = defaultFranciscanCrown?.name ?: "Tap to pray"
    val sevenSorrowsSubtitle = defaultSevenSorrows?.name ?: "Tap to pray"
    val divineMercySubtitle = defaultDivineMercy?.name ?: "Tap to pray"

    val devotionCards = listOf(
        DevotionCard(
            kind = PrayerKind.Rosary,
            icon = Icons.Filled.Circle,
            accentColor = rosaryAccent,
            subtitle = rosarySubtitle,
            testTag = "rosaryCard",
            onClick = {
                val prayer = defaultRosary
                if (prayer != null) onOpenPrayer(prayer.id) else onOpenFavorites()
            },
        ),
        DevotionCard(
            kind = PrayerKind.Angelus,
            icon = Icons.Filled.Notifications,
            accentColor = angelusAccent,
            subtitle = angelusSubtitle,
            testTag = "angelusCard",
            onClick = {
                val prayer = defaultAngelus
                if (prayer != null) onOpenPrayer(prayer.id) else onOpenAngelus()
            },
        ),
        DevotionCard(
            kind = PrayerKind.JesusPrayer,
            icon = Icons.Filled.Favorite,
            accentColor = jesusPrayerAccent,
            subtitle = jesusPrayerSubtitle,
            testTag = "jesusPrayerCard",
            onClick = {
                val prayer = defaultJesusPrayer
                if (prayer != null) onOpenPrayer(prayer.id) else onOpenJesusPrayerSetup()
            },
        ),
        DevotionCard(
            kind = PrayerKind.StationsOfTheCross,
            icon = Icons.AutoMirrored.Filled.DirectionsWalk,
            accentColor = stationsAccent,
            subtitle = stationsSubtitle,
            testTag = "stationsOfTheCrossCard",
            onClick = {
                val prayer = defaultStations
                if (prayer != null) onOpenPrayer(prayer.id) else onOpenStationsOfTheCross()
            },
        ),
        DevotionCard(
            kind = PrayerKind.FranciscanCrown,
            icon = Icons.Filled.WorkspacePremium,
            accentColor = franciscanCrownAccent,
            subtitle = franciscanCrownSubtitle,
            testTag = "franciscanCrownCard",
            onClick = {
                val prayer = defaultFranciscanCrown
                if (prayer != null) onOpenPrayer(prayer.id) else onOpenFranciscanCrown()
            },
        ),
        DevotionCard(
            kind = PrayerKind.SevenSorrows,
            icon = Icons.Filled.WaterDrop,
            accentColor = sevenSorrowsAccent,
            subtitle = sevenSorrowsSubtitle,
            testTag = "sevenSorrowsCard",
            onClick = {
                val prayer = defaultSevenSorrows
                if (prayer != null) onOpenPrayer(prayer.id) else onOpenSevenSorrows()
            },
        ),
        DevotionCard(
            kind = PrayerKind.DivineMercyChaplet,
            icon = Icons.Filled.WbSunny,
            accentColor = divineMercyAccent,
            subtitle = divineMercySubtitle,
            testTag = "divineMercyCard",
            onClick = {
                val prayer = defaultDivineMercy
                if (prayer != null) onOpenPrayer(prayer.id) else onOpenDivineMercyChaplet()
            },
        ),
    )

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
                        title = card.kind.displayName,
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
