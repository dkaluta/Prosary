using Prosary.Localization;

namespace Prosary.Models;

/// <summary>
/// The handful of prayers worth praying on their own, outside any devotion — tester-requested
/// (Erez, 2026-08-07): the Sign of the Cross, the Our Father, the Hail Mary, the Glory Be, and
/// the Trisagion's Holy God, the four Marian antiphons, and the prayer to St. Michael.
/// Nothing here carries text: each entry names the same keys the
/// devotions already resolve, so a basic prayer reads in the prayer language with every chain
/// the flows use — rites included. Mirrors iOS's BasicPrayerCatalog.swift.
/// </summary>
/// <param name="BundleId">The bundle whose content resolves this prayer's keys.</param>
/// <param name="ImageKey">The prayer's traditional illustration — the same override keys the
/// devotions use.</param>
public sealed record BasicPrayer(
    string Id, string BundleId, string TitleKey, string BodyKey, string ImageKey)
{
    public string HomeCardId => $"basic:{Id}";
}

public static class BasicPrayerCatalog
{
    public static readonly IReadOnlyList<BasicPrayer> All =
    [
        new("signOfCross", "rosary", "signumCrucisTitle", "signumCrucis", "crucifix"),
        new("ourFather", "rosary", "paterNosterTitle", "paterNoster", "our_father"),
        new("hailMary", "rosary", "aveMariaTitle", "aveMaria", "madonna_and_child"),
        new("gloryBe", "rosary", "gloriaPatriTitle", "gloriaPatri", "glory_be"),
        // "The Creed" resolves per community, not per catalog: the shared tables carry the
        // Apostles' Creed, and the Mission of St. Gamaliel's overlay replaces it with the
        // Nicene — exactly as their Rosary prays it (Erez, 2026-08-08).
        new("creed", "rosary", "symbolumApostolorumTitle", "symbolumApostolorum", "crucifix"),
        new("holyGod", "trisagion", "trisagionAcclamationTitle", "trisagionAcclamation", "jesus_portrait"),
        // Standalone antiphon text, without the Rosary's appended versicle and collect.
        new("salveRegina", "rosary", "salveReginaTitle", "salveRegina", "madonna_and_child"),
        new("almaRedemptorisMater", "rosary", "almaRedemptorisMaterTitle", "almaRedemptorisMater", "madonna_and_child"),
        new("aveReginaCaelorum", "rosary", "aveReginaCaelorumTitle", "aveReginaCaelorum", "madonna_and_child"),
        new("reginaCaeli", "rosary", "reginaCaeliTitle", "reginaCaeli", "madonna_and_child"),
        new("stMichael", "rosary", "sanctusMichaelTitle", "sanctusMichael", "st_michael"),
    ];

    public static BasicPrayer? Prayer(string id) => All.FirstOrDefault(p => p.Id == id);

    public static LanguageOption EffectiveLanguage(BasicPrayer prayer, string? languageCode)
    {
        var language = LanguageCatalog.Resolve(languageCode);
        if (LanguageCatalog.PickerLanguageCode(language.Code) != "he") return language;
        var rites = PrayerPackStore.AuthoredHebrewRites(prayer.BundleId, prayer.BodyKey);
        return rites.Count == 1 ? LanguageCatalog.Resolve(rites[0].Code) : language;
    }

    public static RosaryStep Step(BasicPrayer prayer, string? languageCode = null)
    {
        var language = EffectiveLanguage(prayer, languageCode);
        return new RosaryStep(
            Title: PrayerPackStore.ResolveDisplayText(prayer.BundleId, language.Code, prayer.TitleKey),
            Subtitle: null,
            Body: PrayerPackStore.ResolveBodyText(prayer.BundleId, language.Code, prayer.BodyKey),
            TransliteratedBody: PrayerPackStore.Transliteration(prayer.BundleId, language.Code, prayer.BodyKey),
            ImageOverrideKey: prayer.ImageKey);
    }
}
