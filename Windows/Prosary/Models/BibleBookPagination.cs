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
