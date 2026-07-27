using Prosary.Localization;
using Xunit;

namespace Prosary.Tests;

/// <summary>
/// Proves the whole .prosaryprayer pipeline end-to-end against the actual bundled
/// .prosaryprayer files (produced by Shared/tools/make-prosaryprayer.sh
/// from Shared/content/) — mirrors iOS's PrayerPackLoaderTests.swift / Android's
/// PrayerPackLoaderTest.kt. <see cref="PrayerPackStore"/> is a process-wide singleton, so loading
/// happens once via a class fixture rather than per-test.
/// </summary>
public sealed class PrayerPackLoaderFixture
{
    public PrayerPackLoaderFixture()
    {
        PrayerPackStore.Initialize(packName =>
        {
            var path = Path.Combine(AppContext.BaseDirectory, "PrayerPacks", $"{packName}.prosaryprayer");
            return File.Exists(path) ? File.OpenRead(path) : null;
        });
    }
}

public class PrayerPackLoaderTests : IClassFixture<PrayerPackLoaderFixture>
{
    public PrayerPackLoaderTests(PrayerPackLoaderFixture _)
    {
    }

    [Fact]
    public void RosaryPackProvidedKeyOverridesEnglishText()
    {
        var text = PrayerTranslations.Get("en", PrayerKey.OratioFatimae);
        Assert.Equal(
            "O my Jesus, forgive us our sins, save us from the fires of hell, lead all souls to Heaven, especially those who are in most need of Thy mercy.",
            text);
    }

    [Fact]
    public void RosaryPackProvidedMysteryOverridesLatinTitle()
    {
        var text = MysteryTranslations.Get("la", "joyful_01_annunciation");
        Assert.Equal("Nuntiatio", text.Title);
        Assert.Equal("Humilitas", text.Fruit);
    }

    [Fact]
    public void AngelusPackProvidesHebrewComposedBody()
    {
        var text = PrayerPackStore.ResolveBodyText("angelus", "he", "angelusCollectBody");
        Assert.False(string.IsNullOrEmpty(text));
        Assert.Contains("נִתְפַּלְּלָה", text);
    }

    /// <summary>The "main" prayers (Sign of the Cross, Creed, Our Father, Hail Mary, Glory Be) are
    /// deliberately absent from every bundle (see Shared/ARCHITECTURE.md) and must keep resolving
    /// from the hardcoded table even with both packs loaded. (Expected text hardcoded here rather
    /// than read from PrayerTranslations' per-language dictionaries — those are private to the
    /// Prosary assembly and not visible from this test project.)</summary>
    [Fact]
    public void MainPrayerKeyStillResolvesFromHardcodedTableNotFromAPack()
    {
        var text = PrayerTranslations.Get("en", PrayerKey.AveMaria);
        Assert.Equal(
            "Hail Mary, full of grace, the Lord is with thee. Blessed art thou amongst women, and blessed is the fruit of thy womb, Jesus.\nHoly Mary, Mother of God, pray for us sinners, now and at the hour of our death. Amen.",
            text);
    }

    /// <summary>A devotion converted to a bundle resolves entirely bundle-locally — its keys no
    /// longer exist in the hardcoded tables at all.</summary>
    [Fact]
    public void ConvertedDevotionKeyResolvesFromItsBundle()
    {
        var text = PrayerPackStore.ResolveBodyText("stationsOfTheCross", "en", "stationsOpeningPrayer");
        Assert.StartsWith("My Lord Jesus Christ, You made this journey", text);
    }

    [Fact]
    public void RosaryPackProvidesImageDataForAMysteryKey()
    {
        var data = PrayerPackStore.ImageData("joyful_01_annunciation");
        Assert.NotNull(data);
        Assert.True(data!.Length > 0);
    }

    [Fact]
    public void StationsPackProvidesItsImageData()
    {
        var data = PrayerPackStore.ImageData("station_01_condemned_to_death");
        Assert.True((data?.Length ?? 0) > 0);
    }

    [Fact]
    public void PackProvidesNoImageDataForAnUnknownKey()
    {
        Assert.Null(PrayerPackStore.ImageData("no_such_image_key"));
    }

    // Generic (bundle-driven) devotions

    [Fact]
    public void TrisagionIsDiscoveredAsACustomDevotion()
    {
        Assert.Contains("trisagion", PrayerPackStore.CustomDevotionIds());
    }

    /// <summary>The Rosary's pack has no devotion.json (override-only) and must never be
    /// mistaken for a generic devotion; the six generic devotions appear in pack-load order.</summary>
    [Fact]
    public void CustomDevotionIdsAreTheSixGenericDevotionsInLoadOrder()
    {
        Assert.Equal(
            ["angelus", "stationsOfTheCross", "franciscanCrown", "sevenSorrows", "divineMercyChaplet", "trisagion"],
            PrayerPackStore.CustomDevotionIds());
    }

    [Fact]
    public void TrisagionInfoReadsFromItsManifest()
    {
        var info = PrayerPackStore.Info("trisagion");
        Assert.Equal("Trisagion", info?.DisplayName);
        Assert.Equal("#00796B", info?.AccentColorHex);
        Assert.Equal("triangle", info?.IconSystemName);
    }

    [Fact]
    public void TrisagionDefinitionMatchesTheAuthoredSixStepSequence()
    {
        var definition = PrayerPackStore.Definition("trisagion");
        Assert.Equal(CustomDevotionDefinition.DevotionType.Steps, definition?.Type);
        var steps = definition?.Steps ?? [];
        Assert.Equal(
            ["Holy God", "Holy God", "Holy God", "Glory Be", "Holy God", "Holy God"],
            steps.Select(s => s.Title));
        Assert.Equal(
            [
                "trisagionAcclamation", "trisagionAcclamation", "trisagionAcclamation",
                "gloriaPatri", "trisagionShortAcclamation", "trisagionAcclamation",
            ],
            steps.Select(s => s.BodyKey));
    }

    /// <summary><see cref="PrayerPackStore.ResolveBodyText"/> step 1 — a bundle-local-only key
    /// (never a real <see cref="PrayerKey"/> constant) resolves from the bundle's own raw
    /// content.</summary>
    [Fact]
    public void ResolveBodyTextResolvesABundleLocalKey()
    {
        var text = PrayerPackStore.ResolveBodyText("trisagion", "en", "trisagionAcclamation");
        Assert.Equal("Holy God, Holy Mighty One, Holy Immortal One, have mercy on us.", text);
    }

    /// <summary><see cref="PrayerPackStore.ResolveBodyText"/> step 2 — a key matching a shared
    /// "main" key ("gloriaPatri", deliberately absent from every bundle) falls through to the
    /// ordinary hardcoded table.</summary>
    [Fact]
    public void ResolveBodyTextFallsThroughToASharedPrayerKey()
    {
        var text = PrayerPackStore.ResolveBodyText("trisagion", "en", "gloriaPatri");
        Assert.Equal(PrayerTranslations.Get("en", PrayerKey.GloriaPatri), text);
    }

    /// <summary><see cref="PrayerPackStore.ResolveBodyText"/> step 3 — an unresolvable key
    /// returns itself (the original camelCase form, not its PascalCased lookup), matching
    /// iOS/Android.</summary>
    [Fact]
    public void ResolveBodyTextFallsBackToTheRawKey()
    {
        var text = PrayerPackStore.ResolveBodyText("trisagion", "en", "notARealKey");
        Assert.Equal("notARealKey", text);
    }
}
