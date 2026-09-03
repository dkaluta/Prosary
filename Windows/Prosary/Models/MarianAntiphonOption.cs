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

public sealed record MarianAntiphonChoice(MarianAntiphonOption Value, string Label);

public static class MarianAntiphonOptionExtensions
{
    public static IReadOnlyList<MarianAntiphonChoice> Choices(string? languageCode)
    {
        var resolved = LanguageCatalog.Resolve(languageCode).Code;
        return Enum.GetValues<MarianAntiphonOption>()
            .Select(option => new MarianAntiphonChoice(option, option.DisplayName(resolved)))
            .ToList();
    }

    public static string DisplayName(this MarianAntiphonOption option) => option.DisplayName(AppSettings.DefaultLanguageCode);

    public static string DisplayName(this MarianAntiphonOption option, string languageCode) => option switch
    {
        MarianAntiphonOption.None => Loc.Tr("antiphon_none", "None"),
        MarianAntiphonOption.Seasonal => Loc.Tr("antiphon_seasonal", "Automatic (Seasonal)"),
        MarianAntiphonOption.SalveRegina => PrayerTranslations.GetDisplay(languageCode, PrayerKey.SalveReginaTitle),
        MarianAntiphonOption.AlmaRedemptorisMater => PrayerTranslations.GetDisplay(languageCode, PrayerKey.AlmaRedemptorisMaterTitle),
        MarianAntiphonOption.AveReginaCaelorum => PrayerTranslations.GetDisplay(languageCode, PrayerKey.AveReginaCaelorumTitle),
        MarianAntiphonOption.ReginaCaeli => PrayerTranslations.GetDisplay(languageCode, PrayerKey.ReginaCaeliTitle),
        MarianAntiphonOption.SubTuumPraesidium => PrayerTranslations.GetDisplay(languageCode, PrayerKey.SubTuumPraesidiumTitle),
        _ => throw new ArgumentOutOfRangeException(nameof(option))
    };
}
