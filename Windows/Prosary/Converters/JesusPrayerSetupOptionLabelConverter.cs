using Microsoft.UI.Xaml.Data;
using Prosary.ViewModels;

using Prosary.Localization;

namespace Prosary.Converters;

/// <summary>Display label for a <see cref="JesusPrayerSetupOption"/> ComboBox item — Convert-only,
/// since the ComboBox binds its own <c>SelectedItem</c> straight to the enum value with no
/// converter needed there.</summary>
public sealed class JesusPrayerSetupOptionLabelConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, string language) => value switch
    {
        JesusPrayerSetupOption.ThirtyThree => "33",
        JesusPrayerSetupOption.SixtySix => "66",
        JesusPrayerSetupOption.NinetyNine => "99",
        JesusPrayerSetupOption.Custom => Loc.Tr("jp_custom", "Custom"),
        JesusPrayerSetupOption.Unbounded => Loc.Tr("jp_unbounded", "Unbounded"),
        _ => value?.ToString() ?? string.Empty
    };

    public object ConvertBack(object value, Type targetType, object parameter, string language)
        => throw new NotSupportedException();
}
