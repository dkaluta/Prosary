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
        // The Mission of St. Gamaliel's own wording, sent by Erez 2026-08-05: an overlay on "he",
        // so the prayers they have not sent still read in the app's Hebrew.
        new("he-x-gamliel", "עברית — נוסח השליחות", true),
        new("ru", "Русский", false),
        new("tl", "Tagalog", false),
    ];

    public static LanguageOption Resolve(string? code)
    {
        if (code is null || code == DefaultSentinel)
        {
            var stored = AppSettings.DefaultLanguageCode;
            return All.FirstOrDefault(l => l.Code == stored) ?? All.First(l => l.Code == DefaultCode);
        }
        return All.FirstOrDefault(l => l.Code == code) ?? All.First(l => l.Code == DefaultCode);
    }
}
