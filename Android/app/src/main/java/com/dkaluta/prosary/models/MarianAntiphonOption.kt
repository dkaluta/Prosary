package com.dkaluta.prosary.models

import androidx.annotation.StringRes
import com.dkaluta.prosary.R
import android.content.Context
import com.dkaluta.prosary.content.PrayerKey
import com.dkaluta.prosary.content.PrayerTranslations

/** Which closing Marian antiphon (if any) follows the Rosary. */
enum class MarianAntiphonOption {
    None,

    /** Pick the antiphon proper to the current liturgical season automatically. */
    Seasonal,
    SalveRegina,
    AlmaRedemptorisMater,
    AveReginaCaelorum,
    ReginaCaeli,
    SubTuumPraesidium;

    @get:StringRes
    val displayNameRes: Int
        get() = when (this) {
            None -> R.string.antiphon_none
            Seasonal -> R.string.antiphon_seasonal
            SalveRegina -> R.string.antiphon_salve_regina
            AlmaRedemptorisMater -> R.string.antiphon_alma_redemptoris
            AveReginaCaelorum -> R.string.antiphon_ave_regina
            ReginaCaeli -> R.string.antiphon_regina_caeli
            SubTuumPraesidium -> R.string.antiphon_sub_tuum
        }

    fun displayName(context: Context, languageCode: String): String = when (this) {
        None, Seasonal -> context.getString(displayNameRes)
        SalveRegina -> PrayerTranslations.get(languageCode, PrayerKey.SalveReginaTitle)
        AlmaRedemptorisMater -> PrayerTranslations.get(languageCode, PrayerKey.AlmaRedemptorisMaterTitle)
        AveReginaCaelorum -> PrayerTranslations.get(languageCode, PrayerKey.AveReginaCaelorumTitle)
        ReginaCaeli -> PrayerTranslations.get(languageCode, PrayerKey.ReginaCaeliTitle)
        SubTuumPraesidium -> PrayerTranslations.get(languageCode, PrayerKey.SubTuumPraesidiumTitle)
    }
}
