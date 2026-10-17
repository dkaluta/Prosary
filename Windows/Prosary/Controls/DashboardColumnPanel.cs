using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Prosary.Models;
using Windows.Foundation;

namespace Prosary.Controls;

/// Equal-width independent columns retain one flat child collection in saved source order.
public sealed class DashboardColumnPanel : Panel
{
    protected override Size MeasureOverride(Size availableSize)
    {
        var cardWidth = DashboardColumnLayout.CardWidthFor(availableSize.Width);
        foreach (var child in Children)
            child.Measure(new Size(cardWidth, double.PositiveInfinity));
        var layout = DashboardColumnLayout.Create(availableSize.Width,
            Children.Select(child => child.DesiredSize.Height).ToArray());
        return new Size(layout.Width, layout.Height);
    }

    protected override Size ArrangeOverride(Size finalSize)
    {
        var layout = DashboardColumnLayout.Create(finalSize.Width,
            Children.Select(child => child.DesiredSize.Height).ToArray());
        for (var index = 0; index < Children.Count; index++)
        {
            var card = layout.Cards[index];
            // X is logical leading; inherited FlowDirection mirrors the native panel for RTL.
            Children[index].Arrange(new Rect(card.X, card.Y, card.Width, card.Height));
        }
        return finalSize;
    }
}
