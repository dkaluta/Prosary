using Windows.Storage;

namespace Prosary.Models;

/// <summary>The user's personal ordering of the basic-prayers list (Erez, 2026-08-08) — the
/// <see cref="HomeOrder"/> pattern on a fixed catalog: a persisted list of prayer ids, catalog
/// order for ids it does not name (so a prayer added in an update appears after the ordered
/// ones), an empty list meaning pure catalog order. Mirrors iOS/Android.</summary>
public static class BasicPrayersOrder
{
    private const string Key = "basicPrayerOrder";

    public static IReadOnlyList<string> Saved()
    {
        try
        {
            return ApplicationData.Current.LocalSettings.Values[Key] is string csv && csv.Length > 0
                ? csv.Split('\n')
                : [];
        }
        catch
        {
            return [];
        }
    }

    public static void Save(IEnumerable<string> ids)
    {
        try
        {
            ApplicationData.Current.LocalSettings.Values[Key] = string.Join('\n', ids);
        }
        catch
        {
            // Settings I/O never breaks the list.
        }
    }

    public static void Reset()
    {
        try
        {
            ApplicationData.Current.LocalSettings.Values.Remove(Key);
        }
        catch
        {
        }
    }

    /// <summary>Stable: unknown ids keep their relative (catalog) order after the ordered.</summary>
    public static List<BasicPrayer> Apply(IEnumerable<BasicPrayer> prayers)
    {
        var order = Saved().ToList();
        var list = prayers.ToList();
        if (order.Count == 0)
        {
            return list;
        }

        return list
            .Select((prayer, index) => (prayer, index))
            .OrderBy(x => { var i = order.IndexOf(x.prayer.Id); return i < 0 ? int.MaxValue : i; })
            .ThenBy(x => x.index)
            .Select(x => x.prayer)
            .ToList();
    }
}
