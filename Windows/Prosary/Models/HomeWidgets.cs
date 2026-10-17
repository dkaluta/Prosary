namespace Prosary.Models;

/// <summary>The cross-platform Home card contract. Missing storage gets the initial layout;
/// an explicitly empty layout stays empty. Unknown and repeated identifiers never become cards.</summary>
public static class HomeWidgets
{
    public static IReadOnlyList<string> All { get; } =
        ["readings", "torah", "popeIntention", "calendar", "photo", "reminders", "scripture", "reflection", "feast"];
    public static IReadOnlyList<string> Defaults { get; } =
        ["readings", "torah", "popeIntention", "calendar", "reminders", "scripture", "feast", "reflection"];
    public static IReadOnlyList<string> ColorIds { get; } = ["default", "blue", "green", "gold", "rose"];

    public static IReadOnlyDictionary<string, string> ParseColors(string? stored)
    {
        try
        {
            var colors = System.Text.Json.JsonSerializer.Deserialize<Dictionary<string, string>>(stored ?? "{}") ?? [];
            return colors.Where(pair => All.Contains(pair.Key, StringComparer.Ordinal)
                    && pair.Value != "default" && ColorIds.Contains(pair.Value, StringComparer.Ordinal))
                .ToDictionary(pair => pair.Key, pair => pair.Value, StringComparer.Ordinal);
        }
        catch (System.Text.Json.JsonException) { return new Dictionary<string, string>(); }
    }

    public static IReadOnlyList<string> AddingDailyCards(IReadOnlyList<string> ids)
    {
        if (ids.Count == 0) return ids;
        var result = ids.ToList();
        var readings = result.IndexOf("readings");
        if (!result.Contains("torah")) result.Insert(readings < 0 ? 0 : readings + 1, "torah");
        if (!result.Contains("reflection")) result.Add("reflection");
        return result;
    }

    public static IReadOnlyList<string> Parse(string? stored) => stored is null
        ? Defaults.ToArray() : Normalize(stored.Split('\n', StringSplitOptions.RemoveEmptyEntries));

    public static IReadOnlyList<string> Normalize(IEnumerable<string> ids) => ids
        .Where(id => All.Contains(id, StringComparer.Ordinal)).Distinct(StringComparer.Ordinal).ToArray();

    public static IReadOnlyList<string> Add(IEnumerable<string> ids, string id) => Normalize(ids.Append(id));

    public static IReadOnlyList<string> ParseCollapsed(string? stored) =>
        Normalize((stored ?? "").Split('\n', StringSplitOptions.RemoveEmptyEntries));

    public static IReadOnlyDictionary<string, string> ParseGraphics(string? stored)
    {
        try
        {
            var paths = System.Text.Json.JsonSerializer.Deserialize<Dictionary<string, string>>(stored ?? "{}") ?? [];
            return paths.Where(pair => All.Contains(pair.Key, StringComparer.Ordinal) && !string.IsNullOrWhiteSpace(pair.Value))
                .ToDictionary(pair => pair.Key, pair => pair.Value, StringComparer.Ordinal);
        }
        catch (System.Text.Json.JsonException) { return new Dictionary<string, string>(); }
    }
}
