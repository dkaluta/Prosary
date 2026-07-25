using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Data;

namespace Prosary.Converters;

/// <summary>WinUI3 has no MAUI-style <c>IsVisible</c> bool property — every element's visibility
/// binds through <see cref="UIElement.Visibility"/> instead, so every <c>IsVisible="{Binding
/// SomeBool}"</c> in the irosary/Android references this project ports from needs this converter
/// at the WinUI3 XAML layer.</summary>
public sealed class BoolToVisibilityConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, string language)
        => value is true ? Visibility.Visible : Visibility.Collapsed;

    public object ConvertBack(object value, Type targetType, object parameter, string language)
        => value is Visibility.Visible;
}
