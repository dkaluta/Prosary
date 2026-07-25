using Microsoft.UI.Xaml.Data;
using Microsoft.UI.Xaml.Media;
using Windows.UI;

namespace Prosary.Converters;

/// <summary>
/// WinUI3 doesn't implicitly convert a bound <see cref="Color"/> value to the
/// <see cref="Brush"/> that <c>Fill</c>/<c>Background</c>/<c>Foreground</c> actually need (unlike
/// MAUI, where irosary's equivalent bindings worked directly against <c>Color</c>-typed
/// properties) — every ViewModel in this project intentionally keeps its color properties as
/// plain <see cref="Color"/> (matching <c>Windows.UI.Notifications</c>-adjacent code and staying
/// easy to unit test), so this converter bridges the gap at the XAML layer instead.
/// </summary>
public sealed class ColorToBrushConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, string language)
        => new SolidColorBrush(value is Color color ? color : Colors.Transparent);

    public object ConvertBack(object value, Type targetType, object parameter, string language)
        => throw new NotSupportedException();
}
