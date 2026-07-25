namespace Prosary.Models;

public enum MarianAntiphonOption
{
    None,

    /// <summary>Pick the antiphon proper to the current liturgical season automatically.</summary>
    Seasonal,

    SalveRegina,
    AlmaRedemptorisMater,
    AveReginaCaelorum,
    ReginaCaeli,

    /// <summary>Added last to preserve the existing integer values stored in saved presets.</summary>
    SubTuumPraesidium
}
