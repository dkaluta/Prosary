using Microsoft.Windows.ApplicationModel.Resources;

namespace Prosary.Localization;

/// <summary>
/// UI-language string lookup (v0.7, Gamaliel item 3 — Hebrew UI). Every call carries its English
/// fallback inline so unit tests, which run unpackaged with no resources.pri, keep working — and
/// so a missing resw key degrades to English instead of an empty control. Prayer *content*
/// localization (PrayerTranslations et al.) is a separate axis and never routes through here.
/// </summary>
public static class Loc
{
    private static ResourceLoader? _loader;
    private static bool _unavailable;
    private static ResourceManager? _manager;

    public static string Tr(string key, string fallback)
    {
        if (_unavailable)
        {
            return fallback;
        }

        try
        {
            _loader ??= new ResourceLoader();
            var value = _loader.GetString(key);
            return string.IsNullOrEmpty(value) ? fallback : value;
        }
        catch
        {
            _unavailable = true;
            return fallback;
        }
    }

    /// <summary>Look up a caption in an explicit language without changing the app locale.</summary>
    public static string Tr(string key, string fallback, string language)
    {
        try
        {
            _manager ??= new ResourceManager();
            var context = _manager.CreateResourceContext();
            context.QualifierValues["Language"] = UiLanguageCatalog.ResourceTag(language);
            var value = _manager.MainResourceMap.GetSubtree("Resources").GetValue(key, context).ValueAsString;
            return string.IsNullOrEmpty(value) ? fallback : value;
        }
        catch
        {
            // Unpackaged unit tests have no PRI; retain the caller's language-specific fallback.
            return fallback;
        }
    }
}
