using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Data;

namespace Prosary.Converters;

/// <summary>Bridges a ViewModel's plain <c>bool IsRightToLeft</c> to
/// <see cref="FrameworkElement.FlowDirection"/> — ported from irosary's
/// <c>BoolToFlowDirectionConverter</c> (MAUI), same idea under WinUI3's own
/// <see cref="FlowDirection"/> enum.</summary>
public sealed class BoolToFlowDirectionConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, string language)
        => value is true ? FlowDirection.RightToLeft : FlowDirection.LeftToRight;

    public object ConvertBack(object value, Type targetType, object parameter, string language)
        => value is FlowDirection.RightToLeft;
}
