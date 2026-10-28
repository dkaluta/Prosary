namespace Prosary.Models;

/// <summary>A page is a contiguous slice of the source's display blocks, never a verse sort.</summary>
public sealed record BibleBookPage(int Start, int Count);

public static class BibleBookPagination
{
    public static bool SupportsFacingPages(double width, double height) => width >= 720 && height >= 360;

    public static IReadOnlyList<BibleBookPage> Paginate(IReadOnlyList<double> blockHeights, double pageHeight)
    {
        if (blockHeights.Count == 0) return [];
        var capacity = double.IsFinite(pageHeight) && pageHeight > 0 ? pageHeight : 1;
        var pages = new List<BibleBookPage>();
        var start = 0;
        var used = 0d;
        for (var index = 0; index < blockHeights.Count; index++)
        {
            var measured = blockHeights[index];
            var height = double.IsFinite(measured) && measured > 0 ? measured : capacity;
            if (index > start && used + height > capacity)
            {
                pages.Add(new(start, index - start));
                start = index;
                used = 0;
            }
            // A source block taller than a page remains whole on its own scrollable page.
            used += height;
        }
        pages.Add(new(start, blockHeights.Count - start));
        return pages;
    }

    public static IReadOnlyList<BibleBookPage> FlowPages(int count, double height, Func<int, int, double> measure)
    {
        if (count == 0) return [];
        var pages = new List<BibleBookPage>();
        var first = 0;
        for (var last = 0; last < count; last++)
        {
            if (last > first && measure(first, last - first + 1) > Math.Max(1, height))
            {
                pages.Add(new(first, last - first));
                first = last;
            }
        }
        pages.Add(new(first, count - first));
        return pages;
    }

    public static IReadOnlyList<BibleBookPage> Paragraphs(int start, int count, IReadOnlyList<bool> flowing)
    {
        if (count == 0) return [];
        var result = new List<BibleBookPage>();
        var first = start;
        for (var index = start + 1; index < start + count; index++)
            if (!flowing[index] || !flowing[index - 1])
            {
                result.Add(new(first, index - first));
                first = index;
            }
        result.Add(new(first, start + count - first));
        return result;
    }

    public static int PageContaining(IReadOnlyList<BibleBookPage> pages, int blockIndex)
    {
        for (var index = 0; index < pages.Count; index++)
            if (blockIndex >= pages[index].Start && blockIndex < pages[index].Start + pages[index].Count) return index;
        return 0;
    }

    public static int SpreadContaining(IReadOnlyList<BibleBookPage> pages, int blockIndex) => PageContaining(pages, blockIndex) / 2 * 2;

    /// <summary>Swipes turn toward Scripture's inline end, independently of interface language.</summary>
    public static int SwipeDirection(double translationX, bool scriptureRightToLeft) => Math.Abs(translationX) < 40 ? 0
        : (translationX > 0) == scriptureRightToLeft ? 1 : -1;
}
