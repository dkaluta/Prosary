package com.dkaluta.prosary

import com.dkaluta.prosary.models.AppColor
import java.io.File
import javax.xml.parsers.DocumentBuilderFactory
import org.junit.Assert.*
import org.junit.Test

class LauncherIconControllerTest {
    @Test fun everyTransitionKeepsALauncherAvailableAndEndsWithExactlyOne() {
        for (previous in AppColor.entries) for (selected in AppColor.entries) {
            val enabled = mutableSetOf(previous)
            for (change in launcherIconChanges(selected, enabled)) {
                if (change.enabled) enabled += change.color else enabled -= change.color
                assertTrue("$previous → $selected must remain launchable", enabled.isNotEmpty())
            }
            assertEquals(setOf(selected), enabled)
        }
    }

    @Test fun startupRepairsRestoredOrInterruptedAliasSelections() {
        for (initial in listOf(emptySet(), AppColor.entries.toSet(), setOf(AppColor.Red, AppColor.White))) {
            for (selected in AppColor.entries) {
                val enabled = initial.toMutableSet()
                launcherIconChanges(selected, enabled).forEach { change ->
                    if (change.enabled) enabled += change.color else enabled -= change.color
                }
                assertEquals(setOf(selected), enabled)
                assertTrue(launcherIconChanges(selected, enabled).isEmpty())
            }
        }
    }

    @Test fun aliasesKeepTheOriginalActivityAvailableForExistingDeepLinks() {
        val factory = DocumentBuilderFactory.newInstance().apply { isNamespaceAware = true }
        val document = factory.newDocumentBuilder().parse(File("src/main/AndroidManifest.xml"))
        val android = "http://schemas.android.com/apk/res/android"
        val activities = document.getElementsByTagName("activity")
        val main = (0 until activities.length).map { activities.item(it) as org.w3c.dom.Element }
            .single { it.getAttributeNS(android, "name") == ".MainActivity" }
        assertNotEquals("false", main.getAttributeNS(android, "enabled"))
        assertEquals("true", main.getAttributeNS(android, "exported"))
        assertEquals(0, main.getElementsByTagName("intent-filter").length)
        val aliases = document.getElementsByTagName("activity-alias")
        assertEquals(AppColor.entries.size, aliases.length)
        for (index in 0 until aliases.length) {
            val alias = aliases.item(index) as org.w3c.dom.Element
            val name = alias.getAttributeNS(android, "name")
            val color = AppColor.entries.single { it.launcherClass == "com.dkaluta.prosary$name" }
            assertEquals(".MainActivity", alias.getAttributeNS(android, "targetActivity"))
            assertEquals((color == AppColor.Blue).toString(), alias.getAttributeNS(android, "enabled"))
            assertEquals("@mipmap/ic_launcher_${color.id}", alias.getAttributeNS(android, "icon"))
            assertEquals("android.intent.category.LAUNCHER",
                (alias.getElementsByTagName("category").item(0) as org.w3c.dom.Element).getAttributeNS(android, "name"))
        }
    }
}
