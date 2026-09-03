using System.Text.Json;
using Prosary.Localization;
using Prosary.Models;

namespace Prosary.Services;

/// <summary>The calendar's own vocabulary: "Solemnity" / "Feast" / "Sunday" / "Memorial" /
/// "Optional Memorial" (Roman), "1st Class" … "3rd Class" (1962).</summary>
public sealed record FeastDay(
    string Title,
    string Rank,
    Dictionary<string, string>? TitleByLanguage = null)
{
    public string LocalizedTitle(string language) => HebrewDisplayText.WithoutMarks(
        TitleByLanguage?.GetValueOrDefault(language)
        ?? (LanguageCatalog.BaseLanguage(language) is { } baseLanguage
            ? TitleByLanguage?.GetValueOrDefault(baseLanguage)
            : null)
        ?? Title);
}

public sealed record PopeIntention(
    string Title,
    string Text,
    Dictionary<string, string>? TitleByLanguage,
    Dictionary<string, string>? TextByLanguage)
{
    public string LocalizedTitle(string language) => HebrewDisplayText.WithoutMarks(
        TitleByLanguage?.GetValueOrDefault(language)
        ?? (LanguageCatalog.BaseLanguage(language) is { } baseLanguage
            ? TitleByLanguage?.GetValueOrDefault(baseLanguage)
            : null)
        ?? Title);
    public string LocalizedText(string language) => TextByLanguage?.GetValueOrDefault(language) ?? Text;
}

public sealed record ReadingCitation(
    string Type,
    string Short,
    string Full,
    string? Hebrew = null,
    Dictionary<string, string>? ShortByLanguage = null,
    Dictionary<string, string>? FullByLanguage = null)
{
    public string LocalizedShort(string language) =>
        Localized(ShortByLanguage, language) ?? (IsHebrew(language) ? Hebrew : null) ?? Short;

    public string LocalizedFull(string language) =>
        Localized(FullByLanguage, language) ?? (IsHebrew(language) ? Hebrew : null) ?? Full;

    private static string? Localized(Dictionary<string, string>? values, string language) =>
        values?.GetValueOrDefault(language)
        ?? (LanguageCatalog.BaseLanguage(language) is { } baseLanguage
            ? values?.GetValueOrDefault(baseLanguage)
            : null);

    private static bool IsHebrew(string language) =>
        (LanguageCatalog.BaseLanguage(language) ?? language).Equals("he", StringComparison.OrdinalIgnoreCase);
}

public sealed record LiturgicalDayInfo(string English, string Hebrew);

/// <summary>
/// Backs the Pray tab's "Today" section: the day's feast per the selected liturgical
/// calendar, and the Pope's monthly prayer intention. Everything comes from bundled offline
/// datasets (Shared/data/, generated at dev time — movable feasts baked in per year, no
/// computus in the app; and popesprayer.va's published intentions). calendars.json is the
/// registry of switchable calendars (2026-08, Erez's request): the app-wide "feastCalendarId"
/// setting picks one, defaulting — also for unknown ids — to the registry's default (the Latin
/// Patriarchate of Jerusalem overlay). Its feast and readings tables reload whenever the
/// selection changes; the calendar does not affect the engine's season/mystery machinery. A
/// date/month outside the datasets returns null and the row simply hides — regenerating the
/// JSON yearly is the only maintenance.
/// </summary>
public static class TodayInfoStore
{
    /// <summary>One entry of calendars.json — a switchable liturgical calendar. <c>File</c> and
    /// <c>ReadingsFile</c> are its feast/readings dataset basenames.</summary>
    public sealed record FeastCalendar(
        string Id,
        string File,
        string Name,
        Dictionary<string, string>? NameByLanguage,
        string? ReadingsFile = null)
    {
        /// <summary>The Settings picker label, resolved by UI language with the plain name as
        /// fallback.</summary>
        public string DisplayName => HebrewDisplayText.WithoutMarks(
            UiLanguage() is { } language && NameByLanguage?.GetValueOrDefault(language) is { } localized
                ? localized
                : Name);

        /// <summary>The app UI language's two-letter code, or null in unpackaged (unit-test)
        /// contexts where the language machinery isn't up — the plain name serves there.</summary>
        private static string? UiLanguage()
        {
            try
            {
                var tag = Windows.Globalization.ApplicationLanguages.Languages.FirstOrDefault();
                return tag is { Length: >= 2 } ? tag[..2] : null;
            }
            catch
            {
                return null;
            }
        }
    }

