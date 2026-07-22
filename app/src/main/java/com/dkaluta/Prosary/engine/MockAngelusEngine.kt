package com.dkaluta.Prosary.engine

import com.dkaluta.Prosary.calendar.LiturgicalCalendarProviding
import com.dkaluta.Prosary.calendar.MockLiturgicalCalendar
import com.dkaluta.Prosary.content.PrayerKey
import com.dkaluta.Prosary.content.PrayerTranslations
import com.dkaluta.Prosary.models.RosaryStep

/** A fully-working [AngelusEngine] used to drive the app today, built on the ported prayer
 * content in [com.dkaluta.Prosary.content]. Not necessarily the final production implementation. */
class MockAngelusEngine(
    private val calendar: LiturgicalCalendarProviding = MockLiturgicalCalendar(),
) : AngelusEngine {

    override fun buildSteps(languageCode: String?): List<RosaryStep> {
        fun text(key: PrayerKey): String = PrayerTranslations.get(languageCode, key)

        if (calendar.isEasterSeasonToday()) {
            // During Eastertide the Angelus is traditionally replaced entirely by the Regina
            // Caeli — same composition (antiphon + versicle/response/collect) MockRosaryEngine
            // already builds for the Rosary's own Paschal closing antiphon.
            val body = "${text(PrayerKey.ReginaCaeli)}\n\nV. ${text(PrayerKey.VersiculumPaschale)}\n" +
                "R. ${text(PrayerKey.ResponsiumPaschale)}\n\n${text(PrayerKey.CollectaPaschale)}"
            return listOf(RosaryStep(title = "Regina Caeli", body = body, imageOverrideKey = "madonna_and_child"))
        }

        return listOf(
            RosaryStep(
                title = "The Annunciation",
                body = "V. ${text(PrayerKey.VersiculumAngelusPrimus)}\nR. ${text(PrayerKey.ResponsiumAngelusPrimus)}",
                imageOverrideKey = "joyful_01_annunciation",
            ),
            RosaryStep(title = "Hail Mary", body = text(PrayerKey.AveMaria), imageOverrideKey = "joyful_01_annunciation"),

            RosaryStep(
                title = "The Fiat",
                body = "V. ${text(PrayerKey.VersiculumAngelusSecundus)}\nR. ${text(PrayerKey.ResponsiumAngelusSecundus)}",
                imageOverrideKey = "joyful_01_annunciation",
            ),
            RosaryStep(title = "Hail Mary", body = text(PrayerKey.AveMaria), imageOverrideKey = "joyful_01_annunciation"),

            RosaryStep(
                title = "The Incarnation",
                body = "V. ${text(PrayerKey.VersiculumAngelusTertius)}\nR. ${text(PrayerKey.ResponsiumAngelusTertius)}",
                imageOverrideKey = "joyful_01_annunciation",
            ),
            RosaryStep(title = "Hail Mary", body = text(PrayerKey.AveMaria), imageOverrideKey = "joyful_01_annunciation"),

            RosaryStep(
                title = "Let Us Pray",
                body = "V. ${text(PrayerKey.VersiculumStandard)}\nR. ${text(PrayerKey.ResponsiumStandard)}\n\n" +
                    text(PrayerKey.CollectaAngelus),
                imageOverrideKey = "joyful_01_annunciation",
            ),
        )
    }
}
