package com.dkaluta.prosary.engine

import com.dkaluta.prosary.content.PrayerKey
import com.dkaluta.prosary.content.PrayerTranslations
import com.dkaluta.prosary.models.MarianAntiphonOption
import com.dkaluta.prosary.models.RosaryStep

/** Builds the closing Marian antiphon step shared by any devotion that ends with one — the
 * Rosary (MockRosaryEngine) and the Franciscan Crown (MockFranciscanCrownEngine) both use this;
 * extracted here rather than duplicated once a second caller needed the exact same
 * style-branching logic. Mirrors iOS's MarianAntiphonBuilder.swift. */
object MarianAntiphonBuilder {
    private enum class Style { Standard, Paschal, Standalone }

    fun buildStep(antiphon: MarianAntiphonOption, languageCode: String?): RosaryStep {
        fun text(key: PrayerKey): String = PrayerTranslations.get(languageCode, key)

        val (titleKey, style) = when (antiphon) {
            MarianAntiphonOption.SalveRegina -> PrayerKey.SalveRegina to Style.Standard
            MarianAntiphonOption.AlmaRedemptorisMater -> PrayerKey.AlmaRedemptorisMater to Style.Standard
            MarianAntiphonOption.AveReginaCaelorum -> PrayerKey.AveReginaCaelorum to Style.Standard
            MarianAntiphonOption.ReginaCaeli -> PrayerKey.ReginaCaeli to Style.Paschal
            // Sub Tuum Praesidium is the Church's oldest known Marian prayer and is traditionally
            // prayed on its own, without the versicle/response/collect used after the four Office antiphons.
            MarianAntiphonOption.SubTuumPraesidium -> PrayerKey.SubTuumPraesidium to Style.Standalone
            MarianAntiphonOption.None, MarianAntiphonOption.Seasonal -> PrayerKey.SalveRegina to Style.Standard
        }

        val body = when (style) {
            Style.Standalone -> text(titleKey)
            Style.Standard ->
                "${text(titleKey)}\n\nV. ${text(PrayerKey.VersiculumStandard)}\nR. ${text(PrayerKey.ResponsiumStandard)}\n\n" +
                    text(PrayerKey.CollectaStandard)
            Style.Paschal ->
                "${text(titleKey)}\n\nV. ${text(PrayerKey.VersiculumPaschale)}\nR. ${text(PrayerKey.ResponsiumPaschale)}\n\n" +
                    text(PrayerKey.CollectaPaschale)
        }

        val step = RosaryStep(title = header(antiphon), body = body)
        step.isAntiphon = true
        step.imageOverrideKey = "madonna_and_child"
        return step
    }

    private fun header(antiphon: MarianAntiphonOption): String = when (antiphon) {
        MarianAntiphonOption.SalveRegina -> "Salve Regina"
        MarianAntiphonOption.AlmaRedemptorisMater -> "Alma Redemptoris Mater"
        MarianAntiphonOption.AveReginaCaelorum -> "Ave Regina Caelorum"
        MarianAntiphonOption.ReginaCaeli -> "Regina Caeli"
        MarianAntiphonOption.SubTuumPraesidium -> "Sub Tuum Praesidium"
        MarianAntiphonOption.None, MarianAntiphonOption.Seasonal -> "Marian Antiphon"
    }
}
