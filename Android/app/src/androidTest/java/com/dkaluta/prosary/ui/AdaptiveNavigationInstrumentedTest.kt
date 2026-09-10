package com.dkaluta.prosary.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.requiredWidth
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test

class AdaptiveNavigationInstrumentedTest {
    @get:Rule val compose = createAndroidComposeRule<AdaptiveLayoutTestActivity>()

    @Test fun switchingBetweenPhoneAndRailKeepsTheDestinationAlive() {
        var width by mutableStateOf(380.dp)
        var disposals = 0
        compose.setContent {
            CompositionLocalProvider(LocalDensity provides Density(0.75f)) {
                MaterialTheme {
                    AdaptiveNavigationShell(
                        showsTabs = true,
                        modifier = Modifier.requiredWidth(width),
                        rail = { Text("Rail") },
                        bottomBar = { Text("Tabs") },
                    ) { modifier ->
                        var count by remember { mutableIntStateOf(0) }
                        DisposableEffect(Unit) { onDispose { disposals++ } }
                        Box(modifier) {
                            Button(onClick = { count++ }) { Text("Count $count") }
                        }
                    }
                }
            }
        }
        compose.onNodeWithText("Count 0").performClick()
        repeat(3) {
            compose.runOnIdle { width = 1000.dp }
            compose.onNodeWithText("Rail").assertExists()
            compose.onNodeWithText("Count 1").assertExists()
            compose.runOnIdle { width = 380.dp }
            compose.onNodeWithText("Tabs").assertExists()
            compose.onNodeWithText("Count 1").assertExists()
        }
        compose.runOnIdle { assertEquals("A width change must not dispose the current screen", 0, disposals) }
    }
}
