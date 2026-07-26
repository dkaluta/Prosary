using Prosary.Localization;
using Prosary.Models;

namespace Prosary.Services;

/// <summary>Builds the closing Marian antiphon step shared by any devotion that ends with one —
/// the Rosary (RosaryEngine) and the Franciscan Crown (FranciscanCrownEngine) both use this;
/// extracted here rather than duplicated once a second caller needed the exact same
/// style-branching logic. Mirrors iOS's MarianAntiphonBuilder.swift/Android's
/// MarianAntiphonBuilder.kt.</summary>
public static class MarianAntiphonBuilder
{
    private enum Style { Standard, Paschal, Standalone }

    public static RosaryStep BuildStep(MarianAntiphonOption antiphon, string? languageCode)
    {
        string Text(string key) => PrayerTranslations.Get(languageCode, key);

        var (titleKey, style) = antiphon switch
        {
            MarianAntiphonOption.SalveRegina => (PrayerKey.SalveRegina, Style.Standard),
            MarianAntiphonOption.AlmaRedemptorisMater => (PrayerKey.AlmaRedemptorisMater, Style.Standard),
            MarianAntiphonOption.AveReginaCaelorum => (PrayerKey.AveReginaCaelorum, Style.Standard),
            MarianAntiphonOption.ReginaCaeli => (PrayerKey.ReginaCaeli, Style.Paschal),
            MarianAntiphonOption.SubTuumPraesidium => (PrayerKey.SubTuumPraesidium, Style.Standalone),
            _ => (PrayerKey.SalveRegina, Style.Standard)
        };

        // Sub Tuum Praesidium is the Church's oldest known Marian prayer and is traditionally
        // prayed on its own, without the versicle/response/collect used after the four Office antiphons.
        var body = style == Style.Standalone
            ? Text(titleKey)
            : $"{Text(titleKey)}\n\nV. {Text(style == Style.Paschal ? PrayerKey.VersiculumPaschale : PrayerKey.VersiculumStandard)}" +
              $"\nR. {Text(style == Style.Paschal ? PrayerKey.ResponsiumPaschale : PrayerKey.ResponsiumStandard)}" +
              $"\n\n{Text(style == Style.Paschal ? PrayerKey.CollectaPaschale : PrayerKey.CollectaStandard)}";

        return new RosaryStep(GetHeader(antiphon), null, body) with { IsAntiphon = true, ImageOverrideKey = "madonna_and_child" };
    }

    private static string GetHeader(MarianAntiphonOption antiphon) => antiphon switch
    {
        MarianAntiphonOption.SalveRegina => "Hail, Holy Queen (Salve Regina)",
        MarianAntiphonOption.AlmaRedemptorisMater => "Alma Redemptoris Mater",
        MarianAntiphonOption.AveReginaCaelorum => "Ave Regina Caelorum",
        MarianAntiphonOption.ReginaCaeli => "Regina Caeli",
        MarianAntiphonOption.SubTuumPraesidium => "Sub Tuum Praesidium",
        _ => "Marian Antiphon"
    };
}
