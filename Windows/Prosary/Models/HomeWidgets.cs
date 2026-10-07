namespace Prosary.Models;

/// <summary>The cross-platform Home card contract. Missing storage gets the initial layout;
/// an explicitly empty layout stays empty. Unknown and repeated identifiers never become cards.</summary>
public static class HomeWidgets
{
    public static IReadOnlyList<string> All { get; } =
        ["readings", "popeIntention", "calendar", "photo", "reminders", "scripture", "reflection", "feast"];
    public static IReadOnlyList<string> Defaults { get; } =
        ["readings", "popeIntention", "calendar", "reminders", "scripture", "feast"];

    public static IReadOnlyList<string> Parse(string? stored) => stored is null
        ? Defaults.ToArray() : Normalize(stored.Split('\n', StringSplitOptions.RemoveEmptyEntries));

    public static IReadOnlyList<string> Normalize(IEnumerable<string> ids) => ids
        .Where(id => All.Contains(id, StringComparer.Ordinal)).Distinct(StringComparer.Ordinal).ToArray();

    public static IReadOnlyList<string> Add(IEnumerable<string> ids, string id) => Normalize(ids.Append(id));
}
