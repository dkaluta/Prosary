using Prosary.Localization;
using Prosary.Models;
using Prosary.Services;
using Xunit;

namespace Prosary.Tests;

/// <summary>
/// PrayerEngine.BuildCustomDevotionSteps is the one generic builder behind every
/// PrayerKind.Custom devotion. These tests exercise it via the real shipped bundles (produced by
/// Shared/tools/make-prosaryprayer.sh from Shared/content/) and carry over the per-devotion
/// assertions from the five deleted hardcoded-engine test files — the step sequences must be
/// byte-for-byte what the hardcoded builders used to emit. Mirrors iOS's
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

    // Trisagion (flat)

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

    // Angelus (flat + Eastertide swap)

    [Fact]
    public void AngelusStandardFormOutsideEastertide()
    {
        var steps = BuildSteps("angelus", "en");

        Assert.Equal(7, steps.Count);
        Assert.Equal(
            [
                "The Annunciation", "Hail Mary",
                "The Fiat", "Hail Mary",
                "The Incarnation", "Hail Mary",
                "Let Us Pray",
            ],
            steps.Select(s => s.Title));
        Assert.Contains("The Angel of the Lord declared unto Mary", steps[0].Body);
        Assert.Contains("**And she conceived of the Holy Spirit.**", steps[0].Body);
        Assert.Contains("Hail Mary, full of grace", steps[1].Body);
        Assert.Contains("Pour forth, we beseech Thee", steps[^1].Body);
        Assert.DoesNotContain(steps, s => s.Body.Contains("Queen of Heaven"));
        Assert.All(steps, s => Assert.Equal("joyful_01_annunciation", s.ImageOverrideKey));
    }

    [Fact]
    public void AngelusReginaCaeliSubstitutionDuringEastertide()
    {
        var steps = BuildSteps("angelus", "en", isEasterSeason: true);

        var step = Assert.Single(steps);
        Assert.Equal("Regina Caeli", step.Title);
        Assert.Contains("Queen of Heaven, rejoice", step.Body);
        Assert.Contains("Rejoice and be glad, O Virgin Mary", step.Body);
        Assert.DoesNotContain("Pour forth, we beseech Thee", step.Body);
        Assert.Equal("madonna_and_child", step.ImageOverrideKey);
    }

    [Fact]
    public void AngelusFallsBackToLatinWhenLanguageIsUnknown()
    {
        var steps = BuildSteps("angelus", "xx");
        Assert.Contains("Angelus Domini nuntiavit Mariae", steps[0].Body);
    }

    // Stations of the Cross (flat, translated titles)

    [Fact]
    public void StationsProducesSeventeenStepsWithTranslatedTitlesAndOrdinals()
    {
        var steps = BuildSteps("stationsOfTheCross", "en");

        Assert.Equal(17, steps.Count);
        Assert.Equal("Sign of the Cross", steps[0].Title);
        Assert.Equal("Opening Prayer", steps[1].Title);
        Assert.Equal("Jesus is Condemned to Death", steps[2].Title);
        Assert.Equal("1st Station", steps[2].Subtitle);
        Assert.Equal("14th Station", steps[15].Subtitle);
        Assert.Equal("Closing Prayer", steps[^1].Title);
        Assert.Contains("We adore You, O Christ", steps[2].Body);
        Assert.Contains("**Because by Your holy Cross You have redeemed the world.**", steps[2].Body);
        Assert.Equal("station_01_condemned_to_death", steps[2].ImageOverrideKey);
        // No bead fields anywhere — Stations is a flat devotion.
        Assert.All(steps, s =>
        {
            Assert.Null(s.DecadeIndex);
            Assert.Null(s.HailMaryIndexInDecade);
        });
    }

    // Franciscan Crown (rosary type, 7×10 + antiphon)

    [Fact]
    public void FranciscanCrownNinetyStepSequence()
    {
        var steps = BuildSteps("franciscanCrown", "en");

        Assert.Equal(90, steps.Count);
        Assert.Equal("Sign of the Cross", steps[0].Title);
        // 7 decades of announce + Our Father + 10 Hail Marys.
        Assert.Equal(Enumerable.Range(0, 7), steps.Where(s => s.DecadeIndex.HasValue).Select(s => s.DecadeIndex!.Value).Distinct().OrderBy(i => i));
        Assert.Equal(10, steps.Where(s => s.HailMaryIndexInDecade.HasValue).Max(s => s.HailMaryIndexInDecade!.Value));
        // Joy 1 announcement reuses the shared Rosary mystery text/image cross-bundle.
        Assert.Equal("The Annunciation", steps[1].Title);
        Assert.Equal("1st Joy", steps[1].Subtitle);
        Assert.True(steps[1].IsScripture);
        Assert.Equal("joyful_01_annunciation", steps[1].ImageOverrideKey);
        // Joy 4 is the Crown's own Adoration of the Magi.
        var joy4 = steps.First(s => s.Subtitle == "4th Joy");
        Assert.Equal("The Adoration of the Magi", joy4.Title);
        Assert.Equal("franciscan_04_adoration_of_the_magi", joy4.ImageOverrideKey);
        // The Our Father inside a decade uses the decade's own art (unlike the Rosary).
        Assert.Equal("Our Father", steps[2].Title);
        Assert.Equal("joyful_01_annunciation", steps[2].ImageOverrideKey);
        // Closing (opening 1 + 7×12 decades = indices 0…84): 2 Hail Marys + Our Father +
        // seasonal antiphon + cross.
        Assert.Equal("Hail Mary (1 of 2)", steps[85].Title);
        Assert.Equal("For the years of Our Lady's life", steps[85].Subtitle);
        Assert.Null(steps[85].DecadeIndex);
        Assert.Null(steps[85].HailMaryIndexInDecade);
        Assert.Equal("Our Father", steps[87].Title);
        Assert.Equal("For the intentions of the Holy Father", steps[87].Subtitle);
        Assert.True(steps[88].IsAntiphon);
        Assert.Equal("madonna_and_child", steps[88].ImageOverrideKey);
        Assert.Equal("Sign of the Cross", steps[^1].Title);
    }

    [Fact]
    public void FranciscanCrownAntiphonFollowsTheSeason()
    {
        var paschal = BuildSteps("franciscanCrown", "en", seasonalAntiphon: MarianAntiphonOption.ReginaCaeli);
        Assert.Equal("Regina Caeli", paschal[88].Title);
        Assert.True(paschal[88].IsAntiphon);
    }

    // Seven Sorrows (rosary type, 7×7)

    [Fact]
    public void SevenSorrowsSixtyNineStepSequence()
    {
        var steps = BuildSteps("sevenSorrows", "en");

        Assert.Equal(69, steps.Count);
        Assert.Equal(Enumerable.Range(0, 7), steps.Where(s => s.DecadeIndex.HasValue).Select(s => s.DecadeIndex!.Value).Distinct().OrderBy(i => i));
        Assert.Equal(7, steps.Where(s => s.HailMaryIndexInDecade.HasValue).Max(s => s.HailMaryIndexInDecade!.Value));
        Assert.Equal("The Prophecy of Simeon", steps[1].Title);
        Assert.Equal("1st Sorrow", steps[1].Subtitle);
        // The Meeting on the Way (4th sorrow) is the one traditional non-Gospel scene.
        var announcements = steps.Where(s => s.DecadeIndex.HasValue && !s.HailMaryIndexInDecade.HasValue && s.Title != "Our Father").ToList();
        Assert.Equal(7, announcements.Count);
        Assert.False(announcements[3].IsScripture);
        Assert.All(announcements.Where((_, i) => i != 3), a => Assert.True(a.IsScripture));
        // Closing: 3 Hail Marys for the tears, the composed Our Lady of Sorrows body, cross.
        Assert.Equal("Hail Mary (1 of 3)", steps[64].Title);
        Assert.Equal("For the tears of Our Lady", steps[64].Subtitle);
        Assert.Equal("Our Lady of Sorrows", steps[67].Title);
        Assert.Contains("**That we may be made worthy of the promises of Christ.**", steps[67].Body);
        Assert.DoesNotContain(steps, s => s.IsAntiphon);
        Assert.Equal("Sign of the Cross", steps[^1].Title);
    }

    /// <summary>The sorrow texts live only in the bundle (they were deleted from the hardcoded
    /// tables) — a language the bundle doesn't declare must fall back to the bundle's Latin
    /// mysteries, not leak raw imageKeys as titles.</summary>
    [Fact]
    public void SevenSorrowsFallsBackToBundleLatinForAnUndeclaredLanguage()
    {
        var steps = BuildSteps("sevenSorrows", "xx");
        Assert.Equal("Simeonis Prophetia", steps[1].Title);
    }

    // Divine Mercy Chaplet (rosary type, no announcements, fixed image)

    [Fact]
    public void DivineMercySixtyThreeStepSequence()
    {
        var steps = BuildSteps("divineMercyChaplet", "en");

        Assert.Equal(63, steps.Count);
        Assert.Equal(
            ["Sign of the Cross", "Our Father", "Hail Mary", "The Apostles' Creed"],
            steps.Take(4).Select(s => s.Title));
        Assert.Equal(Enumerable.Range(0, 5), steps.Where(s => s.DecadeIndex.HasValue).Select(s => s.DecadeIndex!.Value).Distinct().OrderBy(i => i));
        Assert.Equal("Eternal Father, I Offer You...", steps[4].Title);
        Assert.Equal("1st Decade", steps[4].Subtitle);
        Assert.Equal("For the Sake of His Sorrowful Passion (1 of 10)", steps[5].Title);
        Assert.Equal("Holy God, Holy Mighty One, Holy Immortal One (1 of 3)", steps[59].Title);
        Assert.Null(steps[59].DecadeIndex);
        Assert.Equal("Sign of the Cross", steps[^1].Title);
        // Every step reuses the single Divine Mercy image.
        Assert.All(steps, s => Assert.Equal("divine_mercy_image", s.ImageOverrideKey));
    }

    // Structural guards

    [Fact]
    public void UnknownBundleIdProducesNoSteps()
    {
        var steps = BuildSteps("not-a-real-bundle", "en");
        Assert.Empty(steps);
    }

    /// <summary>The bead track assumes the closing cross is the literal last step and decade
    /// indices are dense — guard every shipped rosary-type bundle at once.</summary>
    [Fact]
    public void EveryRosaryTypeBundleSatisfiesTheBeadTrackInvariants()
    {
        foreach (var bundleId in PrayerPackStore.CustomDevotionIds())
        {
            var definition = PrayerPackStore.Definition(bundleId);
            Assert.NotNull(definition);
            if (definition!.Type != CustomDevotionDefinition.DevotionType.Rosary)
            {
                continue;
            }

            var steps = BuildSteps(bundleId, "en");
            Assert.True(steps[0].Title == "Sign of the Cross", $"{bundleId}: opening cross must be step 0");
            if (definition.HasClosingCross == true)
            {
                Assert.True(steps[^1].Title == "Sign of the Cross", $"{bundleId}: closing cross must be last");
            }

            var indices = steps.Where(s => s.DecadeIndex.HasValue).Select(s => s.DecadeIndex!.Value).ToList();
            Assert.True(
                indices.ToHashSet().SetEquals(Enumerable.Range(0, indices.Max() + 1)),
                $"{bundleId}: decadeIndex must be dense");
            Assert.True(steps.Count(s => s.IsAntiphon) <= 1, $"{bundleId}: at most one antiphon");
            // Minors carry indices; announcements/majors never do.
            foreach (var step in steps.Where(s => s.HailMaryIndexInDecade.HasValue))
            {
                Assert.True(step.DecadeIndex.HasValue, $"{bundleId}: minor steps must sit inside a decade");
            }
        }
    }
}
