package com.dkaluta.prosary.ui.shared

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import com.dkaluta.prosary.models.PrayerKind

/** Where tapping a directory entry leads — mapped to navigation lambdas by the caller. */
sealed interface LaunchTarget {
    data object Rosary : LaunchTarget
    data class Custom(val bundleId: String) : LaunchTarget
    data object JesusPrayer : LaunchTarget
}

/** One launchable devotion for the Categories/Search tabs. */
data class DevotionListing(
    val id: String,
    val title: String,
    val icon: ImageVector,
    val accentColor: Color?,
    /** Lowercase category labels from the manifest; the Jesus Prayer, having no bundle,
     * carries its tags here. */
    val tags: List<String>,
    val target: LaunchTarget,
)

/** One flat catalog of every launchable devotion — the Rosary, each loaded bundle, the Jesus
 * Prayer — so the Categories and Search tabs hardcode nothing devotion-specific. Mirrors
 * iOS's DevotionDirectory. */
object DevotionDirectory {
    fun all(): List<DevotionListing> = buildList {
        add(
            DevotionListing(
                id = "rosary",
                title = PrayerKind.Rosary.displayName,
                icon = iconForSystemName("rosary"),
                accentColor = null,
                tags = PrayerPackStore.info("rosary")?.tags ?: listOf("marian"),
                target = LaunchTarget.Rosary,
            ),
        )
        for (bundleId in PrayerPackStore.customDevotionIds()) {
            val info = PrayerPackStore.info(bundleId) ?: continue
            add(
                DevotionListing(
                    id = bundleId,
                    title = info.localizedDisplayName,
                    icon = iconForSystemName(info.iconSystemName),
                    accentColor = colorForHex(info.accentColorHex),
                    tags = info.tags,
                    target = LaunchTarget.Custom(bundleId),
                ),
            )
        }
        add(
            DevotionListing(
                id = "jesusPrayer",
                title = PrayerKind.JesusPrayer.displayName,
                icon = iconForSystemName("jesusPrayer"),
                accentColor = null,
                tags = listOf("eastern", "meditative"),
                target = LaunchTarget.JesusPrayer,
            ),
        )
    }
}
