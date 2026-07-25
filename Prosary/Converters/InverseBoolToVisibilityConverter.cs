using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Data;

namespace Prosary.Converters;

/// <summary>Inverse of <see cref="BoolToVisibilityConverter"/> — used for the two-FontIcon
/// filled/outline star toggle pattern (favorited shows the filled glyph and hides the outline
/// one; not-favorited is the reverse) without needing a second bound bool on the ViewModel.</summary>
public sealed class InverseBoolToVisibilityConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, string language)
        => value is true ? Visibility.Collapsed : Visibility.Visible;

    public object ConvertBack(object value, Type targetType, object parameter, string language)
        => value is Visibility.Collapsed;
}
