using Prosary.Localization;
using Prosary.Models;
using Prosary.Services;
using Xunit;

namespace Prosary.Tests;

/// <summary>
/// PrayerEngine.BuildCustomDevotionSteps is the one generic builder behind every PrayerKind.Custom
/// devotion; these tests exercise it via the actual bundled trisagion.prosaryprayer (produced by
/// Shared/tools/make-prosaryprayer.sh from Shared/content/trisagion) rather than a fixture, the
/// same convention PrayerPackLoaderTests uses for Rosary/Angelus. Mirrors iOS's
/// CustomDevotionEngineTests.swift / Android's CustomDevotionEngineTest.kt.
/// </summary>
public class CustomDevotionEngineTests : IClassFixture<PrayerPackLoaderFixture>
{
    public CustomDevotionEngineTests(PrayerPackLoaderFixture _)
    {
    }

    private static IReadOnlyList<RosaryStep> BuildSteps(
        string bundleId, string? languageCode,
        bool isEasterSeason = false,
        MarianAntiphonOption seasonalAntiphon = MarianAntiphonOption.SalveRegina) =>
        PrayerEngine.BuildCustomDevotionSteps(bundleId, languageCode, isEasterSeason, seasonalAntiphon);

    [Fact]
    public void TrisagionProducesTheSixStepSequence()
    {
        var steps = BuildSteps("trisagion", "en");

        Assert.Equal(6, steps.Count);
        Assert.Equal(
            ["Holy God", "Holy God", "Holy God", "Glory Be", "Holy God", "Holy God"],
            steps.Select(s => s.Title));
        Assert.Contains("Holy God, Holy Mighty One, Holy Immortal One", steps[0].Body);
        Assert.Contains("Glory be to the Father", steps[3].Body);
        Assert.Contains("Holy Immortal One, have mercy on us.", steps[4].Body);
        Assert.DoesNotContain("Holy Mighty One", steps[4].Body);
    }

    [Fact]
    public void TrisagionImagesMatchTheDevotionJsonImageKeys()
    {
        var steps = BuildSteps("trisagion", "en");

        Assert.Equal(
            ["jesus_portrait", "jesus_portrait", "jesus_portrait", "glory_be", "jesus_portrait", "jesus_portrait"],
            steps.Select(s => s.ImageOverrideKey));
    }

    [Fact]
    public void UnknownBundleIdProducesNoSteps()
    {
        var steps = BuildSteps("not-a-real-bundle", "en");
        Assert.Empty(steps);
    }
}
