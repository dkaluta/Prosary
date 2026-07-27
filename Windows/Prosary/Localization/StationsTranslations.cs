namespace Prosary.Localization;

/// <summary>
/// Looks up a Station's display text by imageKey and language code, falling back to Latin (and
/// then a bare placeholder) when a translation is missing. Only <c>la</c>/<c>en</c> are populated
/// for now — <c>ar</c>/<c>he</c>/<c>ru</c>/<c>tl</c> fall back to Latin until dedicated
/// translations are added. Mirrors <see cref="MysteryTranslations"/>.
/// </summary>
public static partial class StationsTranslations
{
    private static readonly Dictionary<string, IReadOnlyDictionary<string, StationText>> ByLanguage;

    // See PrayerTranslations' static constructor for why this can't be a field initializer:
    // static field initializers across this partial class's files run in an unspecified order.
    static StationsTranslations()
    {
        ByLanguage = new Dictionary<string, IReadOnlyDictionary<string, StationText>>
        {
            ["la"] = Latin,
            ["en"] = English,
        };
    }

    public static StationText Get(string? languageCode, string imageKey)
    {
        if (languageCode is not null && ByLanguage.TryGetValue(languageCode, out var table) &&
            table.TryGetValue(imageKey, out var text))
        {
            return text;
        }

        return Latin.TryGetValue(imageKey, out var latinText) ? latinText : new StationText(imageKey, string.Empty);
    }
}
