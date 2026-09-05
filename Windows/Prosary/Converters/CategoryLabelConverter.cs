using Microsoft.UI.Xaml.Data;
using Prosary.Localization;

namespace Prosary.Converters;

public sealed class CategoryLabelConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, string language) =>
        CategoryLabels.Display(value?.ToString() ?? string.Empty);

    public object ConvertBack(object value, Type targetType, object parameter, string language) =>
        throw new NotSupportedException();
}
