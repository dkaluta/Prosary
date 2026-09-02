namespace Prosary.Models;

/// <summary>A prayer language the app can display, independent of the device's own UI/system
/// language.</summary>
/// <param name="Code">Prayer-language identifier used as the key into the content layer's
/// translations.</param>
/// <param name="NativeName">The language's own name, in its own script (shown in pickers).</param>
/// <param name="IsRightToLeft">Whether prayer text in this language should be displayed
/// right-to-left.</param>
public sealed record LanguageOption(string Code, string NativeName, bool IsRightToLeft);

/// <summary>Languages available for prayer text. Latin is the default — it's the neutral fallback
/// every lookup falls back to if a translation is missing in the chosen language.</summary>
public static class LanguageCatalog
{
    /// <summary>"he-x-gamliel" → "he": community variants overlay their base language — the
    /// resolve chains try the exact code first, then this. Null when there is no subtag.</summary>
    public static string? BaseLanguage(string code)
    {
        var dash = code.IndexOf('-');
        return dash > 0 ? code[..dash] : null;
    }

    public const string DefaultCode = "la";

    /// <summary>Sentinel stored in a favorite's LanguageCode meaning "follow the app-level default
    /// setting" (see <see cref="AppSettings.DefaultLanguageCode"/>).</summary>
    public const string DefaultSentinel = "";

    public static readonly IReadOnlyList<LanguageOption> All =
    [
        new("la", "Latina", false),
        new("en", "English", false),
        new("ar", "العربية", true),
        new("he", "עברית — נוסח הנציגות", true),
        new("he-x-gamliel", "עברית — נוסח השליחות", true),
        // Aramaic in Hebrew script — the Aramaic-rite communities' liturgical language.
        new("arc", "ארמית", true),
        // Greek: the language a great deal of the app's own Scripture and prayer was first
        // written in — the Creed, the Sub Tuum, the Jesus Prayer.
        new("el", "Ἑλληνικά", false),
        new("es", "Español", false),
        new("ru", "Русский", false),
        new("tl", "Tagalog", false),
    ];

    /// <summary>Picker choices for a bundle's declared languages. The Mission is a sparse
    /// overlay rather than a manifest language of its own, so every bundle offering Hebrew
    /// exposes both sourced Hebrew uses as adjacent, independent choices.</summary>
    public static IReadOnlyList<LanguageOption> AvailableOptions(IEnumerable<string> declaredCodes)
    {
        var available = declaredCodes
            .SelectMany(code => code == "he" ? new[] { "he", "he-x-gamliel" } : new[] { code })
            .ToHashSet();
        return All.Where(language => available.Contains(language.Code)).ToList();
    }

    public static IReadOnlyList<string> FallbackOrder
    {
        get
        {
            var known = All.Select(l => l.Code).ToHashSet();
            var result = AppSettings.LanguageFallbackOrder.Where(known.Contains).Distinct().ToList();
            var defaults = All.Select(l => l.Code).Where(c => c != DefaultCode).Append(DefaultCode);
            result.AddRange(defaults.Where(c => !result.Contains(c)));
            return result;
        }
    }

    public static IReadOnlyList<string> FallbackChain(string? requested)
    {
        var result = new List<string>();
        void Append(string? code)
        {
            if (string.IsNullOrEmpty(code) || result.Contains(code)) return;
            result.Add(code);
            if (BaseLanguage(code) is { } baseCode && !result.Contains(baseCode)) result.Add(baseCode);
        }
        Append(string.IsNullOrEmpty(requested) ? AppSettings.DefaultLanguageCode : requested);
        foreach (var code in FallbackOrder) Append(code);
        Append(DefaultCode);
        return result;
    }

    /// <summary>Legacy grouping metadata for the two Hebrew community uses. Pickers expose them
    /// beside one another as independent prayer languages; the relationship remains useful when
    /// resolving older stored codes and documenting the base-language fallback.</summary>
    public static readonly IReadOnlyDictionary<string, IReadOnlyList<LanguageOption>> RitesByLanguage =
        new Dictionary<string, IReadOnlyList<LanguageOption>>
        {
            ["he"] =
            [
                new("he", "נוסח הנציגות", true),
                // The Mission of St. Gamaliel's wording, sent by Erez 2026-08-05.
                new("he-x-gamliel", "נוסח השליחות", true),
            ],
        };

    /// <summary>The rites offered for a code's language — empty when there is only one way to
    /// pray it.</summary>
    public static IReadOnlyList<LanguageOption> Rites(string code) =>
        RitesByLanguage.GetValueOrDefault(BaseLanguage(code) ?? code) ?? [];

    public static LanguageOption Resolve(string? code)
    {
        if (code is null || code == DefaultSentinel)
        {
            return Option(AppSettings.DefaultLanguageCode);
        }

        return Option(code);
    }

    /// <summary>Resolves a stored code, which may name a rite ("he-x-gamliel") rather than a
    /// plain language — the rite keeps its own code so every lookup can overlay it on the
    /// base.</summary>
    private static LanguageOption Option(string? code)
    {
        if (All.FirstOrDefault(l => l.Code == code) is { } exact) return exact;
        if (code is not null && Rites(code).FirstOrDefault(r => r.Code == code) is { } rite)
        {
            // A rite carries its language's name in pickers; its own name belongs to the rite row.
            var language = All.FirstOrDefault(l => l.Code == (BaseLanguage(rite.Code) ?? rite.Code));
            if (language is not null)
            {
                return rite with { NativeName = language.NativeName };
            }
        }

        return All.FirstOrDefault(l => l.Code == code) ?? All.First(l => l.Code == DefaultCode);
    }
}
