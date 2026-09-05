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
    private const string KeyBasicPrayersLanguage = "basicPrayersLanguageCode";
    private const string KeyAramaicSignOfCrossForm = "aramaicSignOfCrossForm";
    private const string KeyFeastCalendar = "feastCalendarId";
    private const string KeyAutoAdvance = "autoAdvanceSeconds";
    private const string KeyShowTodayFeast = "showTodayFeast";
    private const string KeyShowTodayIntention = "showTodayIntention";
    private const string KeyTodayLanguage = "todayLanguageCode";
    private const string KeySyriacTypeface = "syriacTypeface";
    private const string KeyHebrewPrayerTypeface = "hebrewPrayerTypeface";
    private const string KeyHebrewScriptureTypeface = "hebrewScriptureTypeface";
    private const string KeyFavoriteBasicPrayers = "favoriteBasicPrayerIds";
    private const string KeyFavoriteBasicPrayersFirst = "favoriteBasicPrayersFirst";
    private const string KeyLanguageFallbackOrder = "languageFallbackOrder";

    private static string? _defaultLanguageCode;
    private static string? _basicPrayersLanguageCode;
    private static string? _aramaicSignOfCrossForm;
    private static string? _feastCalendarId;
    private static int? _autoAdvanceSeconds;
    private static bool? _showTodayFeast;
    private static bool? _showTodayIntention;
    private static string? _todayLanguageCode;
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
                _defaultLanguageCode = ReadLocalSetting(KeyDefaultLanguage) as string
                    ?? LanguageCatalog.DefaultCode;
            }
            return _defaultLanguageCode;
        }
        private set => _defaultLanguageCode = value;
    }

    public static void SetDefaultLanguageCode(string code)
    {
        DefaultLanguageCode = code;
        WriteLocalSetting(KeyDefaultLanguage, code);
    }

    /// <summary>The basic-prayers list and flow share their own language selection. Empty
    /// follows the app-wide default without replacing it.</summary>
    public static string BasicPrayersLanguageCode => _basicPrayersLanguageCode ??=
        ReadLocalSetting(KeyBasicPrayersLanguage) as string ?? LanguageCatalog.DefaultSentinel;

    public static void SetBasicPrayersLanguageCode(string code)
    {
        _basicPrayersLanguageCode = code;
        WriteLocalSetting(KeyBasicPrayersLanguage, code);
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
                var stored = ReadLocalSetting(KeyAramaicSignOfCrossForm) as string;
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
        WriteLocalSetting(KeyAramaicSignOfCrossForm, AramaicSignOfCrossForm);
    }

    /// <summary>Whether the app-wide Aramaic form currently governs prayer text. An explicitly
    /// Aramaic Rosary under another app default uses its own saved form instead.</summary>
    public static bool UsesSystemWideAramaicSignOfCrossForm =>
        (LanguageCatalog.BaseLanguage(DefaultLanguageCode) ?? DefaultLanguageCode) == "arc";

    public static string SyriacTypeface => _syriacTypeface ??=
        ReadLocalSetting(KeySyriacTypeface) as string ?? TypefaceDefault;
    public static string HebrewPrayerTypeface => _hebrewPrayerTypeface ??=
        ReadLocalSetting(KeyHebrewPrayerTypeface) as string ?? TypefaceDefault;
    public static string HebrewScriptureTypeface => _hebrewScriptureTypeface ??=
        ReadLocalSetting(KeyHebrewScriptureTypeface) as string ?? TypefaceDefault;

    public static void SetSyriacTypeface(string value)
    {
        _syriacTypeface = value;
        WriteLocalSetting(KeySyriacTypeface, value);
    }

    public static void SetHebrewPrayerTypeface(string value)
    {
        _hebrewPrayerTypeface = value;
        WriteLocalSetting(KeyHebrewPrayerTypeface, value);
    }

    public static void SetHebrewScriptureTypeface(string value)
    {
        _hebrewScriptureTypeface = value;
        WriteLocalSetting(KeyHebrewScriptureTypeface, value);
    }

    public static IReadOnlySet<string> FavoriteBasicPrayerIds => _favoriteBasicPrayerIds ??=
        ((ReadLocalSetting(KeyFavoriteBasicPrayers) as string) ?? string.Empty)
            .Split('\n', StringSplitOptions.RemoveEmptyEntries).ToHashSet();

    public static bool FavoriteBasicPrayersFirst => _favoriteBasicPrayersFirst ??=
        ReadLocalSetting(KeyFavoriteBasicPrayersFirst) as bool? ?? false;

    public static void ToggleFavoriteBasicPrayer(string id)
    {
        var updated = FavoriteBasicPrayerIds.ToHashSet();
        if (!updated.Add(id)) updated.Remove(id);
        _favoriteBasicPrayerIds = updated;
        WriteLocalSetting(KeyFavoriteBasicPrayers, string.Join('\n', updated));
    }

    public static void SetFavoriteBasicPrayersFirst(bool value)
    {
        _favoriteBasicPrayersFirst = value;
        WriteLocalSetting(KeyFavoriteBasicPrayersFirst, value);
    }

    public static IReadOnlyList<string> LanguageFallbackOrder => _languageFallbackOrder ??=
        ReadLanguageFallbackOrder();

    public static void SetLanguageFallbackOrder(IEnumerable<string> codes)
    {
        _languageFallbackOrder = codes.ToArray();
        WriteLocalSetting(KeyLanguageFallbackOrder, string.Join('\n', _languageFallbackOrder));
    }

    private static IReadOnlyList<string> ReadLanguageFallbackOrder()
    {
        return ((ReadLocalSetting(KeyLanguageFallbackOrder) as string) ?? string.Empty)
            .Split('\n', StringSplitOptions.RemoveEmptyEntries);
    }

    private static object? ReadLocalSetting(string key) => TryGetLocalSettings()?.Values[key];

    private static void WriteLocalSetting(string key, object value)
    {
        if (TryGetLocalSettings() is { } localSettings)
        {
            localSettings.Values[key] = value;
        }
    }

    private static ApplicationDataContainer? TryGetLocalSettings()
    {
        try
        {
            return ApplicationData.Current.LocalSettings;
        }
        catch (InvalidOperationException)
        {
            // ApplicationData.Current requires package identity. Unit tests run in an unpackaged
            // host, where this setting remains available from the process-local cache above.
            return null;
        }
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
                var stored = ReadLocalSetting(KeyFeastCalendar) as string ?? string.Empty;
                _feastCalendarId = stored == "roman-he" ? "roman" : stored;
                if (stored == "roman-he")
                {
                    // Hebrew titles now live inside the General Roman dataset. Persist the
                    // one-time alias so old installations do not carry a dead calendar id.
                    WriteLocalSetting(KeyFeastCalendar, _feastCalendarId);
                }
            }
            return _feastCalendarId;
        }
        private set => _feastCalendarId = value;
    }

    public static void SetFeastCalendarId(string id)
    {
        FeastCalendarId = id == "roman-he" ? "roman" : id;
        WriteLocalSetting(KeyFeastCalendar, FeastCalendarId);
    }

    /// <summary>Whether Home's Today section shows the day's feast row — Erez's request: each
    /// Today row can be switched off on its own, so any of both/either/neither can show.</summary>
    public static bool ShowTodayFeast
    {
        get
        {
            _showTodayFeast ??= ReadLocalSetting(KeyShowTodayFeast) as bool? ?? true;
            return _showTodayFeast.Value;
        }
        private set => _showTodayFeast = value;
    }

    public static void SetShowTodayFeast(bool shows)
    {
        ShowTodayFeast = shows;
        WriteLocalSetting(KeyShowTodayFeast, shows);
    }

    /// <summary>Whether Home's Today section shows the Pope's monthly intention row.</summary>
    public static bool ShowTodayIntention
    {
        get
        {
            _showTodayIntention ??= ReadLocalSetting(KeyShowTodayIntention) as bool? ?? true;
            return _showTodayIntention.Value;
        }
        private set => _showTodayIntention = value;
    }

    public static void SetShowTodayIntention(bool shows)
    {
        ShowTodayIntention = shows;
        WriteLocalSetting(KeyShowTodayIntention, shows);
    }

    /// <summary>Empty follows the interface language; prayer-language changes never alter Today.</summary>
    public static string TodayLanguageCode => _todayLanguageCode ??=
        ReadLocalSetting(KeyTodayLanguage) as string ?? string.Empty;

    public static void SetTodayLanguageCode(string code)
    {
        _todayLanguageCode = code;
        WriteLocalSetting(KeyTodayLanguage, code);
    }

    /// <summary>Seconds between automatic step advances in the prayer flows; 0 = off.</summary>
    public static int AutoAdvanceSeconds
    {
        get
        {
            _autoAdvanceSeconds ??= ReadLocalSetting(KeyAutoAdvance) as int? ?? 0;
            return _autoAdvanceSeconds.Value;
        }
        private set => _autoAdvanceSeconds = value;
    }

    public static void SetAutoAdvanceSeconds(int seconds)
    {
        AutoAdvanceSeconds = seconds;
        WriteLocalSetting(KeyAutoAdvance, seconds);
    }
}
