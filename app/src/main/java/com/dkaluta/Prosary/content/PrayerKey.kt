package com.dkaluta.Prosary.content

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
}
