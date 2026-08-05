using Windows.Storage;

namespace Prosary.Models;

/// <summary>
/// Which devotions are pinned to the Pray page. Deliberately separate from <see cref="Prayer"/>:
/// a Prayer is a *saved configuration* (a preset), while this is only "show it on Pray", so
/// unpinning a devotion never destroys the presets underneath it. Devotion ids are the ones the
/// rest of the app already uses — "rosary", "jesusPrayer", or a bundle id. Mirrors
/// iOS/Android's FavoriteDevotions.
/// </summary>
public static class FavoriteDevotions
{
    private const string Key = "favoriteDevotionIds";

    /// <summary>Null until the user first pins or unpins something, which is what lets a fresh
    /// install fall back to "whatever already has a preset" instead of an empty Pray page.</summary>
    private static IReadOnlyList<string>? Stored()
    {
        try
        {
            return ApplicationData.Current.LocalSettings.Values[Key] is string csv
                ? csv.Split('\n', StringSplitOptions.RemoveEmptyEntries)
                : null;
        }
        catch
        {
            return null;
        }
    }

    public static IReadOnlyList<string> Ids(IEnumerable<string> implied) =>
        Stored() ?? implied.ToList();

    public static bool Contains(string devotionId, IEnumerable<string> implied) =>
        Ids(implied).Contains(devotionId);

    /// <summary>Pins or unpins, materialising the implied set on the first explicit choice so the
    /// other devotions keep their current state rather than silently vanishing.</summary>
    public static void Toggle(string devotionId, IEnumerable<string> implied)
    {
        var current = Ids(implied).ToList();
        if (!current.Remove(devotionId))
        {
            current.Add(devotionId);
        }

        try
        {
            ApplicationData.Current.LocalSettings.Values[Key] = string.Join('\n', current);
        }
        catch
        {
            // Settings I/O never breaks Pray.
        }
    }

    public static void Pin(string devotionId, IEnumerable<string> implied)
    {
        if (!Contains(devotionId, implied))
        {
            Toggle(devotionId, implied);
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
}
