package com.dkaluta.prosary.engine

import com.dkaluta.prosary.content.PrayerKey
import com.dkaluta.prosary.content.PrayerTranslations
import com.dkaluta.prosary.models.RosaryStep

private val ordinals = listOf("1st", "2nd", "3rd", "4th", "5th")
private const val imageKey = "divine_mercy_image"

/** A fully-working [DivineMercyEngine] used to drive the app today, built on the ported prayer
 * content in [com.dkaluta.prosary.content]. Not necessarily the final production implementation.
 * Builds the fixed sequence: Sign of the Cross, Our Father, Hail Mary, the Apostles' Creed (the
 * traditional opening, reusing existing PrayerKeys — nothing new needed there), 5 decades each of
 * one offering ("Eternal Father, I offer You...") at the Our-Father-bead position and 10
 * petitions ("For the sake of His sorrowful Passion...") at the Hail-Mary-bead positions — the
 * same two lines every decade, unlike the Rosary/Franciscan Crown/Seven Sorrows — closing with
 * the acclamation ("Holy God, Holy Mighty One, Holy Immortal One...") prayed three times, and a
 * closing Sign of the Cross. Every step reuses the single divine_mercy_image illustration, the
 * same reuse pattern the Angelus uses for joyful_01_annunciation. */
class MockDivineMercyEngine : DivineMercyEngine {

    override fun buildSteps(languageCode: String?): List<RosaryStep> {
        fun text(key: PrayerKey): String = PrayerTranslations.get(languageCode, key)

        val steps = mutableListOf<RosaryStep>()

        steps.add(RosaryStep(title = "Sign of the Cross", body = text(PrayerKey.SignumCrucis), imageOverrideKey = imageKey))
        steps.add(RosaryStep(title = "Our Father", body = text(PrayerKey.PaterNoster), imageOverrideKey = imageKey))
        steps.add(RosaryStep(title = "Hail Mary", body = text(PrayerKey.AveMaria), imageOverrideKey = imageKey))
        steps.add(RosaryStep(title = "The Apostles' Creed", body = text(PrayerKey.SymbolumApostolorum), imageOverrideKey = imageKey))

        for (d in 0 until 5) {
            val decadeSubtitle = "${ordinals[d]} Decade"

            steps.add(
                RosaryStep(
                    title = "Eternal Father, I Offer You...", subtitle = decadeSubtitle, body = text(PrayerKey.DivineMercyOffering),
                    decadeIndex = d, imageOverrideKey = imageKey,
                ),
            )

            for (h in 1..10) {
                steps.add(
                    RosaryStep(
                        title = "For the Sake of His Sorrowful Passion ($h of 10)", subtitle = decadeSubtitle,
                        body = text(PrayerKey.DivineMercyPetition), decadeIndex = d, hailMaryIndexInDecade = h, imageOverrideKey = imageKey,
                    ),
                )
            }
        }

        for (h in 1..3) {
            steps.add(
                RosaryStep(
                    title = "Holy God, Holy Mighty One, Holy Immortal One ($h of 3)",
                    body = text(PrayerKey.DivineMercyClosingAcclamation), imageOverrideKey = imageKey,
                ),
            )
        }

        steps.add(RosaryStep(title = "Sign of the Cross", body = text(PrayerKey.SignumCrucis), imageOverrideKey = imageKey))

        return steps
    }
}
