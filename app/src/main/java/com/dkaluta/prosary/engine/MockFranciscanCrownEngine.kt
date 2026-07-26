package com.dkaluta.prosary.engine

import com.dkaluta.prosary.calendar.LiturgicalCalendarProviding
import com.dkaluta.prosary.calendar.MockLiturgicalCalendar
import com.dkaluta.prosary.content.PrayerKey
import com.dkaluta.prosary.content.PrayerTranslations
import com.dkaluta.prosary.content.MysteryTranslations
import com.dkaluta.prosary.models.FranciscanCrownCatalog
import com.dkaluta.prosary.models.RosaryStep

private val ordinals = listOf("1st", "2nd", "3rd", "4th", "5th", "6th", "7th")

/** A fully-working [FranciscanCrownEngine] used to drive the app today, built on the ported
 * prayer/mystery content in [com.dkaluta.prosary.content]. Not necessarily the final production
 * implementation. Builds the fixed sequence: Sign of the Cross, the Seven Joys of Mary (each a
 * decade of an Our Father + 10 Hail Marys), 2 additional Hail Marys (for the 72 years
 * traditionally attributed to Our Lady's life) + an Our Father (for the Pope's intentions), the
 * seasonal Marian antiphon, and a closing Sign of the Cross. */
class MockFranciscanCrownEngine(
    private val calendar: LiturgicalCalendarProviding = MockLiturgicalCalendar(),
) : FranciscanCrownEngine {

    override fun buildSteps(languageCode: String?): List<RosaryStep> {
        fun text(key: PrayerKey): String = PrayerTranslations.get(languageCode, key)

        val steps = mutableListOf<RosaryStep>()

        steps.add(RosaryStep(title = "Sign of the Cross", body = text(PrayerKey.SignumCrucis), imageOverrideKey = "crucifix"))

        val fruitLabel = text(PrayerKey.FructusMysteriiLabel)

        for ((d, imageKey) in FranciscanCrownCatalog.sevenJoys.withIndex()) {
            val joyText = MysteryTranslations.get(languageCode, imageKey)
            val ordinalLabel = "${ordinals[d]} Joy"
            val decadeSubtitle = "$ordinalLabel — ${joyText.title}"

            steps.add(
                RosaryStep(
                    title = joyText.title, subtitle = ordinalLabel,
                    body = "${joyText.description}\n\n$fruitLabel: ${joyText.fruit}",
                    isScripture = true, decadeIndex = d, imageOverrideKey = imageKey,
                ),
            )

            steps.add(
                RosaryStep(
                    title = "Our Father", subtitle = decadeSubtitle, body = text(PrayerKey.PaterNoster),
                    decadeIndex = d, imageOverrideKey = imageKey,
                ),
            )

            for (h in 1..10) {
                steps.add(
                    RosaryStep(
                        title = "Hail Mary ($h of 10)", subtitle = decadeSubtitle, body = text(PrayerKey.AveMaria),
                        decadeIndex = d, hailMaryIndexInDecade = h, imageOverrideKey = imageKey,
                    ),
                )
            }
        }

        for (h in 1..2) {
            steps.add(
                RosaryStep(
                    title = "Hail Mary ($h of 2)", subtitle = "For the years of Our Lady's life",
                    body = text(PrayerKey.AveMaria), imageOverrideKey = "madonna_and_child",
                ),
            )
        }

        steps.add(
            RosaryStep(
                title = "Our Father", subtitle = "For the intentions of the Holy Father",
                body = text(PrayerKey.PaterNoster), imageOverrideKey = "our_father",
            ),
        )

        steps.add(MarianAntiphonBuilder.buildStep(calendar.seasonalMarianAntiphonToday(), languageCode))

        steps.add(RosaryStep(title = "Sign of the Cross", body = text(PrayerKey.SignumCrucis), imageOverrideKey = "crucifix"))

        return steps
    }
}
