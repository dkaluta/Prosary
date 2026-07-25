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
import androidx.compose.material.icons.filled.Circle
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Notifications
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

@Composable
fun HomeScreen(
    onOpenPrayer: (String) -> Unit,
    onOpenFavorites: () -> Unit,
    onOpenAbout: () -> Unit,
    onOpenSettings: () -> Unit,
    onOpenAngelus: () -> Unit,
    onOpenJesusPrayerSetup: () -> Unit,
) {
    val services = LocalAppServices.current

    var todayMysteryGroup by remember { mutableStateOf<MysteryGroup?>(null) }
    var defaultRosary by remember { mutableStateOf<Prayer?>(null) }
    var defaultAngelus by remember { mutableStateOf<Prayer?>(null) }
    var defaultJesusPrayer by remember { mutableStateOf<Prayer?>(null) }

    LaunchedEffect(Unit) {
        todayMysteryGroup = services.calendar.mysteryGroupToday()
        val all = runCatching { services.presetStore.all() }.getOrDefault(emptyList())
        defaultRosary = all.firstOrNull { it.kind == PrayerKind.Rosary && it.isDefault }
            ?: all.firstOrNull { it.kind == PrayerKind.Rosary }
        defaultAngelus = all.firstOrNull { it.kind == PrayerKind.Angelus && it.isDefault }
            ?: all.firstOrNull { it.kind == PrayerKind.Angelus }
        defaultJesusPrayer = all.firstOrNull { it.kind == PrayerKind.JesusPrayer && it.isDefault }
            ?: all.firstOrNull { it.kind == PrayerKind.JesusPrayer }
    }

    val rosaryAccent = todayMysteryGroup?.color ?: MaterialTheme.colorScheme.primary
    // Fixed accent colors for the other two cards, matching iOS's HomeView.
    val angelusAccent = Color(0xFF8B6914)
    val jesusPrayerAccent = Color(0xFF8B1A1A)

    val rosarySubtitle = buildString {
        todayMysteryGroup?.let { append("Today: ${it.displayName}") }
        defaultRosary?.let {
            if (isNotEmpty()) append(" • ")
            append(it.name)
        }
    }
    val angelusSubtitle = defaultAngelus?.name ?: "Tap to pray"
    val jesusPrayerSubtitle = defaultJesusPrayer?.let { "${it.name} • ${it.jesusPrayer.targetDisplayName}" } ?: "Tap to set up"

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
                PrayerCard(
                    icon = Icons.Filled.Circle,
                    title = "Rosary",
                    subtitle = rosarySubtitle,
                    accentColor = rosaryAccent,
                    onClick = {
                        val prayer = defaultRosary
                        if (prayer != null) onOpenPrayer(prayer.id) else onOpenFavorites()
                    },
                    modifier = Modifier.testTag("rosaryCard"),
                )

                PrayerCard(
                    icon = Icons.Filled.Notifications,
                    title = "Angelus",
                    subtitle = angelusSubtitle,
                    accentColor = angelusAccent,
                    onClick = {
                        val prayer = defaultAngelus
                        if (prayer != null) onOpenPrayer(prayer.id) else onOpenAngelus()
                    },
                    modifier = Modifier.testTag("angelusCard"),
                )

                PrayerCard(
                    icon = Icons.Filled.Favorite,
                    title = "Jesus Prayer",
                    subtitle = jesusPrayerSubtitle,
                    accentColor = jesusPrayerAccent,
                    onClick = {
                        val prayer = defaultJesusPrayer
                        if (prayer != null) onOpenPrayer(prayer.id) else onOpenJesusPrayerSetup()
                    },
                    modifier = Modifier.testTag("jesusPrayerCard"),
                )
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
