package com.dkaluta.prosary.ui

import org.junit.Assert.assertTrue
import org.junit.Test

class NavigationSingleTopOptionsTest {
    @Test
    fun ordinaryPushesUseSingleTopNavigation() {
        assertTrue(singleTopNavOptions().shouldLaunchSingleTop())
    }
}
