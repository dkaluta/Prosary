namespace Prosary.Models;

/// <summary>A prayer language the app can display, independent of the device's own UI/system
/// language.</summary>
/// <param name="Code">ISO 639-1 code used as the key into the content layer's prayer/mystery
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
        new("he", "עברית", true),
        // Aramaic in Hebrew script — the Aramaic-rite communities' liturgical language.
        new("arc", "ארמית", true),
        new("ru", "Русский", false),
        new("tl", "Tagalog", false),
    ];

    /// <summary>Rites (community uses) of one language: the same tongue, a different wording.
    /// Listed under the language rather than beside it, because choosing "Hebrew" and choosing
    /// *whose* Hebrew are two different questions — and because a rite that lacks a prayer falls
    /// back to the language's own, so they are never truly separate languages. The first entry of
    /// each list is the language's own (base) use; the rest overlay it.</summary>
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
