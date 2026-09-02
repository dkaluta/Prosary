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
    private const string KeyAramaicSignOfCrossForm = "aramaicSignOfCrossForm";
    private const string KeyFeastCalendar = "feastCalendarId";
    private const string KeyAutoAdvance = "autoAdvanceSeconds";
    private const string KeyShowTodayFeast = "showTodayFeast";
    private const string KeyShowTodayIntention = "showTodayIntention";
    private const string KeySyriacTypeface = "syriacTypeface";
    private const string KeyHebrewPrayerTypeface = "hebrewPrayerTypeface";
    private const string KeyHebrewScriptureTypeface = "hebrewScriptureTypeface";
    private const string KeyFavoriteBasicPrayers = "favoriteBasicPrayerIds";
    private const string KeyFavoriteBasicPrayersFirst = "favoriteBasicPrayersFirst";
    private const string KeyLanguageFallbackOrder = "languageFallbackOrder";

    private static string? _defaultLanguageCode;
    private static string? _aramaicSignOfCrossForm;
    private static string? _feastCalendarId;
    private static int? _autoAdvanceSeconds;
    private static bool? _showTodayFeast;
    private static bool? _showTodayIntention;
    private static string? _syriacTypeface;
    private static string? _hebrewPrayerTypeface;
    private static string? _hebrewScriptureTypeface;
    private static HashSet<string>? _favoriteBasicPrayerIds;
    private static bool? _favoriteBasicPrayersFirst;
    private static IReadOnlyList<string>? _languageFallbackOrder;

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

    public const string AramaicSignOfCrossFormA = "formA";
    public const string AramaicSignOfCrossFormB = "formB";
    public const string TypefaceDefault = "default";
    public const string TypefaceWestern = "western";
    public const string TypefaceEastern = "eastern";
    public const string TypefaceDavidLibre = "davidLibre";
    public const string TypefaceSansSerif = "sansSerif";
    public const string TypefaceStamAshkenaz = "stamAshkenaz";
    public const string TypefaceStamSefarad = "stamSefarad";
    public const string TypefaceRashi = "rashi";

    /// <summary>Which of Erez's two sourced Aramaic Sign of the Cross forms is used app-wide.</summary>
    public static string AramaicSignOfCrossForm
    {
        get
        {
            if (_aramaicSignOfCrossForm is null)
            {
                var stored = ApplicationData.Current.LocalSettings.Values[KeyAramaicSignOfCrossForm] as string;
                _aramaicSignOfCrossForm = stored == AramaicSignOfCrossFormB
                    ? AramaicSignOfCrossFormB
                    : AramaicSignOfCrossFormA;
            }
            return _aramaicSignOfCrossForm;
        }
        private set => _aramaicSignOfCrossForm = value;
    }

    public static void SetAramaicSignOfCrossForm(string form)
    {
        AramaicSignOfCrossForm = form == AramaicSignOfCrossFormB
            ? AramaicSignOfCrossFormB
            : AramaicSignOfCrossFormA;
        ApplicationData.Current.LocalSettings.Values[KeyAramaicSignOfCrossForm] = AramaicSignOfCrossForm;
    }

    /// <summary>Whether the app-wide Aramaic form currently governs prayer text. An explicitly
    /// Aramaic Rosary under another app default uses its own saved form instead.</summary>
    public static bool UsesSystemWideAramaicSignOfCrossForm =>
        (LanguageCatalog.BaseLanguage(DefaultLanguageCode) ?? DefaultLanguageCode) == "arc";

    public static string SyriacTypeface => _syriacTypeface ??=
        ApplicationData.Current.LocalSettings.Values[KeySyriacTypeface] as string ?? TypefaceDefault;
    public static string HebrewPrayerTypeface => _hebrewPrayerTypeface ??=
        ApplicationData.Current.LocalSettings.Values[KeyHebrewPrayerTypeface] as string ?? TypefaceDefault;
    public static string HebrewScriptureTypeface => _hebrewScriptureTypeface ??=
        ApplicationData.Current.LocalSettings.Values[KeyHebrewScriptureTypeface] as string ?? TypefaceDefault;

    public static void SetSyriacTypeface(string value)
    {
        _syriacTypeface = value;
        ApplicationData.Current.LocalSettings.Values[KeySyriacTypeface] = value;
    }

    public static void SetHebrewPrayerTypeface(string value)
    {
        _hebrewPrayerTypeface = value;
        ApplicationData.Current.LocalSettings.Values[KeyHebrewPrayerTypeface] = value;
    }

    public static void SetHebrewScriptureTypeface(string value)
    {
        _hebrewScriptureTypeface = value;
        ApplicationData.Current.LocalSettings.Values[KeyHebrewScriptureTypeface] = value;
    }

    public static IReadOnlySet<string> FavoriteBasicPrayerIds => _favoriteBasicPrayerIds ??=
        ((ApplicationData.Current.LocalSettings.Values[KeyFavoriteBasicPrayers] as string) ?? string.Empty)
            .Split('\n', StringSplitOptions.RemoveEmptyEntries).ToHashSet();

    public static bool FavoriteBasicPrayersFirst => _favoriteBasicPrayersFirst ??=
        ApplicationData.Current.LocalSettings.Values[KeyFavoriteBasicPrayersFirst] as bool? ?? false;

    public static void ToggleFavoriteBasicPrayer(string id)
    {
        var updated = FavoriteBasicPrayerIds.ToHashSet();
        if (!updated.Add(id)) updated.Remove(id);
        _favoriteBasicPrayerIds = updated;
        ApplicationData.Current.LocalSettings.Values[KeyFavoriteBasicPrayers] = string.Join('\n', updated);
    }

    public static void SetFavoriteBasicPrayersFirst(bool value)
    {
        _favoriteBasicPrayersFirst = value;
        ApplicationData.Current.LocalSettings.Values[KeyFavoriteBasicPrayersFirst] = value;
    }

    public static IReadOnlyList<string> LanguageFallbackOrder => _languageFallbackOrder ??=
        ((ApplicationData.Current.LocalSettings.Values[KeyLanguageFallbackOrder] as string) ?? string.Empty)
            .Split('\n', StringSplitOptions.RemoveEmptyEntries);

    public static void SetLanguageFallbackOrder(IEnumerable<string> codes)
    {
        _languageFallbackOrder = codes.ToArray();
        ApplicationData.Current.LocalSettings.Values[KeyLanguageFallbackOrder] = string.Join('\n', _languageFallbackOrder);
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

    /// <summary>Whether Home's Today section shows the day's feast row — Erez's request: each
    /// Today row can be switched off on its own, so any of both/either/neither can show.</summary>
    public static bool ShowTodayFeast
    {
        get
        {
            _showTodayFeast ??= ApplicationData.Current.LocalSettings.Values[KeyShowTodayFeast] as bool? ?? true;
            return _showTodayFeast.Value;
        }
        private set => _showTodayFeast = value;
    }

    public static void SetShowTodayFeast(bool shows)
    {
        ShowTodayFeast = shows;
        ApplicationData.Current.LocalSettings.Values[KeyShowTodayFeast] = shows;
    }

    /// <summary>Whether Home's Today section shows the Pope's monthly intention row.</summary>
    public static bool ShowTodayIntention
    {
        get
        {
            _showTodayIntention ??= ApplicationData.Current.LocalSettings.Values[KeyShowTodayIntention] as bool? ?? true;
            return _showTodayIntention.Value;
        }
        private set => _showTodayIntention = value;
    }

    public static void SetShowTodayIntention(bool shows)
    {
        ShowTodayIntention = shows;
        ApplicationData.Current.LocalSettings.Values[KeyShowTodayIntention] = shows;
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
