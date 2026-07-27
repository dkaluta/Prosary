using Microsoft.UI.Xaml.Data;
using Prosary.Models;

namespace Prosary.Converters;

/// <summary>Segoe Fluent Icons glyph for a <see cref="PrayerKind"/>'s <c>FontIcon</c> — reuses
/// <c>PrayerKind.IconGlyph()</c> so the glyph has one source of truth. Used by
/// <c>FavoritesListPage</c>'s "More Devotions" rows.</summary>
public sealed class PrayerKindIconGlyphConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, string language)
        => value is PrayerKind kind ? kind.IconGlyph() : string.Empty;

    public object ConvertBack(object value, Type targetType, object parameter, string language)
        => throw new NotSupportedException();
}
