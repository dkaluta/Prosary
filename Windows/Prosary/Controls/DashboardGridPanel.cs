using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Windows.Foundation;

namespace Prosary.Controls;

/// Adaptive rows keep source prose at its natural height; no uniform cell can clip a hymn.
public sealed class DashboardGridPanel : Panel
{
    private const double Gap = 12;
    private const double MinimumCardWidth = 340;

    private static int Columns(double width) => Math.Clamp((int)((width + Gap) / (MinimumCardWidth + Gap)), 1, 3);

    protected override Size MeasureOverride(Size availableSize)
    {
        var width = double.IsFinite(availableSize.Width) ? availableSize.Width : MinimumCardWidth;
        var columns = Columns(width);
        var cardWidth = Math.Max(0, (width - Gap * (columns - 1)) / columns);
        double height = 0, rowHeight = 0;
        for (var index = 0; index < Children.Count; index++)
        {
            var child = Children[index];
            child.Measure(new Size(cardWidth, double.PositiveInfinity));
            rowHeight = Math.Max(rowHeight, child.DesiredSize.Height);
            if (index % columns == columns - 1 || index == Children.Count - 1)
            {
                height += rowHeight + (index == Children.Count - 1 ? 0 : Gap);
                rowHeight = 0;
            }
        }
        return new Size(width, height);
    }

    protected override Size ArrangeOverride(Size finalSize)
    {
        var columns = Columns(finalSize.Width);
        var cardWidth = Math.Max(0, (finalSize.Width - Gap * (columns - 1)) / columns);
        double top = 0;
        for (var first = 0; first < Children.Count; first += columns)
        {
            var last = Math.Min(first + columns, Children.Count);
            var rowHeight = Enumerable.Range(first, last - first).Max(index => Children[index].DesiredSize.Height);
            for (var index = first; index < last; index++)
                Children[index].Arrange(new Rect((index - first) * (cardWidth + Gap), top, cardWidth,
                    Children[index].DesiredSize.Height));
            top += rowHeight + Gap;
        }
        return finalSize;
    }
}
