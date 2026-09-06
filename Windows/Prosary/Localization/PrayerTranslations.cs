namespace Prosary.Localization;

/// <summary>
/// Looks up fixed prayer text by <see cref="PrayerKey"/> and language code, falling back to
/// Latin (and then the raw key) when a translation is missing.
/// </summary>
public static partial class PrayerTranslations
{
    public static bool? InitialTransliteration(string? languageCode, string body, string? alternate, string? script = null)
    {
        if (Models.LanguageCatalog.FallbackChain(languageCode).FirstOrDefault() != "arc") return null;
        var desired = (script ?? Models.AppSettings.AramaicDefaultScript) == "Syrc"
            ? Services.PrayerTypography.Script.Syriac : Services.PrayerTypography.Script.Hebrew;
        if (Services.PrayerTypography.ScriptOf(body) == desired || alternate is null) return false;
        return Services.PrayerTypography.ScriptOf(alternate) == desired;
    }

    public static string? AramaicProgress(int index, int total, string? languageCode, bool sourceScript)
    {
        if (Models.LanguageCatalog.FallbackChain(languageCode).FirstOrDefault() != "arc") return null;
        var connector = sourceScript ? PrayerPackStore.Transliteration("rosary", "arc", "repetitionCounterConnector") : null;
        return $"{index} {connector ?? Get("arc", PrayerKey.RepetitionCounterConnector)} {total}";
    }

    public static string FlowTitle(string title, string? languageCode, bool sourceScript)
    {
        var unpointed = HebrewDisplayText.WithoutMarks(title);
        if (!sourceScript || Models.LanguageCatalog.FallbackChain(languageCode).FirstOrDefault() != "arc") return unpointed;
        var connector = PrayerPackStore.Transliteration("rosary", "arc", "repetitionCounterConnector");
        if (connector is null) return unpointed;
        var original = HebrewDisplayText.WithoutMarks(Get("arc", PrayerKey.RepetitionCounterConnector));
        var pattern = @"(\(\d+) " + System.Text.RegularExpressions.Regex.Escape(original) + @" (\d+\))$";
        return System.Text.RegularExpressions.Regex.Replace(unpointed, pattern, "$1 " + connector + " $2");
    }

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
            ["el"] = Greek,
            ["es"] = Spanish,
            ["ru"] = Russian,
            ["tl"] = Tagalog,
        };
    }

    public static string Get(string? languageCode, string key)
    {
        foreach (var code in Prosary.Models.LanguageCatalog.FallbackChain(languageCode))
        {
            var packOverride = PrayerPackStore.PrayerOverride(code, key);
            if (packOverride is not null) return packOverride;
            if (ByLanguage.TryGetValue(code, out var table) && table.TryGetValue(key, out var text)) return text;
        }

        // Pack-provided Latin before the hardcoded Latin table — some texts (the converted
        // devotions' bundle-local keys) live only in their bundles.
        return PrayerPackStore.PrayerOverride("la", key)
            ?? (Latin.TryGetValue(key, out var latinText) ? latinText : key);
    }

    /// <summary>A title/label lookup for presentation chrome. The canonical table stays fully
    /// pointed so the same key can still be used as prayer text where a bundle requires it.</summary>
    public static string GetDisplay(string? languageCode, string key) =>
        HebrewDisplayText.WithoutMarks(Get(languageCode, key));
}
