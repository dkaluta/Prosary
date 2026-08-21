using Microsoft.UI.Xaml.Data;
using Prosary.Models;

namespace Prosary.Converters;

/// <summary>Display label for any of the Rosary option enums bound in a
/// <c>FavoriteEditorPage</c> ComboBox, or a <see cref="PrayerKind"/> bound in
/// the preset editors' option rows — reuses each enum's own
/// <c>DisplayName()</c> extension (the same text Android's equivalent screens show) so the label
/// text has one source of truth instead of being duplicated here.</summary>
public sealed class EnumDisplayNameConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, string language) => value switch
    {
        MysterySelectionMode m => m.DisplayName(),
        MysteryGroup g => g.DisplayName(),
        EternalRestPlacement e => e.DisplayName(),
        MarianAntiphonOption a => a.DisplayName(),
        MysteryImageStyle s => s.DisplayName(),
        PrayerKind k => k.DisplayName(),
        _ => value?.ToString() ?? string.Empty
    };

    public object ConvertBack(object value, Type targetType, object parameter, string language)
        => throw new NotSupportedException();
}
