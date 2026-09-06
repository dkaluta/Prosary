using System.Globalization;
using Prosary.Models;

namespace Prosary.Localization;

/// <summary>Interface and Today languages are separate from the prayer-language preference.
/// Windows names Tagalog resources "fil"; shared content keeps its existing "tl" code.</summary>
public static class UiLanguageCatalog
{
    public static readonly IReadOnlyList<LanguageOption> All =
    [
        new("en", "English", false), new("he", "עברית", true),
        new("ar", "العربية", true), new("ru", "Русский", false),
        new("tl", "Tagalog", false), new("fr", "Français", false),
        new("it", "Italiano", false),
    ];

    public static string Normalize(string? tag)
    {
        var code = tag?.Replace('_', '-').Split('-')[0].ToLowerInvariant();
        if (code == "fil") code = "tl";
        if (code == "iw") code = "he";
        return All.Any(option => option.Code == code) ? code! : "en";
    }

    public static string ResourceTag(string? code) => Normalize(code) switch
    {
        "tl" => "fil", "en" => "en-US", var language => language,
    };

    public static string Current
    {
        get
        {
            try
            {
                return Normalize(Windows.Globalization.ApplicationLanguages.Languages.FirstOrDefault());
            }
            catch
            {
                return Normalize(CultureInfo.CurrentUICulture.Name);
            }
        }
    }

    public static string ResolveToday(string? stored, string appLanguage) =>
        Normalize(appLanguage);

    public static bool IsRightToLeft(string language) => Normalize(language) is "he" or "ar";

    public static string? Localized(IReadOnlyDictionary<string, string>? values, string language)
    {
        if (values is null) return null;
        var normalized = Normalize(language);
        foreach (var code in new[] { language, normalized, normalized == "tl" ? "fil" : normalized })
            if (values.TryGetValue(code, out var value) && !string.IsNullOrWhiteSpace(value)) return value;
        return null;
    }
}
