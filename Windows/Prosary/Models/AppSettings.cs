using Windows.Storage;

namespace Prosary.Models;

/// <summary>App-wide preferences that aren't tied to any single <see cref="Prayer"/> — the
/// default prayer language (resolved whenever a Prayer's own LanguageCode is
/// <see cref="LanguageCatalog.DefaultSentinel"/>) and the prayer flows' auto-advance interval.
///
/// <see cref="LanguageCatalog.Resolve"/> is called from many non-UI sites (engines, the preset
/// store) that have no natural access to app storage, so this holds the resolved value in a
/// static property initialized once at app start from <see cref="ApplicationData.LocalSettings"/>
/// (Windows' equivalent of Android's SharedPreferences / iOS's UserDefaults) rather than requiring
/// every call site to thread storage access through.</summary>
public static class AppSettings
{
    private const string KeyDefaultLanguage = "defaultLanguageCode";
    private const string KeyFeastCalendar = "feastCalendarId";
    private const string KeyAutoAdvance = "autoAdvanceSeconds";

    private static string? _defaultLanguageCode;
    private static string? _feastCalendarId;
    private static int? _autoAdvanceSeconds;

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

    /// <summary>The Home "Today" feast row's calendar id (calendars.json registry); empty — or
    /// an id the registry no longer lists — resolves to the registry's default inside
    /// <c>TodayInfoStore</c>.</summary>
    public static string FeastCalendarId
    {
        get
        {
            if (_feastCalendarId is null)
            {
                _feastCalendarId = ApplicationData.Current.LocalSettings.Values[KeyFeastCalendar] as string
                    ?? string.Empty;
            }
            return _feastCalendarId;
        }
        private set => _feastCalendarId = value;
    }

    public static void SetFeastCalendarId(string id)
    {
        FeastCalendarId = id;
        ApplicationData.Current.LocalSettings.Values[KeyFeastCalendar] = id;
    }

    /// <summary>Seconds between automatic step advances in the prayer flows; 0 = off.</summary>
    public static int AutoAdvanceSeconds
    {
        get
        {
            _autoAdvanceSeconds ??= ApplicationData.Current.LocalSettings.Values[KeyAutoAdvance] as int? ?? 0;
            return _autoAdvanceSeconds.Value;
        }
        private set => _autoAdvanceSeconds = value;
    }

    public static void SetAutoAdvanceSeconds(int seconds)
    {
        AutoAdvanceSeconds = seconds;
        ApplicationData.Current.LocalSettings.Values[KeyAutoAdvance] = seconds;
    }
}
