using Microsoft.UI.Xaml.Data;
using Prosary.Localization;
using Prosary.Models;

namespace Prosary.Converters;

/// <summary>Localized display title for a <see cref="Mystery"/>'s ComboBox item — reuses
/// <see cref="MysteryTranslations"/> so the label has one source of truth. Used by
/// <c>FavoriteEditorPage</c>'s "Which mystery" picker (One Mystery Only mode).</summary>
public sealed class MysteryTitleConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, string language)
        => value is Mystery mystery
            ? MysteryTranslations.GetDisplay(
                System.Globalization.CultureInfo.CurrentUICulture.TwoLetterISOLanguageName,
                mystery.ImageKey).Title
            : string.Empty;

    public object ConvertBack(object value, Type targetType, object parameter, string language)
        => throw new NotSupportedException();
}
