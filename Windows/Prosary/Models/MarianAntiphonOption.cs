using Prosary.Localization;

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

public static class MarianAntiphonOptionExtensions
{
    public static string DisplayName(this MarianAntiphonOption option) => option switch
    {
        MarianAntiphonOption.None => Loc.Tr("antiphon_none", "None"),
        MarianAntiphonOption.Seasonal => Loc.Tr("antiphon_seasonal", "Automatic (Seasonal)"),
        MarianAntiphonOption.SalveRegina => Loc.Tr("antiphon_salve_regina", "Salve Regina"),
        MarianAntiphonOption.AlmaRedemptorisMater => Loc.Tr("antiphon_alma_redemptoris", "Alma Redemptoris Mater"),
        MarianAntiphonOption.AveReginaCaelorum => Loc.Tr("antiphon_ave_regina", "Ave Regina Caelorum"),
        MarianAntiphonOption.ReginaCaeli => Loc.Tr("antiphon_regina_caeli", "Regina Caeli"),
        MarianAntiphonOption.SubTuumPraesidium => Loc.Tr("antiphon_sub_tuum", "Sub Tuum Praesidium"),
        _ => throw new ArgumentOutOfRangeException(nameof(option))
    };
}
