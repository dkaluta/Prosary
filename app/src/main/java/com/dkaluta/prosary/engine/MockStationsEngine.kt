package com.dkaluta.prosary.engine

import com.dkaluta.prosary.content.PrayerKey
import com.dkaluta.prosary.content.PrayerTranslations
import com.dkaluta.prosary.content.StationsTranslations
import com.dkaluta.prosary.models.RosaryStep
import com.dkaluta.prosary.models.StationsCatalog

private val ordinals = listOf(
    "1st", "2nd", "3rd", "4th", "5th", "6th", "7th",
    "8th", "9th", "10th", "11th", "12th", "13th", "14th",
)

/** A fully-working [StationsEngine] used to drive the app today, built on the ported prayer
 * content in [com.dkaluta.prosary.content]. Not necessarily the final production implementation.
 * Unlike the Rosary/Franciscan Crown/Seven Sorrows/Divine Mercy Chaplet, there's no decade/bead
 * math at all — every step leaves `mystery`/`decadeIndex`/`hailMaryIndexInDecade` at their null
 * defaults, same as MockAngelusEngine. */
class MockStationsEngine : StationsEngine {
    override fun buildSteps(languageCode: String?): List<RosaryStep> {
        fun text(key: PrayerKey): String = PrayerTranslations.get(languageCode, key)

        val steps = mutableListOf<RosaryStep>()

        steps.add(RosaryStep(title = "Sign of the Cross", body = text(PrayerKey.SignumCrucis), imageOverrideKey = "crucifix"))
        steps.add(RosaryStep(title = "Opening Prayer", body = text(PrayerKey.StationsOpeningPrayer), imageOverrideKey = "crucifix"))

        for (station in StationsCatalog.all) {
            val stationText = StationsTranslations.get(languageCode, station.imageKey)
            val ordinalLabel = "${ordinals[station.order - 1]} Station"
            val body = "V. ${text(PrayerKey.StationsVersicle)}\nR. ${text(PrayerKey.StationsResponse)}\n\n" +
                stationText.meditation

            steps.add(
                RosaryStep(
                    title = stationText.title,
                    subtitle = ordinalLabel,
                    body = body,
                    imageOverrideKey = station.imageKey,
                ),
            )
        }

        steps.add(RosaryStep(title = "Closing Prayer", body = text(PrayerKey.StationsClosingPrayer), imageOverrideKey = "crucifix"))

        return steps
    }
}
