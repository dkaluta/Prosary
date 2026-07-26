namespace Prosary.Localization;

/// <summary>
/// Stable, language-independent identifiers for each fixed prayer text. Named in Latin
/// since Latin is the app's canonical/default prayer language.
/// </summary>
public static class PrayerKey
{
    public const string SignumCrucis = nameof(SignumCrucis);
    public const string SymbolumApostolorum = nameof(SymbolumApostolorum);
    public const string PaterNoster = nameof(PaterNoster);
    public const string AveMaria = nameof(AveMaria);
    public const string GloriaPatri = nameof(GloriaPatri);

    /// <summary>"For thine is the kingdom..." — not currently used in the Rosary flow itself;
    /// stored for future use (e.g. Mass responses, other prayers).</summary>
    public const string DoxologiaMinor = nameof(DoxologiaMinor);

    public const string OratioFatimae = nameof(OratioFatimae);
    public const string RequiemAeternam = nameof(RequiemAeternam);
    public const string SanctusMichael = nameof(SanctusMichael);

    public const string SalveRegina = nameof(SalveRegina);
    public const string AlmaRedemptorisMater = nameof(AlmaRedemptorisMater);
    public const string AveReginaCaelorum = nameof(AveReginaCaelorum);
    public const string ReginaCaeli = nameof(ReginaCaeli);

    /// <summary>The oldest known Marian prayer; traditionally recited on its own, without a versicle/collect.</summary>
    public const string SubTuumPraesidium = nameof(SubTuumPraesidium);

    public const string VersiculumStandard = nameof(VersiculumStandard);
    public const string ResponsiumStandard = nameof(ResponsiumStandard);
    public const string CollectaStandard = nameof(CollectaStandard);
    public const string VersiculumPaschale = nameof(VersiculumPaschale);
    public const string ResponsiumPaschale = nameof(ResponsiumPaschale);
    public const string CollectaPaschale = nameof(CollectaPaschale);

    /// <summary>The opening Hail Mary said for an increase of Faith.</summary>
    public const string AveMariaProFide = nameof(AveMariaProFide);

    /// <summary>The opening Hail Mary said for an increase of Hope.</summary>
    public const string AveMariaProSpe = nameof(AveMariaProSpe);

    /// <summary>The opening Hail Mary said for an increase of Charity.</summary>
    public const string AveMariaProCaritate = nameof(AveMariaProCaritate);

    public const string FructusMysteriiLabel = nameof(FructusMysteriiLabel);

    // The Angelus's three versicle/response pairs (Annunciation / Fiat / Incarnation) and its own
    // closing collect — distinct from CollectaStandard (the Rosary's collect) and
    // CollectaPaschale (reused verbatim for the Angelus's Eastertide/Regina Caeli substitution).
    public const string VersiculumAngelusPrimus = nameof(VersiculumAngelusPrimus);
    public const string ResponsiumAngelusPrimus = nameof(ResponsiumAngelusPrimus);
    public const string VersiculumAngelusSecundus = nameof(VersiculumAngelusSecundus);
    public const string ResponsiumAngelusSecundus = nameof(ResponsiumAngelusSecundus);
    public const string VersiculumAngelusTertius = nameof(VersiculumAngelusTertius);
    public const string ResponsiumAngelusTertius = nameof(ResponsiumAngelusTertius);
    public const string CollectaAngelus = nameof(CollectaAngelus);

    /// <summary>The Jesus Prayer ("Lord Jesus Christ, Son of God, have mercy on me, a sinner.").</summary>
    public const string OratioIesu = nameof(OratioIesu);

    // Stations of the Cross — the versicle/response repeated before each of the 14 stations, plus
    // its own opening and closing prayers. Per-station meditation text lives in
    // StationsTranslations (mirroring how MysteryTranslations holds per-mystery text), not here.
    public const string StationsOpeningPrayer = nameof(StationsOpeningPrayer);
    public const string StationsVersicle = nameof(StationsVersicle);
    public const string StationsResponse = nameof(StationsResponse);
    public const string StationsClosingPrayer = nameof(StationsClosingPrayer);

    // Seven Sorrows (Servite Rosary) — the versicle/response and closing collect prayed after the
    // 3 closing Hail Marys for Our Lady's tears. Unlike the Rosary's Marian antiphon, this closing
    // is fixed, not a user choice (see SevenSorrowsEngine). Per-sorrow meditation text lives in
    // MysteryTranslations (reusing the same imageKey-keyed lookup Franciscan Crown's Adoration of
    // the Magi uses), not here.
    public const string SevenSorrowsVersicle = nameof(SevenSorrowsVersicle);
    public const string SevenSorrowsResponse = nameof(SevenSorrowsResponse);
    public const string SevenSorrowsCollect = nameof(SevenSorrowsCollect);

    // The Divine Mercy Chaplet — the Our-Father-bead offering, the Hail-Mary-bead petition (each
    // repeated identically across all 5 decades, unlike the Rosary/Franciscan Crown/Seven
    // Sorrows, which vary per decade), and the closing acclamation (repeated 3 times). The
    // opening (Sign of the Cross, Our Father, Hail Mary, Apostles' Creed) reuses existing keys —
    // see DivineMercyEngine.
    public const string DivineMercyOffering = nameof(DivineMercyOffering);
    public const string DivineMercyPetition = nameof(DivineMercyPetition);
    public const string DivineMercyClosingAcclamation = nameof(DivineMercyClosingAcclamation);
}
