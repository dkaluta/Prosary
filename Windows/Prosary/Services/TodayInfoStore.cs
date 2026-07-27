using System.Text.Json;

namespace Prosary.Services;

/// <summary>"Solemnity" / "Feast" / "Sunday" / "Memorial" / "Optional Memorial".</summary>
public sealed record FeastDay(string Title, string Rank);

public sealed record PopeIntention(string Title, string Text);

/// <summary>
/// Backs the Home screen's "Today" section: the day's feast per the Holy Land (Latin
/// Patriarchate of Jerusalem) calendar, and the Pope's monthly prayer intention. Both come from
/// bundled offline datasets (Shared/data/, generated at dev time — the General Roman Calendar
/// with the LPJ's documented propers overlaid, movable feasts baked in per year; and
/// popesprayer.va's published intentions). A date/month outside the datasets returns null and
/// the row simply hides — regenerating the JSON yearly is the only maintenance.
/// </summary>
public static class TodayInfoStore
{
    private sealed record FeastsFile(Dictionary<string, FeastDay>? Days);

    private sealed record IntentionsFile(Dictionary<string, PopeIntention>? Months);

    private static readonly JsonSerializerOptions JsonOptions = new() { PropertyNameCaseInsensitive = true };

    private static Dictionary<string, FeastDay> _feastsByDay = new();
    private static Dictionary<string, PopeIntention> _intentionsByMonth = new();
    private static bool _didLoad;

    public static FeastDay? Feast(DateOnly date)
    {
        EnsureLoaded();
        return _feastsByDay.GetValueOrDefault(date.ToString("yyyy-MM-dd"));
    }

    public static PopeIntention? Intention(DateOnly date)
    {
        EnsureLoaded();
        return _intentionsByMonth.GetValueOrDefault(date.ToString("yyyy-MM"));
    }

    private static void EnsureLoaded()
    {
        if (_didLoad) return;
        _didLoad = true;

        _feastsByDay = LoadFile<FeastsFile>("feasts")?.Days ?? new Dictionary<string, FeastDay>();
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
