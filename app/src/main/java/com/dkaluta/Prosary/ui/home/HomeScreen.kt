package com.dkaluta.Prosary.ui.home

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.dkaluta.Prosary.services.LocalAppServices
import com.dkaluta.Prosary.ui.theme.extraColors

@Composable
fun HomeScreen(onPray: (String) -> Unit, onOpenPresets: () -> Unit, onOpenAbout: () -> Unit) {
    val services = LocalAppServices.current

    var todayMysteryGroupName by remember { mutableStateOf("") }
    var seasonColor by remember { mutableStateOf(Color.Transparent) }
    var defaultPresetName by remember { mutableStateOf("") }
    var defaultPresetId by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(Unit) {
        todayMysteryGroupName = services.calendar.mysteryGroupToday().displayName
        seasonColor = services.calendar.seasonColorToday()
        val preset = runCatching { services.presetStore.defaultPreset() }.getOrNull()
        if (preset != null) {
            defaultPresetName = preset.name
            defaultPresetId = preset.id
        }
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
            Text(
                "Prosary",
                style = MaterialTheme.typography.headlineLarge,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.extraColors.headline,
            )

            Text(
                "A companion for praying the Rosary and other Catholic devotions",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )

            HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp))

            if (todayMysteryGroupName.isNotEmpty()) {
                Surface(color = seasonColor, shape = RoundedCornerShape(percent = 50)) {
                    Row(modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)) {
                        Text("Today's Mysteries: ", color = Color.White)
                        Text(todayMysteryGroupName, color = Color.White, fontWeight = FontWeight.Bold)
                    }
                }
            }

            if (defaultPresetName.isNotEmpty()) {
                Text(
                    "Preset: $defaultPresetName",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            Button(
                onClick = { defaultPresetId?.let(onPray) },
                modifier = Modifier.fillMaxWidth().padding(top = 16.dp).height(52.dp),
                colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.primary),
            ) {
                Text("Pray the Rosary")
            }

            OutlinedButton(onClick = onOpenPresets, modifier = Modifier.fillMaxWidth().height(52.dp)) {
                Text("My Presets")
            }

            TextButton(onClick = onOpenAbout, modifier = Modifier.padding(top = 8.dp)) {
                Text(
                    "About",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}
