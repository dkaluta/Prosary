using Microsoft.UI.Xaml.Data;

namespace Prosary.Converters;

/// <summary>Unwraps a <c>double?</c> to the plain <c>double</c> a
/// <see cref="Microsoft.UI.Xaml.Controls.ProgressBar.Value"/> binding needs, defaulting to 0 for
/// null (which is only ever bound alongside a <see cref="NullToVisibilityConverter"/>-driven
/// <c>Collapsed</c> on the same element, so the fallback value itself is never actually seen).</summary>
public sealed class NullableDoubleToValueConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, string language)
        => value is double d ? d : 0.0;

    public object ConvertBack(object value, Type targetType, object parameter, string language)
        => throw new NotSupportedException();
}
