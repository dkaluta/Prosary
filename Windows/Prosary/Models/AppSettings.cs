using Windows.Storage;

namespace Prosary.Models;

/// <summary>App-wide preferences that aren't tied to any single <see cref="Prayer"/> — currently
/// just the default prayer language, resolved whenever a Prayer's own LanguageCode is
/// <see cref="LanguageCatalog.DefaultSentinel"/>.
///
/// <see cref="LanguageCatalog.Resolve"/> is called from many non-UI sites (engines, the preset
/// store) that have no natural access to app storage, so this holds the resolved value in a
/// static property initialized once at app start from <see cref="ApplicationData.LocalSettings"/>
/// (Windows' equivalent of Android's SharedPreferences / iOS's UserDefaults) rather than requiring
/// every call site to thread storage access through.</summary>
public static class AppSettings
{
    private const string KeyDefaultLanguage = "defaultLanguageCode";

    private static string? _defaultLanguageCode;

    public static string DefaultLanguageCode
    {
        get
        {
            if (_defaultLanguageCode is null)
            {
                _defaultLanguageCode = ApplicationData.Current.LocalSettings.Values[KeyDefaultLanguage] as string
                    ?? LanguageCatalog.DefaultCode;
            }
            return _defaultLanguageCode;
        }
        private set => _defaultLanguageCode = value;
    }

    public static void SetDefaultLanguageCode(string code)
    {
        DefaultLanguageCode = code;
        ApplicationData.Current.LocalSettings.Values[KeyDefaultLanguage] = code;
    }
}
