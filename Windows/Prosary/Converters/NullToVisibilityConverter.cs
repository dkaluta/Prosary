using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Data;

namespace Prosary.Converters;

/// <summary>Visible when the bound value is non-null — used for
/// <see cref="ViewModels.IPrayerStepFlowViewModel.Progress"/>'s progress bar, which hides
/// entirely for an open-ended (unbounded Jesus Prayer) session rather than showing a meaningless
/// bar stuck at some fraction.</summary>
public sealed class NullToVisibilityConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, string language)
        => value is null ? Visibility.Collapsed : Visibility.Visible;

    public object ConvertBack(object value, Type targetType, object parameter, string language)
        => throw new NotSupportedException();
}
