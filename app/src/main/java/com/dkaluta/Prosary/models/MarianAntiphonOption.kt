package com.dkaluta.Prosary.models

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

    val displayName: String
        get() = when (this) {
            None -> "None"
            Seasonal -> "Automatic (Seasonal)"
            SalveRegina -> "Salve Regina"
            AlmaRedemptorisMater -> "Alma Redemptoris Mater"
            AveReginaCaelorum -> "Ave Regina Caelorum"
            ReginaCaeli -> "Regina Caeli"
            SubTuumPraesidium -> "Sub Tuum Praesidium"
        }
}
