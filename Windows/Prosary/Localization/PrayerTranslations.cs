namespace Prosary.Localization;

/// <summary>
/// Looks up fixed prayer text by <see cref="PrayerKey"/> and language code, falling back to
/// Latin (and then the raw key) when a translation is missing.
/// </summary>
public static partial class PrayerTranslations
{
    // internal (not private) so Prosary.Tests can verify per-language completeness directly —
    // see PrayerTranslationsCompletenessTests.cs. Relies on the [InternalsVisibleTo] declared in
    // Properties/AssemblyInfo.cs.
    internal static readonly Dictionary<string, IReadOnlyDictionary<string, string>> ByLanguage;

    // Static field initializers across the partial-class files (one per language) run in an
    // unspecified order relative to each other. An explicit static constructor is guaranteed to
    // run only after ALL of them have completed, so building ByLanguage here (rather than as a
    // field initializer) avoids capturing a still-null dictionary from a sibling file.
    static PrayerTranslations()
    {
        ByLanguage = new Dictionary<string, IReadOnlyDictionary<string, string>>
        {
            ["la"] = Latin,
            ["en"] = English,
            ["ar"] = Arabic,
            ["he"] = Hebrew,
            // The Mission of St. Gamaliel's wording, overlaying plain Hebrew key by key.
            ["he-x-gamliel"] = HebrewGamaliel,
            ["ru"] = Russian,
            ["tl"] = Tagalog,
        };
    }

    public static string Get(string? languageCode, string key)
    {
        if (languageCode is not null)
        {
            var packOverride = PrayerPackStore.PrayerOverride(languageCode, key);
            if (packOverride is not null) return packOverride;
        }

        if (languageCode is not null && ByLanguage.TryGetValue(languageCode, out var table) &&
            table.TryGetValue(key, out var text))
        {
            return text;
        }

        // Community variants ("he-x-gamliel") overlay their base language before Latin.
        if (languageCode is not null && Prosary.Models.LanguageCatalog.BaseLanguage(languageCode) is { } baseCode)
        {
            var baseOverride = PrayerPackStore.PrayerOverride(baseCode, key);
            if (baseOverride is not null) return baseOverride;
            if (ByLanguage.TryGetValue(baseCode, out var baseTable) && baseTable.TryGetValue(key, out var baseText))
            {
                return baseText;
            }
        }

        // Pack-provided Latin before the hardcoded Latin table — some texts (the converted
        // devotions' bundle-local keys) live only in their bundles.
        return PrayerPackStore.PrayerOverride("la", key)
            ?? (Latin.TryGetValue(key, out var latinText) ? latinText : key);
    }
}
