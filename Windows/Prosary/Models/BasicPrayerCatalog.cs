using Prosary.Localization;

namespace Prosary.Models;

/// <summary>
/// The handful of prayers worth praying on their own, outside any devotion — tester-requested
/// (Erez, 2026-08-07): the Sign of the Cross, the Our Father, the Hail Mary, the Glory Be, and
/// the Trisagion's Holy God. Nothing here carries text: each entry names the same keys the
/// devotions already resolve, so a basic prayer reads in the prayer language with every chain
/// the flows use — rites included. Mirrors iOS's BasicPrayerCatalog.swift.
/// </summary>
/// <param name="BundleId">The bundle whose content resolves this prayer's keys.</param>
/// <param name="ImageKey">The prayer's traditional illustration — the same override keys the
/// devotions use.</param>
public sealed record BasicPrayer(
    string Id, string BundleId, string TitleKey, string BodyKey, string ImageKey);

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
    ];

    public static BasicPrayer? Prayer(string id) => All.FirstOrDefault(p => p.Id == id);

    public static RosaryStep Step(BasicPrayer prayer, string? languageCode = null)
    {
        var language = LanguageCatalog.Resolve(languageCode);
        return new RosaryStep(
            Title: PrayerPackStore.ResolveDisplayText(prayer.BundleId, language.Code, prayer.TitleKey),
            Subtitle: null,
            Body: PrayerPackStore.ResolveBodyText(prayer.BundleId, language.Code, prayer.BodyKey),
            TransliteratedBody: PrayerPackStore.Transliteration(prayer.BundleId, language.Code, prayer.BodyKey),
            ImageOverrideKey: prayer.ImageKey);
    }
}
