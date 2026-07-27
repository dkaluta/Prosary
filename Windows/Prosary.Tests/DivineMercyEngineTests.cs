using Prosary.Models;
using Prosary.Services;
using Xunit;

namespace Prosary.Tests;

/// <summary>Mirrors iOS's DivineMercyEngineTests.swift / Android's DivineMercyEngineTest.kt.</summary>
public class DivineMercyEngineTests
{
    private readonly PrayerEngine _engine = new(new LiturgicalCalendarService());

    private static IReadOnlyList<RosaryStep> BuildSteps(PrayerEngine engine, string? languageCode) =>
        engine.BuildSteps(new Prayer { Kind = PrayerKind.DivineMercyChaplet, LanguageCode = languageCode ?? LanguageCatalog.DefaultSentinel });

    [Fact]
    public void BuildSteps_FiveDecadesOfTenPetitions()
    {
        var steps = BuildSteps(_engine, "en");
        var decadeIndices = steps.Where(s => s.DecadeIndex.HasValue).Select(s => s.DecadeIndex!.Value).Distinct();
        Assert.Equal(Enumerable.Range(0, 5), decadeIndices.OrderBy(i => i));

        for (var d = 0; d < 5; d++)
        {
            var petitionsInDecade = steps.Count(s => s.DecadeIndex == d && s.HailMaryIndexInDecade.HasValue);
            Assert.Equal(10, petitionsInDecade);
        }
    }

    [Fact]
    public void BuildSteps_NoStepHasAMystery()
    {
        var steps = BuildSteps(_engine, "en");
        Assert.All(steps, s => Assert.Null(s.Mystery));
    }

    [Fact]
    public void BuildSteps_EveryStepReusesTheSingleDivineMercyImage()
    {
        // Unlike the Rosary/Franciscan Crown/Seven Sorrows, every step — opening, decades, and
        // closing alike — reuses the one divine_mercy_image illustration (the same reuse pattern
        // the Angelus uses for joyful_01_annunciation), since there's no per-decade content to
        // illustrate separately.
        var steps = BuildSteps(_engine, "en");
        Assert.All(steps, s => Assert.Equal("divine_mercy_image", s.ImageOverrideKey));
    }

    [Fact]
    public void BuildSteps_OfferingIsRepeatedIdenticallyAcrossEveryDecade()
    {
        var steps = BuildSteps(_engine, "en");
        var offerings = steps.Where(s => s.DecadeIndex.HasValue && !s.HailMaryIndexInDecade.HasValue).ToList();
        Assert.Equal(5, offerings.Count);
        Assert.All(offerings, s => Assert.Contains("Eternal Father, I offer You", s.Body));
    }

    [Fact]
    public void BuildSteps_OpeningReusesExistingPrayersNotNewContent()
    {
        var steps = BuildSteps(_engine, "en");
        Assert.Equal("Sign of the Cross", steps[0].Title);
        Assert.Equal("Our Father", steps[1].Title);
        Assert.Equal("Hail Mary", steps[2].Title);
        Assert.Equal("The Apostles' Creed", steps[3].Title);
    }

    [Fact]
    public void BuildSteps_ClosingAcclamationRepeatedThreeTimesThenClosingCross()
    {
        var steps = BuildSteps(_engine, "en");
        var closingAcclamations = steps.Where(s => !s.DecadeIndex.HasValue && s.Body.Contains("Holy God")).ToList();
        Assert.Equal(3, closingAcclamations.Count);
        Assert.Equal("Sign of the Cross", steps[^1].Title);
    }

    [Fact]
    public void BuildSteps_EnglishBodyContainsEnglishText()
    {
        var steps = BuildSteps(_engine, "en");
        Assert.Contains(steps, s => s.Body.Contains("For the sake of His sorrowful Passion"));
    }

    [Fact]
    public void BuildSteps_LatinBodyContainsLatinText()
    {
        var steps = BuildSteps(_engine, "la");
        Assert.Contains(steps, s => s.Body.Contains("Pro dolorosa Eius passione"));
    }
}
