namespace Prosary.ViewModels;

/// <summary>A text position survives wrapping, unlike a pixel or whole-scroll-view fraction.
/// Before reaching the body, retain progress through the artwork/header instead.</summary>
public readonly record struct PrayerReadingAnchor(int? TextOffset, double LineFraction, double PreludeFraction)
{
    public static PrayerReadingAnchor BeforeBody(double offset, double bodyTop) =>
        new(null, 0, bodyTop > 0 ? Math.Clamp(offset / bodyTop, 0, 1) : 0);

    public static int FirstVisibleOffset(int symbolCount, double top,
        Func<int, (double Top, double Height)> characterRect)
    {
        var low = 0;
        var high = Math.Max(0, symbolCount - 1);
        // Logical text order has nondecreasing line positions in both LTR and RTL paragraphs.
        while (low < high)
        {
            var middle = low + (high - low) / 2;
            var rect = characterRect(middle);
            if (rect.Top + rect.Height <= top) low = middle + 1;
            else high = middle;
        }
        return low;
    }

    public double ScrollOffset(double bodyTop, double lineTop, double lineHeight, double maximumOffset) =>
        Math.Clamp(TextOffset is null ? PreludeFraction * bodyTop : bodyTop + lineTop + LineFraction * lineHeight,
            0, Math.Max(0, maximumOffset));
}
