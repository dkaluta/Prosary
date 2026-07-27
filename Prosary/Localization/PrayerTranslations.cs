namespace Prosary.Localization;

/// <summary>
/// Looks up fixed prayer text by <see cref="PrayerKey"/> and language code, falling back to
/// Latin (and then the raw key) when a translation is missing.
/// </summary>
public static partial class PrayerTranslations
{
    private static readonly Dictionary<string, IReadOnlyDictionary<string, string>> ByLanguage;

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

        return Latin.TryGetValue(key, out var latinText) ? latinText : key;
    }
}
