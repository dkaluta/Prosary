using Prosary.Models;

namespace Prosary.Localization;

/// <summary>
/// Looks up the title/fruit/description of a mystery by <see cref="Mystery.ImageKey"/> and
/// language code, falling back to Latin when a translation is missing.
/// </summary>
public static partial class MysteryTranslations
{
    private static readonly Dictionary<string, IReadOnlyDictionary<string, MysteryText>> ByLanguage;

    // See PrayerTranslations' static constructor for why this can't be a field initializer:
    // static field initializers across this partial class's files run in an unspecified order.
    static MysteryTranslations()
    {
        ByLanguage = new Dictionary<string, IReadOnlyDictionary<string, MysteryText>>
        {
            ["la"] = Latin,
            ["en"] = English,
            ["ar"] = Arabic,
            ["he"] = Hebrew,
            ["ru"] = Russian,
            ["tl"] = Tagalog,
        };
    }

    public static MysteryText Get(string? languageCode, string imageKey)
    {
        if (languageCode is not null && ByLanguage.TryGetValue(languageCode, out var table) &&
            table.TryGetValue(imageKey, out var text))
        {
            return text;
        }

        return Latin.TryGetValue(imageKey, out var latinText) ? latinText : new MysteryText(imageKey, string.Empty, string.Empty);
    }
}
