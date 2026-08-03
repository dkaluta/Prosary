package com.dkaluta.prosary.content

/** Stable, language-independent identifiers for each fixed prayer text. */
enum class PrayerKey {
    SignumCrucis,
    SymbolumApostolorum,
    PaterNoster,
    AveMaria,
    GloriaPatri,

    /** "For thine is the kingdom..." — not currently used in the Rosary flow itself; kept for future use. */
    DoxologiaMinor,

    OratioFatimae,
    RequiemAeternam,
    SanctusMichael,

    SalveRegina,
    AlmaRedemptorisMater,
    AveReginaCaelorum,
    ReginaCaeli,

    /** The oldest known Marian prayer; traditionally recited on its own, without a versicle/collect. */
    SubTuumPraesidium,
    SalveReginaTitle,
    AlmaRedemptorisMaterTitle,
    AveReginaCaelorumTitle,
    ReginaCaeliTitle,
    SubTuumPraesidiumTitle,

    VersiculumStandard,
    ResponsiumStandard,
    CollectaStandard,
    VersiculumPaschale,
    ResponsiumPaschale,
    CollectaPaschale,

    /** The opening Hail Mary said for an increase of Faith. */
    AveMariaProFide,

    /** The opening Hail Mary said for an increase of Hope. */
    AveMariaProSpe,

    /** The opening Hail Mary said for an increase of Charity. */
    AveMariaProCaritate,

    FructusMysteriiLabel,

    /** The Jesus Prayer ("Lord Jesus Christ, Son of God, have mercy on me, a sinner."). */
    OratioIesu,

    /** Anima Christi ("Soul of Christ") — traditionally prayed after Communion and at the close
     * of the Way of the Cross. A shared "main" prayer: hardcoded in every language, deliberately
     * absent from bundles. */
    AnimaChristi,
}
