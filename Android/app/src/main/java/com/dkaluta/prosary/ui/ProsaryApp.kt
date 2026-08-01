package com.dkaluta.prosary.ui

import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import androidx.compose.runtime.Composable
import com.dkaluta.prosary.models.PrayerKind
import com.dkaluta.prosary.models.jesusPrayerTargetFromRouteValue
import com.dkaluta.prosary.models.toRouteValue
import com.dkaluta.prosary.ui.about.AboutScreen
import com.dkaluta.prosary.ui.favorites.FavoriteEditorScreen
import com.dkaluta.prosary.ui.favorites.FavoritesListScreen
import com.dkaluta.prosary.ui.favorites.RemindersOnlyEditorScreen
import com.dkaluta.prosary.ui.home.HomeScreen
import com.dkaluta.prosary.ui.home.RosaryPresetPickerScreen
import com.dkaluta.prosary.ui.rosaryflow.RosaryFlowScreen
import com.dkaluta.prosary.ui.jesusprayer.JesusPrayerFlowScreen
import com.dkaluta.prosary.ui.jesusprayer.JesusPrayerSetupScreen
import com.dkaluta.prosary.ui.settings.SettingsScreen
import com.dkaluta.prosary.ui.shared.CustomDevotionFlowScreen
import com.dkaluta.prosary.ui.shared.PrayerDispatchScreen
import com.dkaluta.prosary.models.Prayer

/** Carries the picker's ad-hoc, unsaved Rosary across one navigation hop — Compose routes are
 * strings, so a whole Prayer can't ride the route (see Routes.RosaryQuickPray). */
private object AdHocRosaryHolder {
    var prayer: Prayer? = null
}

private object Routes {
    const val Home = "home"
    const val Favorites = "favorites"
    const val RepositoryBrowser = "favorites/repository"
    // `kind` seeds a brand-new favorite's type when prayerId is absent (Android has no
    // equivalent to iOS's sheet(item:) passing a whole ad-hoc Prayer object across screens, so
    // the "Add" action threads just enough to construct one — see FavoriteEditorScreen).
    const val FavoriteEditor = "favorites/editor?prayerId={prayerId}&kind={kind}"
    const val RemindersOnlyEditor = "favorites/reminders/{prayerId}"
    const val About = "about"
    const val Settings = "settings"
    const val Prayer = "prayer/{id}"
    // Home -> Rosary preset picker; the ad-hoc session rides a holder object because Compose
    // routes are strings (same reasoning as FavoriteEditor's kind param above).
    const val RosaryPicker = "rosary/picker"
    const val RosaryQuickPray = "rosary/quickPray"
    const val JesusPrayerSetup = "jesusPrayer/setup"
    const val JesusPrayerFlow = "jesusPrayer/{target}"
    // Launches a generic (bundle-driven) devotion with no existing favorite — devotionId is the
    // bundle id, e.g. "trisagion". See PrayerKind.Custom.
    const val Custom = "custom/{devotionId}"

    fun prayer(id: String) = "prayer/$id"
    fun favoriteEditor(prayerId: String?, kind: PrayerKind? = null): String {
        val params = buildList {
            if (prayerId != null) add("prayerId=$prayerId")
            if (kind != null) add("kind=${kind.name}")
        }
        return if (params.isEmpty()) "favorites/editor" else "favorites/editor?${params.joinToString("&")}"
    }
    fun remindersOnlyEditor(prayerId: String) = "favorites/reminders/$prayerId"
    fun jesusPrayerFlow(target: String) = "jesusPrayer/$target"
    fun custom(devotionId: String) = "custom/$devotionId"
}

@Composable
fun ProsaryApp() {
    val navController = rememberNavController()

    NavHost(navController = navController, startDestination = Routes.Home) {
        composable(Routes.Home) {
            HomeScreen(
                onOpenPrayer = { id -> navController.navigate(Routes.prayer(id)) },
                onOpenRosaryPicker = { navController.navigate(Routes.RosaryPicker) },
                onOpenFavorites = { navController.navigate(Routes.Favorites) },
                onOpenAbout = { navController.navigate(Routes.About) },
                onOpenSettings = { navController.navigate(Routes.Settings) },
                onOpenJesusPrayerSetup = { navController.navigate(Routes.JesusPrayerSetup) },
                onOpenCustomDevotion = { devotionId -> navController.navigate(Routes.custom(devotionId)) },
            )
        }

        composable(
            route = Routes.Custom,
            arguments = listOf(navArgument("devotionId") { type = NavType.StringType }),
        ) { backStackEntry ->
            val devotionId = backStackEntry.arguments?.getString("devotionId")
            if (devotionId != null) {
                CustomDevotionFlowScreen(devotionId = devotionId, onBack = { navController.popBackStack() })
            }
        }

        composable(Routes.RosaryPicker) {
            RosaryPresetPickerScreen(
                onPrayPreset = { id -> navController.navigate(Routes.prayer(id)) },
                onPrayAdHoc = { prayer ->
                    AdHocRosaryHolder.prayer = prayer
                    navController.navigate(Routes.RosaryQuickPray)
                },
                onOpenFavorites = { navController.navigate(Routes.Favorites) },
                onBack = { navController.popBackStack() },
            )
        }

        composable(Routes.RosaryQuickPray) {
            val prayer = AdHocRosaryHolder.prayer
            if (prayer != null) {
                RosaryFlowScreen(prayer = prayer, onBack = { navController.popBackStack() })
            }
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
                onEditReminders = { prayerId -> navController.navigate(Routes.remindersOnlyEditor(prayerId)) },
                onBrowseRepository = { navController.navigate(Routes.RepositoryBrowser) },
                onBack = { navController.popBackStack() },
            )
        }
        composable(Routes.RepositoryBrowser) {
            com.dkaluta.prosary.ui.favorites.RepositoryBrowserScreen(
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

        composable(
            route = Routes.RemindersOnlyEditor,
            arguments = listOf(navArgument("prayerId") { type = NavType.StringType }),
        ) { backStackEntry ->
            val prayerId = backStackEntry.arguments?.getString("prayerId")
            if (prayerId != null) {
                RemindersOnlyEditorScreen(prayerId = prayerId, onDone = { navController.popBackStack() })
            }
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
