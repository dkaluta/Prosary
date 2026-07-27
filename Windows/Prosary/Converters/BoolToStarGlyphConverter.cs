using Microsoft.UI.Xaml.Data;

namespace Prosary.Converters;

/// <summary>Filled star glyph when favorited, outline star otherwise — used by
/// <c>FavoritesListPage</c>'s "More Devotions" star-toggle buttons (the full favorite cards use a
/// plain always-filled star for <c>IsDefault</c> instead, since that's not a toggle).</summary>
public sealed class BoolToStarGlyphConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, string language)
        => value is true ? "" : "";

    public object ConvertBack(object value, Type targetType, object parameter, string language)
        => throw new NotSupportedException();
}
