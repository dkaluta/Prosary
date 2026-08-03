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
    public const string SalveReginaTitle = nameof(SalveReginaTitle);
    public const string AlmaRedemptorisMaterTitle = nameof(AlmaRedemptorisMaterTitle);
    public const string AveReginaCaelorumTitle = nameof(AveReginaCaelorumTitle);
    public const string ReginaCaeliTitle = nameof(ReginaCaeliTitle);
    public const string SubTuumPraesidiumTitle = nameof(SubTuumPraesidiumTitle);

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

    /// <summary>The Jesus Prayer ("Lord Jesus Christ, Son of God, have mercy on me, a sinner.").</summary>
    public const string OratioIesu = nameof(OratioIesu);

    /// <summary>Anima Christi ("Soul of Christ") — traditionally prayed after Communion and at
    /// the close of the Way of the Cross. A shared "main" prayer: hardcoded in every language,
    /// deliberately absent from bundles.</summary>
    public const string AnimaChristi = nameof(AnimaChristi);
}
