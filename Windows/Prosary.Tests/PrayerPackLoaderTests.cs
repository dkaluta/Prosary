using Prosary.Localization;
using Xunit;

namespace Prosary.Tests;

/// <summary>
/// Proves the whole .prosaryprayer pipeline end-to-end against the actual bundled
/// rosary.prosaryprayer/angelus.prosaryprayer files (produced by Shared/tools/make-prosaryprayer.sh
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
    public void AngelusPackProvidedKeyOverridesHebrewText()
    {
        var text = PrayerTranslations.Get("he", PrayerKey.CollectaAngelus);
        Assert.False(string.IsNullOrEmpty(text));
        Assert.StartsWith("נִתְפַּלְּלָה", text);
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

    /// <summary>A devotion with no shipped pack at all (Stations) must be completely unaffected.</summary>
    [Fact]
    public void UnmigratedDevotionKeyStillResolvesFromHardcodedTable()
    {
        var text = PrayerTranslations.Get("en", PrayerKey.StationsOpeningPrayer);
        Assert.Equal(
            "My Lord Jesus Christ, You made this journey to die for me with unspeakable love, and I have so many times unworthily abandoned You. But now I love You with all my heart, and, because I love You, I am sincerely sorry for ever having offended You. Pardon me, my God, for the sake of the merits of Your bitter Passion, and grant me the grace to accompany You in this journey with true contrition for my sins, that I may attain to a happy eternity. Amen.",
            text);
    }

    [Fact]
    public void RosaryPackProvidesImageDataForAMysteryKey()
    {
        var data = PrayerPackStore.ImageData("joyful_01_annunciation");
        Assert.NotNull(data);
        Assert.True(data!.Length > 0);
    }

    [Fact]
    public void PackProvidesNoImageDataForAnUnrelatedKey()
    {
        Assert.Null(PrayerPackStore.ImageData("station_01_condemned_to_death"));
    }

    // Generic (bundle-driven) devotions

    [Fact]
    public void TrisagionIsDiscoveredAsACustomDevotion()
    {
        Assert.Contains("trisagion", PrayerPackStore.CustomDevotionIds());
    }

    /// <summary>A devotion with no steps.json at all (Rosary/Angelus) is never mistaken for a
    /// generic one.</summary>
    [Fact]
    public void PacksWithNoStepsJsonAreNotCustomDevotions()
    {
        Assert.DoesNotContain("rosary", PrayerPackStore.CustomDevotionIds());
        Assert.DoesNotContain("angelus", PrayerPackStore.CustomDevotionIds());
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
    public void TrisagionStepsMatchTheAuthoredSixStepSequence()
    {
        var steps = PrayerPackStore.Steps("trisagion");
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

    /// <summary><see cref="PrayerPackStore.ResolveBodyText"/> resolving a bundle-local-only key
    /// (never a real <see cref="PrayerKey"/> constant) via the global override table it merges
    /// into at load time.</summary>
    [Fact]
    public void ResolveBodyTextResolvesABundleLocalKey()
    {
        var text = PrayerPackStore.ResolveBodyText("en", "trisagionAcclamation");
        Assert.Equal("Holy God, Holy Mighty One, Holy Immortal One, have mercy on us.", text);
    }

    /// <summary><see cref="PrayerPackStore.ResolveBodyText"/> falling through to a shared "main"
    /// key ("gloriaPatri", deliberately absent from every bundle) via the ordinary hardcoded
    /// table.</summary>
    [Fact]
    public void ResolveBodyTextFallsThroughToASharedPrayerKey()
    {
        var text = PrayerPackStore.ResolveBodyText("en", "gloriaPatri");
        Assert.Equal(PrayerTranslations.Get("en", PrayerKey.GloriaPatri), text);
    }

    /// <summary><see cref="PrayerPackStore.ResolveBodyText"/> falling back to the raw key,
    /// matching <see cref="PrayerTranslations.Get"/>'s own last-resort fallback.</summary>
    [Fact]
    public void ResolveBodyTextFallsBackToTheRawKey()
    {
        var text = PrayerPackStore.ResolveBodyText("en", "NotARealKey");
        Assert.Equal("NotARealKey", text);
    }
}
