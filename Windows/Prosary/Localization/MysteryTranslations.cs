using Prosary.Models;

namespace Prosary.Localization;

/// <summary>
/// Looks up the title/fruit/description of a mystery by <see cref="Mystery.ImageKey"/> and
/// language code, falling back to Latin when a translation is missing.
/// </summary>
public static partial class MysteryTranslations
{
    // internal (not private) so Prosary.Tests can verify per-language completeness directly —
    // see PrayerTranslationsCompletenessTests.cs. Relies on the [InternalsVisibleTo] declared in
    // Properties/AssemblyInfo.cs.
    internal static readonly Dictionary<string, IReadOnlyDictionary<string, MysteryText>> ByLanguage;

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
        string? title = null;
        string? fruit = null;
        string? description = null;
        string? transliteratedDescription = null;

        foreach (var code in Prosary.Models.LanguageCatalog.FallbackChain(languageCode))
        {
            var packOverride = PrayerPackStore.MysteryOverride(code, imageKey);
            if (packOverride is not null)
            {
                title ??= packOverride.Title;
                fruit ??= packOverride.Fruit;
                if (description is null && packOverride.Description is { } suppliedDescription)
                {
                    description = suppliedDescription;
                    // Never resolve this independently: it belongs only to the source that
                    // supplied the description selected above.
                    transliteratedDescription = packOverride.TransliteratedDescription;
                }
            }

            if (ByLanguage.TryGetValue(code, out var table) && table.TryGetValue(imageKey, out var text))
            {
                title ??= text.Title;
                fruit ??= text.Fruit;
                if (description is null)
                {
                    description = text.Description;
                    transliteratedDescription = text.TransliteratedDescription;
                }
            }

            if (title is not null && fruit is not null && description is not null) break;
        }

        return new MysteryText(
            title ?? imageKey,
            fruit ?? string.Empty,
            description ?? string.Empty,
            transliteratedDescription);
    }

    /// <summary>Returns a presentation copy with only the mystery heading unpointed. Fruit and
    /// Scripture description remain exactly as authored.</summary>
    public static MysteryText GetDisplay(string? languageCode, string imageKey)
    {
        var text = Get(languageCode, imageKey);
        return text with { Title = HebrewDisplayText.WithoutMarks(text.Title) };
    }
}
