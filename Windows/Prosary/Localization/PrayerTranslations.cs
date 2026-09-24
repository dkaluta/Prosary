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

    public static string FlowTitle(string title, string? languageCode, bool sourceScript, string bundleId = "rosary")
    {
        var unpointed = HebrewDisplayText.WithoutMarks(title);
        if (Models.LanguageCatalog.FallbackChain(languageCode).FirstOrDefault() != "arc") return unpointed;
        var pairs = PrayerPackStore.AramaicTitlePairs(bundleId).ToArray();
        var definition = PrayerPackStore.Definition(bundleId);
        var ordinalKeys = new[] { definition?.Decades?.OrdinalNounKey }
            .Concat(definition?.Variants?.Select(variant => variant.Decades?.OrdinalNounKey) ?? []);
        var ordinalNouns = ordinalKeys.OfType<string>().SelectMany(key => new[]
            { PrayerPackStore.ResolveBodyText(bundleId, "arc", key), PrayerPackStore.Transliteration(bundleId, "arc", key) })
            .OfType<string>().Select(HebrewDisplayText.WithoutMarks).ToHashSet(StringComparer.Ordinal);
        if (unpointed.Contains(" — ", StringComparison.Ordinal))
        {
            var parts = unpointed.Split(" — ");
            bool IsPaired(string value) => pairs.Any(pair =>
                HebrewDisplayText.WithoutMarks(pair.Item1) == value || HebrewDisplayText.WithoutMarks(pair.Item2) == value);
            // Recognize the authored ordinal/mystery caption, preserving personal dash titles.
            if (parts.Length is < 2 or > 3) return unpointed;
            bool IsOrdinal(string value)
            {
                var suffix = System.Text.RegularExpressions.Regex.Match(value, @" \d+$");
                return suffix.Success && ordinalNouns.Contains(value[..suffix.Index]);
            }
            var ordinalIndex = IsOrdinal(parts[^1]) ? parts.Length - 1 : parts.Length - 2;
            if (!IsOrdinal(parts[ordinalIndex]) || (ordinalIndex != parts.Length - 1 && !IsPaired(parts[^1]))) return unpointed;
            return string.Join(" — ", parts.Select(part => FlowTitle(part, languageCode, sourceScript, bundleId)));
        }
        var desiredScript = sourceScript ? Services.PrayerTypography.Script.Syriac : Services.PrayerTypography.Script.Hebrew;
        foreach (var (text, readingAid) in pairs)
        {
            var primary = HebrewDisplayText.WithoutMarks(text);
            var alternate = HebrewDisplayText.WithoutMarks(readingAid);
            var primaryScript = Services.PrayerTypography.ScriptOf(primary);
            var alternateScript = Services.PrayerTypography.ScriptOf(alternate);
            if (!((primaryScript == Services.PrayerTypography.Script.Hebrew && alternateScript == Services.PrayerTypography.Script.Syriac)
                || (primaryScript == Services.PrayerTypography.Script.Syriac && alternateScript == Services.PrayerTypography.Script.Hebrew))) continue;
            foreach (var candidate in new[] { primary, alternate })
            {
                if (!unpointed.StartsWith(candidate, StringComparison.Ordinal)) continue;
                var suffix = unpointed[candidate.Length..];
                if (suffix.Length != 0 && !IsAramaicTitleCounter(suffix)
                    && !(ordinalNouns.Contains(candidate)
                        && System.Text.RegularExpressions.Regex.IsMatch(suffix, @"^ \d+$"))) continue;
                var heading = primaryScript == desiredScript ? primary : alternate;
                return heading + AramaicTitleSuffix(suffix, sourceScript);
            }
        }
        return AramaicTitleSuffix(unpointed, sourceScript);
    }

    private static bool IsAramaicTitleCounter(string suffix)
    {
        var hebrew = HebrewDisplayText.WithoutMarks(Get("arc", PrayerKey.RepetitionCounterConnector));
        var syriac = PrayerPackStore.Transliteration("rosary", "arc", "repetitionCounterConnector");
        var connectors = System.Text.RegularExpressions.Regex.Escape(hebrew)
            + (syriac is null ? "" : "|" + System.Text.RegularExpressions.Regex.Escape(syriac));
        return System.Text.RegularExpressions.Regex.IsMatch(suffix, @"^ \(\d+ (?:" + connectors + @") \d+\)$");
    }

    private static string AramaicTitleSuffix(string suffix, bool sourceScript)
    {
        var hebrew = HebrewDisplayText.WithoutMarks(Get("arc", PrayerKey.RepetitionCounterConnector));
        var syriac = PrayerPackStore.Transliteration("rosary", "arc", "repetitionCounterConnector");
        if (syriac is null) return suffix;
        var original = sourceScript ? hebrew : syriac;
        var replacement = sourceScript ? syriac : hebrew;
        var pattern = @"(\(\d+) " + System.Text.RegularExpressions.Regex.Escape(original) + @" (\d+\))$";
        return System.Text.RegularExpressions.Regex.Replace(suffix, pattern, "$1 " + replacement + " $2");
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
        foreach (var code in Prosary.Models.LanguageCatalog.ContentFallbackChain(languageCode))
        {
            var packOverride = PrayerPackStore.PrayerOverride(code, key);
            if (packOverride is not null) return VicariatePrayerWording.Apply(packOverride, code);
            if (NativeTextAtProbe(code, key) is { } text) return VicariatePrayerWording.Apply(text, code);
        }

        // Pack-provided Latin before the hardcoded Latin table — some texts (the converted
        // devotions' bundle-local keys) live only in their bundles.
        return PrayerPackStore.PrayerOverride("la", key)
            ?? (Latin.TryGetValue(key, out var latinText) ? latinText : key);
    }

    private static bool IsGenericHebrewKey(string key) => key is
        PrayerKey.DecadeOrdinalFormat or PrayerKey.RepetitionCounterConnector or PrayerKey.FructusMysteriiLabel;

    /// <summary>The printed Vicariate prayers keep their own content bucket; editorial Hebrew
    /// vocabulary remains shared. ByLanguage retains its public catalog/completeness shape.</summary>
    internal static string? NativeTextAtProbe(string code, string key)
    {
        if (code == Models.LanguageCatalog.VicariateContentCode)
            return !IsGenericHebrewKey(key) ? Hebrew.GetValueOrDefault(key) : null;
        if (code == "he" && !IsGenericHebrewKey(key)) return null;
        return ByLanguage.GetValueOrDefault(code)?.GetValueOrDefault(key);
    }

    /// <summary>A title/label lookup for presentation chrome. The canonical table stays fully
    /// pointed so the same key can still be used as prayer text where a bundle requires it.</summary>
    public static string GetDisplay(string? languageCode, string key) =>
        HebrewDisplayText.WithoutMarks(Get(languageCode, key));
}
