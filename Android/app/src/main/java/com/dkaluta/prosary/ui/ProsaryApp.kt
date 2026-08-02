package com.dkaluta.prosary.ui

import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.consumeWindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Language
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.GridView
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationRail
import androidx.compose.material3.NavigationRailItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import androidx.compose.runtime.Composable
import com.dkaluta.prosary.ui.categories.CategoriesScreen
import com.dkaluta.prosary.ui.search.SearchScreen
import com.dkaluta.prosary.ui.shared.LaunchTarget
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
    const val Browse = "browse"
    const val Categories = "categories"
    const val Search = "search"
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

private data class TabSpec(val route: String, val label: String, val icon: ImageVector)

/** The app's tab shell: Pray (Home), Browse (prayers.prosary.app), Categories, Search —
 * bottom NavigationBar on phones, NavigationRail on wide layouts ("bottom on phone, side on
 * computer"). The bar shows only on the four top-level tab destinations; inner screens
 * (flows, editors) keep the full height. Mirrors iOS's ContentView TabView. */
@Composable
fun ProsaryApp() {
    val navController = rememberNavController()
    val tabs = listOf(
        TabSpec(Routes.Home, "Pray", Icons.Filled.Home),
        TabSpec(Routes.Browse, "Browse", Icons.Filled.Language),
        TabSpec(Routes.Categories, "Categories", Icons.Filled.GridView),
        TabSpec(Routes.Search, "Search", Icons.Filled.Search),
    )
    val backStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = backStackEntry?.destination?.route
    val showsTabs = tabs.any { it.route == currentRoute }

    fun selectTab(route: String) {
        navController.navigate(route) {
            popUpTo(Routes.Home) { saveState = true }
            launchSingleTop = true
            restoreState = true
        }
    }

    BoxWithConstraints {
        if (maxWidth >= 840.dp) {
            Row(Modifier.fillMaxSize()) {
                if (showsTabs) {
                    NavigationRail {
                        for (tab in tabs) {
                            NavigationRailItem(
                                selected = currentRoute == tab.route,
                                onClick = { selectTab(tab.route) },
                                icon = { Icon(tab.icon, contentDescription = null) },
                                label = { Text(tab.label) },
                            )
                        }
                    }
                }
                AppNavHost(navController, Modifier.weight(1f))
            }
        } else {
            Scaffold(
                // Every destination carries its own Scaffold/TopAppBar and applies the system
                // insets itself — if the shell consumes them too, status- and nav-bar padding
                // lands twice and the whole app looks "framed by bars". The shell's padding
                // should only ever be the tab bar's own height (the NavigationBar composable
                // handles its own bottom inset internally).
                contentWindowInsets = WindowInsets(0, 0, 0, 0),
                bottomBar = {
                    if (showsTabs) {
                        NavigationBar {
                            for (tab in tabs) {
                                NavigationBarItem(
                                    selected = currentRoute == tab.route,
                                    onClick = { selectTab(tab.route) },
                                    icon = { Icon(tab.icon, contentDescription = null) },
                                    label = { Text(tab.label) },
                                )
                            }
                        }
                    }
                },
            ) { paddingValues ->
                AppNavHost(
                    navController,
                    Modifier
                        .padding(paddingValues)
                        // The tab bar already spans the gesture-nav inset, so tab screens'
                        // own Scaffolds must not pad for it again — that painted a dead band
                        // between the scrolling content and the bar. Flow destinations hide
                        // the bar and keep the inset for their own footers.
                        .then(
                            if (showsTabs) {
                                Modifier.consumeWindowInsets(WindowInsets.navigationBars)
                            } else {
                                Modifier
                            },
                        ),
                )
            }
        }
    }
}

private fun NavHostController.launch(target: LaunchTarget) {
    when (target) {
        LaunchTarget.Rosary -> navigate(Routes.RosaryPicker)
        is LaunchTarget.Custom -> navigate(Routes.custom(target.bundleId))
        LaunchTarget.JesusPrayer -> navigate(Routes.JesusPrayerSetup)
    }
}

@Composable
private fun AppNavHost(navController: NavHostController, modifier: Modifier = Modifier) {
    NavHost(navController = navController, startDestination = Routes.Home, modifier = modifier) {
        composable(Routes.Browse) {
            com.dkaluta.prosary.ui.favorites.RepositoryBrowserScreen(onBack = {}, showsBackButton = false)
        }
        composable(Routes.Categories) {
            CategoriesScreen(onLaunch = { target -> navController.launch(target) })
        }
        composable(Routes.Search) {
            SearchScreen(onLaunch = { target -> navController.launch(target) })
        }
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
