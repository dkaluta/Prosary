using Microsoft.UI.Xaml.Data;
using Prosary.Models;

namespace Prosary.Converters;

/// <summary>Display label for a <see cref="JesusPrayerTarget"/> option in
/// <c>FavoriteEditorPage</c>'s target ComboBox — matches Android's <c>FavoriteEditorScreen.kt</c>
/// segmented labels ("33"/"66"/"99"/"Unbounded") rather than <c>JesusPrayerOptions.TargetDisplayName</c>'s
/// "33×" (that one is for read-only summaries elsewhere, not this picker).</summary>
public sealed class JesusPrayerTargetLabelConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, string language) => value switch
    {
        JesusPrayerTarget.Count(var n) => n.ToString(),
        JesusPrayerTarget.Unbounded => "Unbounded",
        _ => value?.ToString() ?? string.Empty
    };

    public object ConvertBack(object value, Type targetType, object parameter, string language)
        => throw new NotSupportedException();
}
