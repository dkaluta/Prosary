package com.dkaluta.Prosary.ui.shared

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import com.dkaluta.Prosary.models.Prayer
import com.dkaluta.Prosary.models.PrayerKind
import com.dkaluta.Prosary.services.LocalAppServices
import com.dkaluta.Prosary.ui.angelus.AngelusFlowScreen
import com.dkaluta.Prosary.ui.jesusprayer.JesusPrayerFlowScreen
import com.dkaluta.Prosary.ui.rosaryflow.RosaryFlowScreen

/** Resolves a [Prayer] by id from the store, forwards to the appropriate flow screen based on
 * [Prayer.kind]. Used when navigating to a saved favorite via the `prayer/{id}` route. */
@Composable
fun PrayerDispatchScreen(prayerId: String, onBack: () -> Unit) {
    val services = LocalAppServices.current
    var prayer by remember { mutableStateOf<Prayer?>(null) }

    LaunchedEffect(prayerId) {
        prayer = services.presetStore.get(prayerId)
    }

    val resolved = prayer
    if (resolved == null) {
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            CircularProgressIndicator()
        }
        return
    }

    when (resolved.kind) {
        PrayerKind.Rosary -> RosaryFlowScreen(prayer = resolved, onBack = onBack)
        PrayerKind.Angelus -> AngelusFlowScreen(prayer = resolved, onBack = onBack)
        // Launched directly from Home (one nav level), unlike the Setup-picker path — Finish
        // just pops back once, same as Rosary/Angelus.
        PrayerKind.JesusPrayer -> JesusPrayerFlowScreen(prayer = resolved, onNavigateUp = onBack, onFinish = onBack)
    }
}
