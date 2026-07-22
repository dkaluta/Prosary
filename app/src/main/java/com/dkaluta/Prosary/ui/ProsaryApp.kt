package com.dkaluta.Prosary.ui

import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import androidx.compose.runtime.Composable
import com.dkaluta.Prosary.models.jesusPrayerTargetFromRouteValue
import com.dkaluta.Prosary.models.toRouteValue
import com.dkaluta.Prosary.ui.about.AboutScreen
import com.dkaluta.Prosary.ui.angelus.AngelusFlowScreen
import com.dkaluta.Prosary.ui.home.HomeScreen
import com.dkaluta.Prosary.ui.jesusprayer.JesusPrayerFlowScreen
import com.dkaluta.Prosary.ui.jesusprayer.JesusPrayerSetupScreen
import com.dkaluta.Prosary.ui.presets.PresetEditorScreen
import com.dkaluta.Prosary.ui.presets.PresetsListScreen
import com.dkaluta.Prosary.ui.rosaryflow.RosaryFlowScreen

private object Routes {
    const val Home = "home"
    const val Presets = "presets"
    const val About = "about"
    const val Rosary = "rosary/{configId}"
    const val PresetEditor = "presets/editor?configId={configId}"
    const val Angelus = "angelus"
    const val JesusPrayerSetup = "jesusPrayer/setup"
    const val JesusPrayerFlow = "jesusPrayer/{target}"

    fun rosary(configId: String) = "rosary/$configId"
    fun presetEditor(configId: String?) = if (configId != null) "presets/editor?configId=$configId" else "presets/editor"
    fun jesusPrayerFlow(target: String) = "jesusPrayer/$target"
}

@Composable
fun ProsaryApp() {
    val navController = rememberNavController()

    NavHost(navController = navController, startDestination = Routes.Home) {
        composable(Routes.Home) {
            HomeScreen(
                onPray = { configId -> navController.navigate(Routes.rosary(configId)) },
                onOpenPresets = { navController.navigate(Routes.Presets) },
                onOpenAbout = { navController.navigate(Routes.About) },
                onOpenAngelus = { navController.navigate(Routes.Angelus) },
                onOpenJesusPrayer = { navController.navigate(Routes.JesusPrayerSetup) },
            )
        }

        composable(Routes.Angelus) {
            AngelusFlowScreen(onBack = { navController.popBackStack() })
        }

        composable(Routes.JesusPrayerSetup) {
            JesusPrayerSetupScreen(
                onBack = { navController.popBackStack() },
                onBegin = { target -> navController.navigate(Routes.jesusPrayerFlow(target.toRouteValue())) },
            )
        }

        composable(
            route = Routes.JesusPrayerFlow,
            arguments = listOf(navArgument("target") { type = NavType.StringType }),
        ) { backStackEntry ->
            val target = jesusPrayerTargetFromRouteValue(backStackEntry.arguments?.getString("target") ?: "unbounded")
            JesusPrayerFlowScreen(
                target = target,
                onNavigateUp = { navController.popBackStack() },
                onFinish = { navController.popBackStack(Routes.Home, inclusive = false) },
            )
        }

        composable(Routes.Presets) {
            PresetsListScreen(
                onPray = { configId -> navController.navigate(Routes.rosary(configId)) },
                onEdit = { configId -> navController.navigate(Routes.presetEditor(configId)) },
                onBack = { navController.popBackStack() },
            )
        }

        composable(
            route = Routes.PresetEditor,
            arguments = listOf(navArgument("configId") { type = NavType.StringType; nullable = true; defaultValue = null }),
        ) { backStackEntry ->
            val configId = backStackEntry.arguments?.getString("configId")
            PresetEditorScreen(configId = configId, onDone = { navController.popBackStack() })
        }

        composable(Routes.About) {
            AboutScreen(onBack = { navController.popBackStack() })
        }

        composable(
            route = Routes.Rosary,
            arguments = listOf(navArgument("configId") { type = NavType.StringType }),
        ) { backStackEntry ->
            val configId = backStackEntry.arguments?.getString("configId")
            if (configId != null) {
                RosaryFlowScreen(configId = configId, onBack = { navController.popBackStack() })
            }
        }
    }
}
