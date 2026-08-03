using Windows.Storage;

namespace Prosary.Models;

/// <summary>The user's personal ordering of the Home cards (v0.7, Gamaliel item 2): a
/// persisted list of card ids. Cards absent from the list keep their natural directory order
/// after the ordered ones; an empty list means pure directory order. Mirrors iOS/Android.</summary>
public static class HomeOrder
{
    private const string Key = "homeCardOrder";

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
            // Settings I/O never breaks Home.
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

    /// <summary>Stable: unknown ids keep their relative (directory) order after the ordered.</summary>
    public static List<T> Apply<T>(IEnumerable<T> cards, Func<T, string> id)
    {
        var order = Saved();
        var list = cards.ToList();
        if (order.Count == 0)
        {
            return list;
        }

        return list
            .Select((card, index) => (card, index))
            .OrderBy(x => { var i = order.ToList().IndexOf(id(x.card)); return i < 0 ? int.MaxValue : i; })
            .ThenBy(x => x.index)
            .Select(x => x.card)
            .ToList();
    }

    /// <summary>"My most important prayer first" — the one-move path (card context menu).</summary>
    public static void MoveToTop(string cardId, IEnumerable<string> allIdsInDisplayOrder)
    {
        Save(new[] { cardId }.Concat(allIdsInDisplayOrder.Where(i => i != cardId)));
    }
}
