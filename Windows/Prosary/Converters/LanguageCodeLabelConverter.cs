using Microsoft.UI.Xaml.Data;
using Prosary.Models;

namespace Prosary.Converters;

/// <summary>Display label for a favorite's raw <c>LanguageCode</c> string in
/// <c>FavoriteEditorPage</c>'s language ComboBox — shows "Default — {app default name}" for
/// <see cref="LanguageCatalog.DefaultSentinel"/>, the resolved native name otherwise, matching
/// Android's <c>FavoriteEditorScreen.kt</c> language OptionPickerField.</summary>
public sealed class LanguageCodeLabelConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, string language)
    {
        var code = value as string;
        if (code == LanguageCatalog.DefaultSentinel)
        {
            return string.Format(Prosary.Localization.Loc.Tr("language_default_parenthesized", "Default ({0})"), LanguageCatalog.Resolve(LanguageCatalog.DefaultSentinel).NativeName);
        }

        return LanguageCatalog.Resolve(code).NativeName;
    }

    public object ConvertBack(object value, Type targetType, object parameter, string language)
        => throw new NotSupportedException();
}
