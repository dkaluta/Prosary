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

    // The Angelus's three versicle/response pairs (Annunciation / Fiat / Incarnation) and its own
    // closing collect — distinct from CollectaStandard (the Rosary's collect) and CollectaPaschale
    // (reused verbatim for the Angelus's Eastertide/Regina Caeli substitution).
    VersiculumAngelusPrimus,
    ResponsiumAngelusPrimus,
    VersiculumAngelusSecundus,
    ResponsiumAngelusSecundus,
    VersiculumAngelusTertius,
    ResponsiumAngelusTertius,
    CollectaAngelus,

    /** The Jesus Prayer ("Lord Jesus Christ, Son of God, have mercy on me, a sinner."). */
    OratioIesu,

    // Stations of the Cross — the versicle/response repeated before each of the 14 stations, plus
    // its own opening and closing prayers. Per-station meditation text lives in
    // StationsTranslations (mirroring how MysteryTranslations holds per-mystery text), not here.
    StationsOpeningPrayer,
    StationsVersicle,
    StationsResponse,
    StationsClosingPrayer,

    // Seven Sorrows (Servite Rosary) — the versicle/response and closing collect prayed after the
    // 3 closing Hail Marys for Our Lady's tears. Unlike the Rosary's Marian antiphon, this closing
    // is fixed, not a user choice (see PrayerEngine). Per-sorrow meditation text lives
    // in MysteryTranslations (reusing the same imageKey-keyed lookup Franciscan Crown's Adoration
    // of the Magi uses), not here.
    SevenSorrowsVersicle,
    SevenSorrowsResponse,
    SevenSorrowsCollect,

    // The Divine Mercy Chaplet — the Our-Father-bead offering, the Hail-Mary-bead petition (each
    // repeated identically across all 5 decades, unlike the Rosary/Franciscan Crown/Seven
    // Sorrows, which vary per decade), and the closing acclamation (repeated 3 times). The
    // opening (Sign of the Cross, Our Father, Hail Mary, Apostles' Creed) reuses existing keys —
    // see PrayerEngine.
    DivineMercyOffering,
    DivineMercyPetition,
    DivineMercyClosingAcclamation,
}
