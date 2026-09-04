package com.dkaluta.prosary.ui

import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class NavigationSingleTopInstrumentedTest {
    @get:Rule
    val composeTestRule = createComposeRule()

    @Test
    fun duplicatePushNeedsOnlyOneBackToReachOrigin() {
        lateinit var navController: NavHostController
        composeTestRule.setContent {
            navController = rememberNavController()
            NavHost(navController, startDestination = "home") {
                composable("home") { }
                composable("rosary/picker") { }
            }
        }

        composeTestRule.runOnIdle {
            navController.navigateSingleTop("rosary/picker")
            navController.navigateSingleTop("rosary/picker")

            assertEquals("rosary/picker", navController.currentDestination?.route)
            assertTrue(navController.popBackStack())
            assertEquals("home", navController.currentDestination?.route)
        }
    }
}
