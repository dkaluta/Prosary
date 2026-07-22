package com.dkaluta.Prosary.ui

import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import androidx.compose.runtime.Composable
import com.dkaluta.Prosary.ui.about.AboutScreen
import com.dkaluta.Prosary.ui.home.HomeScreen
import com.dkaluta.Prosary.ui.presets.PresetEditorScreen
import com.dkaluta.Prosary.ui.presets.PresetsListScreen
import com.dkaluta.Prosary.ui.rosaryflow.RosaryFlowScreen

private object Routes {
    const val Home = "home"
    const val Presets = "presets"
    const val About = "about"
    const val Rosary = "rosary/{configId}"
    const val PresetEditor = "presets/editor?configId={configId}"

    fun rosary(configId: String) = "rosary/$configId"
    fun presetEditor(configId: String?) = if (configId != null) "presets/editor?configId=$configId" else "presets/editor"
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
