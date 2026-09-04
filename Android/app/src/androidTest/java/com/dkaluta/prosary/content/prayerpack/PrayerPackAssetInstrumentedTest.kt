package com.dkaluta.prosary.content.prayerpack

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/** Exercises the production AssetManager/openFd path inside an installed test APK. This catches
 * a lost `noCompress` rule as well as regressions in non-zero APK asset offsets—neither can be
 * represented faithfully by the host-JVM file fixtures. */
@RunWith(AndroidJUnit4::class)
class PrayerPackAssetInstrumentedTest {
    @Test
    fun everyBuiltInPackIsSeekableAndReadsDirectlyFromItsApkRegion() {
        val assets = InstrumentationRegistry.getInstrumentation().targetContext.assets
        val packNames = listOf(
            "rosary", "angelus", "stationsOfTheCross", "viaLucis", "franciscanCrown",
            "sevenSorrows", "divineMercyChaplet", "trisagion", "oAntiphons",
        )

        for (packName in packNames) {
            val assetName = "$packName.prosaryprayer"
            assets.openFd(assetName).use { descriptor ->
                assertTrue("$assetName must have a bounded stored-asset region", descriptor.length > 0)
            }

            val archive = SeekableZipArchive.fromAsset(assets, assetName)
            val manifest = archive.read("manifest.json", maxBytes = 1024L * 1024L)
            assertNotNull("$assetName must expose manifest.json by central-directory offset", manifest)
            assertTrue(String(requireNotNull(manifest), Charsets.UTF_8).contains("\"id\""))

            val finalImage = archive.entryNames.lastOrNull { it.startsWith("images/") }
            if (finalImage != null) {
                assertTrue(
                    "$assetName must read a late image without scanning earlier entries",
                    requireNotNull(archive.read(finalImage)).isNotEmpty(),
                )
            }
        }
    }
}
