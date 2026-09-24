using Windows.Storage;
using Prosary.Localization;

namespace Prosary.Models;

/// <summary>App-wide preferences that aren't tied to any single <see cref="Prayer"/> — the
/// default prayer language (resolved whenever a Prayer's own LanguageCode is
/// <see cref="LanguageCatalog.DefaultSentinel"/>) and the prayer flows' auto-advance interval.
///
/// <see cref="LanguageCatalog.Resolve"/> is called from many non-UI sites (engines, the preset
/// store) that have no natural access to app storage. The default comes from the active
/// interface locale, while the next launch's language choice and the other preferences live
/// in <see cref="ApplicationData.LocalSettings"/>.</summary>
public static class AppSettings
{
    private const string KeyInterfaceLanguage = "interfaceLanguageCode";
    private const string KeyDefaultLanguage = "defaultLanguageCode";
    private const string KeyBasicPrayersLanguage = "basicPrayersLanguageCode";
    private const string KeyAramaicSignOfCrossForm = "aramaicSignOfCrossForm";
    private const string KeyUseJaffaHailMaryWording = "useJaffaHailMaryWording";
    private const string KeyFeastCalendar = "feastCalendarId";
    private const string KeyEasternPaschaStyle = "easternPaschaStyle";
    private const string KeyAutoAdvance = "autoAdvanceSeconds";
    private const string KeyKeyboardArrowNavigationEnabled = "keyboardArrowNavigationEnabled";
    private const string KeyKeyboardSpaceAdvanceEnabled = "keyboardSpaceAdvanceEnabled";
    private const string KeyShowTodayFeast = "showTodayFeast";
    private const string KeyShowTodayIntention = "showTodayIntention";
    private const string KeyShowTodayTorahPortion = "showTodayTorahPortion";
    private const string KeyShowPrayerNameInPrayerLanguage = "showPrayerNameInPrayerLanguage";
    private const string KeyReadingsEdition = "readingsEditionId";
    private const string KeyTodayLanguage = "todayLanguageCode";
    private const string KeySyriacTypeface = "syriacTypeface";
    private const string KeyAramaicDefaultScript = "aramaicDefaultScript";
    private const string KeyHebrewPrayerTypeface = "hebrewPrayerTypeface";
    private const string KeyLatinPrayerTypeface = "latinPrayerTypeface";
    private const string KeyCyrillicPrayerTypeface = "cyrillicPrayerTypeface";
    private const string KeyHebrewScriptureTypeface = "hebrewScriptureTypeface";
    private const string KeyFavoriteBasicPrayers = "favoriteBasicPrayerIds";
    private const string KeyFavoriteBasicPrayersFirst = "favoriteBasicPrayersFirst";
    private const string KeyLanguageFallbackOrder = "languageFallbackOrder";

    private static string? _interfaceLanguageCode;
    private static string? _prayerLanguageCode;
    private static string? _basicPrayersLanguageCode;
    private static string? _aramaicSignOfCrossForm;
    private static bool? _useJaffaHailMaryWording;
    private static string? _feastCalendarId;
    private static string? _easternPaschaStyle;
    private static int? _autoAdvanceSeconds;
    private static bool? _keyboardArrowNavigationEnabled;
    private static bool? _keyboardSpaceAdvanceEnabled;
    private static bool? _showTodayFeast;
    private static bool? _showTodayIntention;
    private static bool? _showTodayTorahPortion;
    private static bool? _showPrayerNameInPrayerLanguage;
    private static string? _todayLanguageCode;
    private static string? _readingsEditionId;
    private static string? _syriacTypeface;
    private static string? _aramaicDefaultScript;
    private static string? _hebrewPrayerTypeface;
    private static string? _latinPrayerTypeface;
    private static string? _cyrillicPrayerTypeface;
    private static string? _hebrewScriptureTypeface;
    private static HashSet<string>? _favoriteBasicPrayerIds;
    private static bool? _favoriteBasicPrayersFirst;
    private static IReadOnlyList<string>? _languageFallbackOrder;