    private sealed record FeastsFile(Dictionary<string, FeastDay>? Days);

    private sealed record IntentionsFile(Dictionary<string, PopeIntention>? Months);

    private sealed record ReadingDay(List<ReadingCitation>? Readings);

    private sealed record ReadingsFile(Dictionary<string, ReadingDay>? Days);

    private sealed record CalendarsFile(string? Default, List<FeastCalendar>? Calendars);

    private static readonly JsonSerializerOptions JsonOptions = new() { PropertyNameCaseInsensitive = true };

    private static Dictionary<string, FeastDay> _feastsByDay = new();
    private static Dictionary<string, PopeIntention> _intentionsByMonth = new();
    private static Dictionary<string, ReadingDay> _readingsByDay = new();
    private static CalendarsFile? _registry;
    private static bool _didLoadRegistry;
    private static bool _didLoadIntentions;
    private static string? _loadedCalendarId;
    private static string? _loadedReadingsCalendarId;

    /// <summary>The stored calendar selection — App startup and Settings assign it from
    /// <c>AppSettings.FeastCalendarId</c> (tests set it directly); readers go through
    /// <see cref="ResolvedCalendarId"/>, which turns null/blank/unknown into the registry's
    /// default.</summary>
    public static string? SelectedCalendarId { get; set; }

    /// <summary>The registry's calendars, in picker order.</summary>
    public static IReadOnlyList<FeastCalendar> Calendars
    {
        get
        {
            EnsureRegistryLoaded();
            return _registry?.Calendars ?? [];
        }
    }

    /// <summary>The selected calendar id, resolved: an unset or unknown selection reads as the
    /// registry's default, so a calendar removed from the registry can never dead-end the
    /// row.</summary>
    public static string ResolvedCalendarId
    {
        get
        {
            EnsureRegistryLoaded();
            var registry = _registry;
            if (registry?.Calendars is not { Count: > 0 } calendars)
            {
                return "lpj";
            }
            // roman-he was an old pseudo-calendar that duplicated the General Roman Calendar
            // solely to expose Hebrew titles. Those titles now live inline on roman; keep old
            // installations on the same calendar rather than falling back to LPJ.
            var stored = SelectedCalendarId == "roman-he" ? "roman" : SelectedCalendarId;
            if (!string.IsNullOrEmpty(stored) && calendars.Any(c => c.Id == stored))
            {
                return stored;
            }
            return registry.Default ?? calendars[0].Id;
        }
    }

    public static FeastDay? Feast(DateOnly date)
    {
        EnsureFeastsLoaded();
        return _feastsByDay.GetValueOrDefault(date.ToString("yyyy-MM-dd"));
    }

    public static PopeIntention? Intention(DateOnly date)
    {
        EnsureIntentionsLoaded();
        return _intentionsByMonth.GetValueOrDefault(date.ToString("yyyy-MM"));
    }

    public static IReadOnlyList<ReadingCitation> Readings(DateOnly date)
    {
        EnsureReadingsLoaded();
        return _readingsByDay.GetValueOrDefault(date.ToString("yyyy-MM-dd"))?.Readings ?? [];
    }

