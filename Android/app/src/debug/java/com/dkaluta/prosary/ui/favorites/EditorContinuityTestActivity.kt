package com.dkaluta.prosary.ui.favorites

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Column
import androidx.compose.material3.Button
import androidx.compose.material3.Text
import androidx.compose.runtime.CompositionLocalProvider
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.dkaluta.prosary.models.JesusPrayerTarget
import com.dkaluta.prosary.models.PrayerKind
import com.dkaluta.prosary.services.AppServices
import com.dkaluta.prosary.services.LocalAppServices
import com.dkaluta.prosary.ui.jesusprayer.JesusPrayerSetupScreen
import com.dkaluta.prosary.ui.theme.ProsaryTheme

/** Debug-only host: exercises real editor/navigation lifecycles with an isolated in-memory
 * store. It never constructs the production database or changes the person's library. */
class EditorContinuityTestActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            ProsaryTheme {
                CompositionLocalProvider(LocalAppServices provides requireNotNull(services)) {
                    val navigation = rememberNavController()
                    NavHost(navigation, startDestination = "editors") {
                        composable("editors") {
                            Column {
                                Button(onClick = { navigation.navigate("favorite") }) { Text("Open favorite editor") }
                                Button(onClick = { navigation.navigate("reminders") }) { Text("Open reminder editor") }
                                Button(onClick = { navigation.navigate("setup") }) { Text("Open Jesus Prayer setup") }
                            }
                        }
                        composable("favorite") {
                            FavoriteEditorScreen(prayerId, newFavoriteKind) { navigation.popBackStack() }
                        }
                        composable("reminders") {
                            RemindersOnlyEditorScreen(requireNotNull(prayerId)) { navigation.popBackStack() }
                        }
                        composable("setup") {
                            JesusPrayerSetupScreen(
                                onBack = { navigation.popBackStack() },
                                onBegin = { lastTarget = it; navigation.popBackStack() },
                            )
                        }
                    }
                }
            }
        }
    }

    companion object {
        var services: AppServices? = null
        var prayerId: String? = null
        var newFavoriteKind: PrayerKind = PrayerKind.Rosary
        var lastTarget: JesusPrayerTarget? = null
    }
}
