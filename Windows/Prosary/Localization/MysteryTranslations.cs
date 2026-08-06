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
        if (languageCode is not null)
        {
            var packOverride = PrayerPackStore.MysteryOverride(languageCode, imageKey);
            if (packOverride is not null) return packOverride;
        }

        if (languageCode is not null && ByLanguage.TryGetValue(languageCode, out var table) &&
            table.TryGetValue(imageKey, out var text))
        {
            return text;
        }

        // Community variants ("he-x-gamliel") overlay their base language, exactly as
        // PrayerTranslations.Get does — without this step a rite that ships no mystery texts of
        // its own announced the mysteries in *Latin* while the rest of the session prayed Hebrew.
        if (languageCode is not null && Prosary.Models.LanguageCatalog.BaseLanguage(languageCode) is { } baseCode)
        {
            var basePackOverride = PrayerPackStore.MysteryOverride(baseCode, imageKey);
            if (basePackOverride is not null) return basePackOverride;

            if (ByLanguage.TryGetValue(baseCode, out var baseTable) &&
                baseTable.TryGetValue(imageKey, out var baseText))
            {
                return baseText;
            }
        }

        // Pack-provided Latin before the hardcoded Latin table — some mystery texts (the Seven
        // Sorrows, the Franciscan Crown's Adoration of the Magi) live only in their bundles.
        return PrayerPackStore.MysteryOverride("la", imageKey)
            ?? (Latin.TryGetValue(imageKey, out var latinText) ? latinText : new MysteryText(imageKey, string.Empty, string.Empty));
    }
}
