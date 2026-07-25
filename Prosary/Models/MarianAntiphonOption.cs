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
        MarianAntiphonOption.None => "None",
        MarianAntiphonOption.Seasonal => "Automatic (Seasonal)",
        MarianAntiphonOption.SalveRegina => "Salve Regina",
        MarianAntiphonOption.AlmaRedemptorisMater => "Alma Redemptoris Mater",
        MarianAntiphonOption.AveReginaCaelorum => "Ave Regina Caelorum",
        MarianAntiphonOption.ReginaCaeli => "Regina Caeli",
        MarianAntiphonOption.SubTuumPraesidium => "Sub Tuum Praesidium",
        _ => throw new ArgumentOutOfRangeException(nameof(option))
    };
}