    /// <summary>The saved interface choice; empty follows Windows. Applied together with
    /// XAML resources on the next launch so existing prayer windows retain a coherent locale.</summary>
    public static string InterfaceLanguageCode => _interfaceLanguageCode ??= ReadInterfaceLanguageCode();

    private static string ReadInterfaceLanguageCode()
    {
        if (ReadLocalSetting(KeyInterfaceLanguage) is string stored)
            return UiLanguageCatalog.NormalizePreference(stored);
        // Windows already offered an independent interface override. Preserve that choice
        // once, including an empty System Default, before startup sets the effective locale.
        string previous;
        try { previous = Windows.Globalization.ApplicationLanguages.PrimaryLanguageOverride; }
        catch { previous = string.Empty; }
        var preference = UiLanguageCatalog.NormalizePreference(previous);
        WriteLocalSetting(KeyInterfaceLanguage, preference);
        return preference;
    }

    public static void SetInterfaceLanguageCode(string code)
    {
        _interfaceLanguageCode = UiLanguageCatalog.NormalizePreference(code);
        WriteLocalSetting(KeyInterfaceLanguage, _interfaceLanguageCode);
    }

    /// <summary>The independent prayer-language preference. Empty follows the active interface;
    /// existing prayer-only languages and Hebrew traditions remain exactly as saved.</summary>
    public static string PrayerLanguageCode => _prayerLanguageCode ??=
        ReadLocalSetting(KeyDefaultLanguage) as string ?? LanguageCatalog.DefaultSentinel;

    public static string DefaultLanguageCode => string.IsNullOrEmpty(PrayerLanguageCode)
        ? UiLanguageCatalog.Current : PrayerLanguageCode;