    public static LiturgicalDayInfo LiturgicalDay(DateOnly date)
    {
        var year = date.Year;
        var easter = ComputeEasterSunday(year);
        var ashWednesday = easter.AddDays(-46);
        var pentecost = easter.AddDays(49);
        var advent = FirstSundayOnOrAfter(new DateOnly(year, 11, 27));
        var christmas = new DateOnly(year, 12, 25);
        var baptism = FirstSundayOnOrAfter(new DateOnly(year, 1, 7));
        var christmasStart = date.Month == 1 ? new DateOnly(year - 1, 12, 25) : christmas;

        (string English, string Hebrew, int Week) season = date switch
        {
            _ when date >= ashWednesday && date < easter => ("Lent", "בצום", Week(ashWednesday, date)),
            _ when date >= easter && date <= pentecost => ("Easter Season", "בזמן הפסחא", Week(easter, date)),
            _ when date >= advent && date < christmas => ("Advent", "בזמן הציפייה", Week(advent, date)),
            _ when date >= christmasStart && (date < baptism || date >= christmas) =>
                ("Christmas Season", "בזמן חג המולד", Week(christmasStart, date)),
            _ when date > pentecost && date < advent =>
                ("Ordinary Time", "בזמן הרגיל", Math.Max(1, 35 - (int)Math.Ceiling((advent.DayNumber - date.DayNumber) / 7.0))),
            _ => ("Ordinary Time", "בזמן הרגיל", Week(baptism.AddDays(1), date)),
        };

        var englishWeekday = date.ToDateTime(TimeOnly.MinValue).ToString("dddd", System.Globalization.CultureInfo.GetCultureInfo("en-US"));
        var hebrewWeekday = date.ToDateTime(TimeOnly.MinValue).ToString("dddd", System.Globalization.CultureInfo.GetCultureInfo("he-IL"));
        return new LiturgicalDayInfo(
            $"{englishWeekday} · Week {season.Week} of {season.English}",
            $"{hebrewWeekday} · השבוע ה־{season.Week} {season.Hebrew}");
    }

    private static int Week(DateOnly origin, DateOnly date) => Math.Max(1, (date.DayNumber - origin.DayNumber) / 7 + 1);

    private static DateOnly FirstSundayOnOrAfter(DateOnly date)
    {
        var offset = ((int)DayOfWeek.Sunday - (int)date.DayOfWeek + 7) % 7;
        return date.AddDays(offset);
    }

    private static DateOnly ComputeEasterSunday(int year)
    {
        var a = year % 19; var b = year / 100; var c = year % 100; var d = b / 4; var e = b % 4;
        var f = (b + 8) / 25; var g = (b - f + 1) / 3; var h = (19 * a + b - d - g + 15) % 30;
        var i = c / 4; var k = c % 4; var l = (32 + 2 * e + 2 * i - h - k) % 7;
        var m = (a + 11 * h + 22 * l) / 451; var month = (h + l - 7 * m + 114) / 31;
        var day = (h + l - 7 * m + 114) % 31 + 1;
        return new DateOnly(year, month, day);
    }

    private static void EnsureRegistryLoaded()
    {
        if (_didLoadRegistry) return;
        _didLoadRegistry = true;

        _registry = LoadFile<CalendarsFile>("calendars");
    }

    /// <summary>Reloads the feast table whenever the resolved selection differs from what is
    /// loaded — which is also what heals a stale table after tests reset the selection.</summary>
    private static void EnsureFeastsLoaded()
    {
        var selected = ResolvedCalendarId;
        if (selected == _loadedCalendarId) return;
        _loadedCalendarId = selected;

        var file = Calendars.FirstOrDefault(c => c.Id == selected)?.File ?? "feasts";
        _feastsByDay = LoadFile<FeastsFile>(file)?.Days ?? new Dictionary<string, FeastDay>();
    }

    private static void EnsureIntentionsLoaded()
    {
        if (_didLoadIntentions) return;
        _didLoadIntentions = true;

        _intentionsByMonth = LoadFile<IntentionsFile>("pope-intentions")?.Months ?? new Dictionary<string, PopeIntention>();
    }

    private static void EnsureReadingsLoaded()
    {
        var selected = ResolvedCalendarId;
        if (selected == _loadedReadingsCalendarId) return;
        _loadedReadingsCalendarId = selected;

        // A missing/unknown readings file is deliberately empty. Falling back to the Roman
        // lectionary here would silently show the wrong rite after the user chose Byzantine,
        // Syriac, or the 1962 calendar.
        var file = Calendars.FirstOrDefault(c => c.Id == selected)?.ReadingsFile;
        _readingsByDay = string.IsNullOrWhiteSpace(file)
            ? new Dictionary<string, ReadingDay>()
            : LoadFile<ReadingsFile>(file)?.Days ?? new Dictionary<string, ReadingDay>();
    }

    private static T? LoadFile<T>(string name) where T : class
    {
        try
        {
            var path = Path.Combine(AppContext.BaseDirectory, "Data", $"{name}.json");
            if (!File.Exists(path)) return null;
            return JsonSerializer.Deserialize<T>(File.ReadAllBytes(path), JsonOptions);
        }
        catch
        {
            // Corrupt/unreadable dataset — the Today row simply hides.
            return null;
        }
    }
}
