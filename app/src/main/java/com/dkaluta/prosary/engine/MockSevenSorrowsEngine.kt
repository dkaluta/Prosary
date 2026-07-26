package com.dkaluta.prosary.engine

import com.dkaluta.prosary.content.PrayerKey
import com.dkaluta.prosary.content.PrayerTranslations
import com.dkaluta.prosary.content.MysteryTranslations
import com.dkaluta.prosary.models.SevenSorrowsCatalog
import com.dkaluta.prosary.models.RosaryStep

private val ordinals = listOf("1st", "2nd", "3rd", "4th", "5th", "6th", "7th")

/** A fully-working [SevenSorrowsEngine] used to drive the app today, built on the ported
 * prayer/mystery content in [com.dkaluta.prosary.content]. Not necessarily the final production
 * implementation. Builds the fixed sequence: Sign of the Cross, the Seven Sorrows of Mary (each a
 * decade of an Our Father + 7 Hail Marys — 7, not 10, per traditional practice), 3 additional
 * Hail Marys (for Our Lady's tears), a fixed closing versicle/response/collect (unlike the
 * Rosary/Franciscan Crown, this isn't a user choice — the Seven Sorrows always closes the same
 * way), and a closing Sign of the Cross. */
class MockSevenSorrowsEngine : SevenSorrowsEngine {

    override fun buildSteps(languageCode: String?): List<RosaryStep> {
        fun text(key: PrayerKey): String = PrayerTranslations.get(languageCode, key)

        val steps = mutableListOf<RosaryStep>()

        steps.add(RosaryStep(title = "Sign of the Cross", body = text(PrayerKey.SignumCrucis), imageOverrideKey = "crucifix"))

        val fruitLabel = text(PrayerKey.FructusMysteriiLabel)

        for ((d, imageKey) in SevenSorrowsCatalog.sevenSorrows.withIndex()) {
            val sorrowText = MysteryTranslations.get(languageCode, imageKey)
            val ordinalLabel = "${ordinals[d]} Sorrow"
            val decadeSubtitle = "$ordinalLabel — ${sorrowText.title}"

            steps.add(
                RosaryStep(
                    title = sorrowText.title, subtitle = ordinalLabel,
                    body = "${sorrowText.description}\n\n$fruitLabel: ${sorrowText.fruit}",
                    isScripture = d != SevenSorrowsCatalog.meetingOnTheWayIndex,
                    decadeIndex = d, imageOverrideKey = imageKey,
                ),
            )

            steps.add(
                RosaryStep(
                    title = "Our Father", subtitle = decadeSubtitle, body = text(PrayerKey.PaterNoster),
                    decadeIndex = d, imageOverrideKey = imageKey,
                ),
            )

            for (h in 1..7) {
                steps.add(
                    RosaryStep(
                        title = "Hail Mary ($h of 7)", subtitle = decadeSubtitle, body = text(PrayerKey.AveMaria),
                        decadeIndex = d, hailMaryIndexInDecade = h, imageOverrideKey = imageKey,
                    ),
                )
            }
        }

        for (h in 1..3) {
            steps.add(
                RosaryStep(
                    title = "Hail Mary ($h of 3)", subtitle = "For the tears of Our Lady",
                    body = text(PrayerKey.AveMaria), imageOverrideKey = "madonna_and_child",
                ),
            )
        }

        steps.add(
            RosaryStep(
                title = "Our Lady of Sorrows",
                body = "V. ${text(PrayerKey.SevenSorrowsVersicle)}\nR. ${text(PrayerKey.SevenSorrowsResponse)}\n\n" +
                    text(PrayerKey.SevenSorrowsCollect),
                imageOverrideKey = "madonna_and_child",
            ),
        )

        steps.add(RosaryStep(title = "Sign of the Cross", body = text(PrayerKey.SignumCrucis), imageOverrideKey = "crucifix"))

        return steps
    }
}