    public static void SetDefaultLanguageCode(string code)
    {
        _prayerLanguageCode = code == LanguageCatalog.VicariateContentCode ? "he" : code;
        WriteLocalSetting(KeyDefaultLanguage, _prayerLanguageCode);
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

    public static bool UseJaffaHailMaryWording => _useJaffaHailMaryWording ??=
        ReadLocalSetting(KeyUseJaffaHailMaryWording) as bool? ?? false;

    public static event Action? PrayerWordingChanged;

    public static void SetUseJaffaHailMaryWording(bool value)
    {
        if (UseJaffaHailMaryWording == value) return;
        _useJaffaHailMaryWording = value;
        WriteLocalSetting(KeyUseJaffaHailMaryWording, value);
        PrayerWordingChanged?.Invoke();
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

    public static event Action? TypographyChanged;

    public static string AramaicDefaultScript => _aramaicDefaultScript ??=
        ReadLocalSetting(KeyAramaicDefaultScript) as string == "Syrc" ? "Syrc" : "Hebr";

    public static void SetAramaicDefaultScript(string value)
    {
        _aramaicDefaultScript = value == "Syrc" ? "Syrc" : "Hebr";
        WriteLocalSetting(KeyAramaicDefaultScript, _aramaicDefaultScript);
        TypographyChanged?.Invoke();
    }

    public static string SyriacTypeface => _syriacTypeface ??=
        ReadLocalSetting(KeySyriacTypeface) as string ?? TypefaceDefault;
    public static string HebrewPrayerTypeface => _hebrewPrayerTypeface ??=
        ReadLocalSetting(KeyHebrewPrayerTypeface) as string ?? TypefaceDefault;
    public static string HebrewScriptureTypeface => _hebrewScriptureTypeface ??=
        ReadLocalSetting(KeyHebrewScriptureTypeface) as string ?? TypefaceDefault;

    public static string LatinPrayerTypeface => _latinPrayerTypeface ??=
        ReadLocalSetting(KeyLatinPrayerTypeface) as string ?? TypefaceDefault;

    public static void SetLatinPrayerTypeface(string value)
    {
        _latinPrayerTypeface = value;
        WriteLocalSetting(KeyLatinPrayerTypeface, value);
        TypographyChanged?.Invoke();
    }

    public static string CyrillicPrayerTypeface => _cyrillicPrayerTypeface ??=
        ReadLocalSetting(KeyCyrillicPrayerTypeface) as string ?? TypefaceDefault;

    public static void SetCyrillicPrayerTypeface(string value)
    {
        _cyrillicPrayerTypeface = value;
        WriteLocalSetting(KeyCyrillicPrayerTypeface, value);
        TypographyChanged?.Invoke();
    }

    public static void SetSyriacTypeface(string value)
    {
        _syriacTypeface = value;
        WriteLocalSetting(KeySyriacTypeface, value);
        TypographyChanged?.Invoke();
    }

    public static void SetHebrewPrayerTypeface(string value)
    {
        _hebrewPrayerTypeface = value;
        WriteLocalSetting(KeyHebrewPrayerTypeface, value);
        TypographyChanged?.Invoke();
    }

    public static void SetHebrewScriptureTypeface(string value)
    {
        _hebrewScriptureTypeface = value;
        WriteLocalSetting(KeyHebrewScriptureTypeface, value);
        TypographyChanged?.Invoke();
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

    public static bool ShowTodayTorahPortion => _showTodayTorahPortion ??=
        ReadLocalSetting(KeyShowTodayTorahPortion) as bool? ?? false;

    public static string EasternPaschaStyle => _easternPaschaStyle ??=
        (ReadLocalSetting(KeyEasternPaschaStyle) as string == "gregorian" ? "gregorian" : "julian");

    public static void SetEasternPaschaStyle(string value)
    {
        _easternPaschaStyle = value == "gregorian" ? "gregorian" : "julian";
        WriteLocalSetting(KeyEasternPaschaStyle, _easternPaschaStyle);
    }

    public static void SetShowTodayTorahPortion(bool value)
    {
        _showTodayTorahPortion = value;
        WriteLocalSetting(KeyShowTodayTorahPortion, value);
    }

    public static bool ShowPrayerNameInPrayerLanguage => _showPrayerNameInPrayerLanguage ??=
        ReadLocalSetting(KeyShowPrayerNameInPrayerLanguage) as bool? ?? false;

    public static void SetShowPrayerNameInPrayerLanguage(bool value)
    {
        _showPrayerNameInPrayerLanguage = value;
        WriteLocalSetting(KeyShowPrayerNameInPrayerLanguage, value);
    }

    /// <summary>Empty follows the interface language; prayer-language changes never alter Today.</summary>
    public static string TodayLanguageCode => _todayLanguageCode ??=
        ReadLocalSetting(KeyTodayLanguage) as string ?? string.Empty;

    public static void SetTodayLanguageCode(string code)
    {
        _todayLanguageCode = code;
        WriteLocalSetting(KeyTodayLanguage, code);
    }

    /// <summary>Empty follows the interface's Bible edition; absent text never selects another language.</summary>
    public static string ReadingsEditionId => _readingsEditionId ??=
        ReadLocalSetting(KeyReadingsEdition) as string ?? string.Empty;
    public static event Action? ReadingsEditionChanged;

    public static void SetReadingsEditionId(string id)
    {
        if (ReadingsEditionId == id) return;
        _readingsEditionId = id;
        WriteLocalSetting(KeyReadingsEdition, id);
        ReadingsEditionChanged?.Invoke();
    }

    public static bool KeyboardArrowNavigationEnabled => _keyboardArrowNavigationEnabled ??=
        ReadLocalSetting(KeyKeyboardArrowNavigationEnabled) as bool? ?? true;

    public static void SetKeyboardArrowNavigationEnabled(bool value)
    {
        _keyboardArrowNavigationEnabled = value;
        WriteLocalSetting(KeyKeyboardArrowNavigationEnabled, value);
    }

    public static bool KeyboardSpaceAdvanceEnabled => _keyboardSpaceAdvanceEnabled ??=
        ReadLocalSetting(KeyKeyboardSpaceAdvanceEnabled) as bool? ?? true;

    public static void SetKeyboardSpaceAdvanceEnabled(bool value)
    {
        _keyboardSpaceAdvanceEnabled = value;
        WriteLocalSetting(KeyKeyboardSpaceAdvanceEnabled, value);
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
