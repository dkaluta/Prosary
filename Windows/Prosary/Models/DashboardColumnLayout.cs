namespace Prosary.Models;

public readonly record struct DashboardCardPlacement(double X, double Y, double Width, double Height);

/// <summary>Saved index selects the column. A tall card advances only that column, without
/// sorting cards by height or changing the source/accessibility order.</summary>
public sealed record DashboardColumnLayout(double Width, double Height, int ColumnCount,
    IReadOnlyList<DashboardCardPlacement> Cards)
{
    public const double Gap = 12;
    public const double MinimumCardWidth = 340;
    public const double MaximumWidth = 1200;

    private static double BoundedWidth(double availableWidth) => double.IsFinite(availableWidth)
        ? Math.Clamp(availableWidth, 0, MaximumWidth) : MinimumCardWidth;

    private static int Columns(double width) =>
        Math.Clamp((int)((width + Gap) / (MinimumCardWidth + Gap)), 1, 3);

    public static double CardWidthFor(double availableWidth)
    {
        var width = BoundedWidth(availableWidth);
        return Math.Max(0, (width - Gap * (Columns(width) - 1)) / Columns(width));
    }

    public static DashboardColumnLayout Create(double availableWidth, IReadOnlyList<double> heights)
    {
        var width = BoundedWidth(availableWidth);
        var columns = Columns(width);
        var cardWidth = CardWidthFor(width);
        var nextTop = new double[columns];
        var cards = new DashboardCardPlacement[heights.Count];
        for (var index = 0; index < heights.Count; index++)
        {
            var column = index % columns;
            var height = Math.Max(0, heights[index]);
            cards[index] = new(column * (cardWidth + Gap), nextTop[column], cardWidth, height);
            nextTop[column] += height + Gap;
        }
        return new(width, heights.Count == 0 ? 0 : nextTop.Max() - Gap, columns, cards);
    }
}
