using System.Globalization;
using Prosary.Models;

namespace Prosary.Localization;

/// <summary>The interface supplies Today's language and the default when no prayer language is chosen.
/// Windows names Tagalog resources "fil"; shared content keeps its existing "tl" code.</summary>
public static class UiLanguageCatalog
{
    public static readonly IReadOnlyList<LanguageOption> All =
    [
        new("en", "English", false), new("he", "עברית", true),
        new("ar", "العربية", true), new("ru", "Русский", false),
        new("uk", "Українська", false),
        new("tl", "Tagalog", false), new("fr", "Français", false),
        new("it", "Italiano", false),
    ];

    public static string Normalize(string? tag)
    {
        return NormalizePreference(tag) is { Length: > 0 } code ? code : "en";
    }

    public static string NormalizePreference(string? tag)
    {
        var code = tag?.Trim().Replace('_', '-').Split('-')[0].ToLowerInvariant();
        if (code == "fil") code = "tl";
        if (code == "iw") code = "he";
        return All.Any(option => option.Code == code) ? code! : string.Empty;
    }

    public static string ResourceTag(string? code) => Normalize(code) switch
    {
        "tl" => "fil", "en" => "en-US", var language => language,
    };

    /// <summary>Choose the first supported Windows language, not English merely because
    /// an unsupported language precedes a supported one in the person's preference list.</summary>
    public static string Resolve(string? preference, IEnumerable<string> systemLanguages) =>
        NormalizePreference(preference) is { Length: > 0 } selected ? selected
        : systemLanguages.Select(NormalizePreference).FirstOrDefault(code => code.Length > 0) ?? "en";

    private static string? _current;
    public static string Current => _current ??= Resolve(AppSettings.InterfaceLanguageCode, SystemLanguages());

    internal static void UseLanguageForCurrentSession(string language) => _current = Normalize(language);

    /// <summary>Apply before constructing any XAML. App-language edits deliberately wait for
    /// relaunch because WinUI's x:Uid resources and existing window trees do not hot-reload.</summary>
    public static void Initialize()
    {
        UseLanguageForCurrentSession(Resolve(AppSettings.InterfaceLanguageCode, SystemLanguages()));
        var tag = ResourceTag(Current);
        Microsoft.Windows.Globalization.ApplicationLanguages.PrimaryLanguageOverride = tag;
        CultureInfo.CurrentUICulture = CultureInfo.GetCultureInfo(tag);
        CultureInfo.DefaultThreadCurrentUICulture = CultureInfo.CurrentUICulture;
    }

    private static IEnumerable<string> SystemLanguages()
    {
        try
        {
            return Windows.System.UserProfile.GlobalizationPreferences.Languages;
        }
        catch { return [CultureInfo.CurrentUICulture.Name]; }
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
