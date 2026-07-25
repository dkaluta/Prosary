package com.dkaluta.Prosary.ui

import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import androidx.compose.runtime.Composable
import com.dkaluta.Prosary.models.PrayerKind
import com.dkaluta.Prosary.models.jesusPrayerTargetFromRouteValue
import com.dkaluta.Prosary.models.toRouteValue
import com.dkaluta.Prosary.ui.about.AboutScreen
import com.dkaluta.Prosary.ui.angelus.AngelusFlowScreen
import com.dkaluta.Prosary.ui.favorites.FavoriteEditorScreen
import com.dkaluta.Prosary.ui.favorites.FavoritesListScreen
import com.dkaluta.Prosary.ui.home.HomeScreen
import com.dkaluta.Prosary.ui.jesusprayer.JesusPrayerFlowScreen
import com.dkaluta.Prosary.ui.jesusprayer.JesusPrayerSetupScreen
import com.dkaluta.Prosary.ui.settings.SettingsScreen
import com.dkaluta.Prosary.ui.shared.PrayerDispatchScreen

private object Routes {
    const val Home = "home"
    const val Favorites = "favorites"
    // `kind` seeds a brand-new favorite's type when prayerId is absent (Android has no
    // equivalent to iOS's sheet(item:) passing a whole ad-hoc Prayer object across screens, so
    // the "Add" action threads just enough to construct one — see FavoriteEditorScreen).
    const val FavoriteEditor = "favorites/editor?prayerId={prayerId}&kind={kind}"
    const val About = "about"
    const val Settings = "settings"
    const val Prayer = "prayer/{id}"
    const val Angelus = "angelus"
    const val JesusPrayerSetup = "jesusPrayer/setup"
    const val JesusPrayerFlow = "jesusPrayer/{target}"

    fun prayer(id: String) = "prayer/$id"
    fun favoriteEditor(prayerId: String?, kind: PrayerKind? = null): String {
        val params = buildList {
            if (prayerId != null) add("prayerId=$prayerId")
            if (kind != null) add("kind=${kind.name}")
        }
        return if (params.isEmpty()) "favorites/editor" else "favorites/editor?${params.joinToString("&")}"
    }
    fun jesusPrayerFlow(target: String) = "jesusPrayer/$target"
}

@Composable
fun ProsaryApp() {
    val navController = rememberNavController()

    NavHost(navController = navController, startDestination = Routes.Home) {
        composable(Routes.Home) {
            HomeScreen(
                onOpenPrayer = { id -> navController.navigate(Routes.prayer(id)) },
                onOpenFavorites = { navController.navigate(Routes.Favorites) },
                onOpenAbout = { navController.navigate(Routes.About) },
                onOpenSettings = { navController.navigate(Routes.Settings) },
                onOpenAngelus = { navController.navigate(Routes.Angelus) },
                onOpenJesusPrayerSetup = { navController.navigate(Routes.JesusPrayerSetup) },
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

        composable(Routes.Favorites) {
            FavoritesListScreen(
                onPray = { id -> navController.navigate(Routes.prayer(id)) },
                onEdit = { prayerId -> navController.navigate(Routes.favoriteEditor(prayerId)) },
                onAddNew = { kind -> navController.navigate(Routes.favoriteEditor(null, kind)) },
                onBack = { navController.popBackStack() },
            )
        }

        composable(
            route = Routes.FavoriteEditor,
            arguments = listOf(
                navArgument("prayerId") { type = NavType.StringType; nullable = true; defaultValue = null },
                navArgument("kind") { type = NavType.StringType; nullable = true; defaultValue = null },
            ),
        ) { backStackEntry ->
            val prayerId = backStackEntry.arguments?.getString("prayerId")
            val kind = backStackEntry.arguments?.getString("kind")
                ?.let { runCatching { PrayerKind.valueOf(it) }.getOrNull() }
                ?: PrayerKind.Rosary
            FavoriteEditorScreen(prayerId = prayerId, newFavoriteKind = kind, onDone = { navController.popBackStack() })
        }

        composable(Routes.About) {
            AboutScreen(onBack = { navController.popBackStack() })
        }

        composable(Routes.Settings) {
            SettingsScreen(onBack = { navController.popBackStack() })
        }

        composable(
            route = Routes.Prayer,
            arguments = listOf(navArgument("id") { type = NavType.StringType }),
        ) { backStackEntry ->
            val id = backStackEntry.arguments?.getString("id")
            if (id != null) {
                PrayerDispatchScreen(prayerId = id, onBack = { navController.popBackStack() })
            }
        }
    }
}
