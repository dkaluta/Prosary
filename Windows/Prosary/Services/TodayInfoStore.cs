using System.Text.Json;

namespace Prosary.Services;

/// <summary>The calendar's own vocabulary: "Solemnity" / "Feast" / "Sunday" / "Memorial" /
/// "Optional Memorial" (Roman), "1st Class" … "3rd Class" (1962).</summary>
public sealed record FeastDay(string Title, string Rank);

public sealed record PopeIntention(string Title, string Text);

/// <summary>
/// Backs the Pray tab's "Today" section: the day's feast per the selected liturgical
/// calendar, and the Pope's monthly prayer intention. Everything comes from bundled offline
/// datasets (Shared/data/, generated at dev time — movable feasts baked in per year, no
/// computus in the app; and popesprayer.va's published intentions). calendars.json is the
/// registry of switchable calendars (2026-08, Erez's request): the app-wide "feastCalendarId"
/// setting picks one, defaulting — also for unknown ids — to the registry's default (the Latin
/// Patriarchate of Jerusalem overlay). The feast table reloads whenever the selection changes;
/// the calendar affects this row only, never the engine's season/mystery machinery. A
/// date/month outside the datasets returns null and the row simply hides — regenerating the
/// JSON yearly is the only maintenance.
/// </summary>
public static class TodayInfoStore
{
    /// <summary>One entry of calendars.json — a switchable feast calendar. <c>File</c> is the
    /// basename of the calendar's dataset ("feasts", "feasts-roman", …).</summary>
    public sealed record FeastCalendar(string Id, string File, string Name, Dictionary<string, string>? NameByLanguage)
    {
        /// <summary>The Settings picker label, resolved by UI language with the plain name as
        /// fallback.</summary>
        public string DisplayName =>
            UiLanguage() is { } language && NameByLanguage?.GetValueOrDefault(language) is { } localized
                ? localized
                : Name;

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

    private sealed record CalendarsFile(string? Default, List<FeastCalendar>? Calendars);

    private static readonly JsonSerializerOptions JsonOptions = new() { PropertyNameCaseInsensitive = true };

    private static Dictionary<string, FeastDay> _feastsByDay = new();
    private static Dictionary<string, PopeIntention> _intentionsByMonth = new();
    private static CalendarsFile? _registry;
    private static bool _didLoadRegistry;
    private static bool _didLoadIntentions;
    private static string? _loadedCalendarId;

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
            var stored = SelectedCalendarId;
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
