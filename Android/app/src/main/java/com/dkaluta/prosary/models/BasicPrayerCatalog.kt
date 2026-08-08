package com.dkaluta.prosary.models

import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import com.dkaluta.prosary.models.RosaryStep

/**
 * The handful of prayers worth praying on their own, outside any devotion — tester-requested
 * (Erez, 2026-08-07): the Sign of the Cross, the Our Father, the Hail Mary, the Glory Be, and
 * the Trisagion's Holy God. Nothing here carries text: each entry names the same keys the
 * devotions already resolve, so a basic prayer reads in the prayer language with every chain the
 * flows use — rites included. Mirrors iOS's BasicPrayerCatalog.swift.
 */
data class BasicPrayer(
    val id: String,
    /** The bundle whose content resolves this prayer's keys. */
    val bundleId: String,
    val titleKey: String,
    val bodyKey: String,
    /** The prayer's traditional illustration — the same override keys the devotions use. */
    val imageKey: String,
)

object BasicPrayerCatalog {
    val all: List<BasicPrayer> = listOf(
        BasicPrayer("signOfCross", "rosary", "signumCrucisTitle", "signumCrucis", "crucifix"),
        BasicPrayer("ourFather", "rosary", "paterNosterTitle", "paterNoster", "our_father"),
        BasicPrayer("hailMary", "rosary", "aveMariaTitle", "aveMaria", "madonna_and_child"),
        BasicPrayer("gloryBe", "rosary", "gloriaPatriTitle", "gloriaPatri", "glory_be"),
        BasicPrayer(
            "holyGod", "trisagion", "trisagionAcclamationTitle", "trisagionAcclamation",
            "jesus_portrait",
        ),
    )

    fun prayer(id: String): BasicPrayer? = all.firstOrNull { it.id == id }

    /** The prayer as one [RosaryStep], in the resolved app-default prayer language — the same
     * step the flows render, so typography, RTL, the ✠ mark and the transliteration toggle all
     * come along without any new machinery. */
    fun step(prayer: BasicPrayer): RosaryStep {
        val language = LanguageCatalog.resolve(null).code
        return RosaryStep(
            title = PrayerPackStore.resolveBodyText(prayer.bundleId, language, prayer.titleKey),
            body = PrayerPackStore.resolveBodyText(prayer.bundleId, language, prayer.bodyKey),
            transliteratedBody = PrayerPackStore.transliteration(prayer.bundleId, language, prayer.bodyKey),
            imageOverrideKey = prayer.imageKey,
        )
    }
}
