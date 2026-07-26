using Prosary.Models;
using Prosary.Services;
using Xunit;

namespace Prosary.Tests;

/// <summary>Mirrors iOS's SevenSorrowsEngineTests.swift / Android's SevenSorrowsEngineTest.kt.</summary>
public class SevenSorrowsEngineTests
{
    private readonly PrayerEngine _engine = new(new LiturgicalCalendarService());

    private static IReadOnlyList<RosaryStep> BuildSteps(PrayerEngine engine, string? languageCode) =>
        engine.BuildSteps(new Prayer { Kind = PrayerKind.SevenSorrows, LanguageCode = languageCode ?? LanguageCatalog.DefaultSentinel });

    [Fact]
    public void BuildSteps_SevenDecadesOfSevenHailMarys()
    {
        var steps = BuildSteps(_engine, "en");
        var decadeIndices = steps.Where(s => s.DecadeIndex.HasValue).Select(s => s.DecadeIndex!.Value).Distinct();
        Assert.Equal(Enumerable.Range(0, 7), decadeIndices.OrderBy(i => i));

        for (var d = 0; d < 7; d++)
        {
            var hailMarysInDecade = steps.Count(s => s.DecadeIndex == d && s.HailMaryIndexInDecade.HasValue);
            Assert.Equal(7, hailMarysInDecade);
        }
    }

    [Fact]
    public void BuildSteps_NoStepHasAMystery()
    {
        // Seven Sorrows steps deliberately leave Mystery null (see BeadLayout's generalization)
        // — the Seven Sorrows aren't Rosary "mysteries", and unlike Franciscan Crown, none of the
        // seven reuse an existing mystery imageKey either.
        var steps = BuildSteps(_engine, "en");
        Assert.All(steps, s => Assert.Null(s.Mystery));
    }

    [Fact]
    public void BuildSteps_ThreeClosingHailMarysForOurLadysTears()
    {
        var steps = BuildSteps(_engine, "en");
        var nonDecadeHailMarys = steps.Count(s => !s.DecadeIndex.HasValue && s.Title.StartsWith("Hail Mary"));
        Assert.Equal(3, nonDecadeHailMarys);
    }

    [Fact]
    public void BuildSteps_EndsWithClosingPrayerThenClosingCross()
    {
        var steps = BuildSteps(_engine, "en");
        Assert.Equal("Our Lady of Sorrows", steps[^2].Title);
        Assert.Equal("Sign of the Cross", steps[^1].Title);
    }

    [Fact]
    public void BuildSteps_FirstSorrowIsProphecyOfSimeon()
    {
        var steps = BuildSteps(_engine, "en");
        var firstSorrow = steps.First(s => s.DecadeIndex == 0 && !s.HailMaryIndexInDecade.HasValue && s.Title != "Our Father");
        Assert.Equal("The Prophecy of Simeon", firstSorrow.Title);
        Assert.Equal("seven_sorrows_01_prophecy_of_simeon", firstSorrow.ImageOverrideKey);
        Assert.True(firstSorrow.IsScripture);
    }

    [Fact]
    public void BuildSteps_FourthSorrowHasNoScriptureCitation()
    {
        // "Mary Meets Jesus on the Way of the Cross" isn't narrated in any Gospel — a
        // traditional devotional scene, not a quoted verse — so unlike the other six, it's not
        // IsScripture.
        var steps = BuildSteps(_engine, "en");
        var fourthSorrow = steps.First(s => s.DecadeIndex == 3 && !s.HailMaryIndexInDecade.HasValue && s.Title != "Our Father");
        Assert.Equal("Mary Meets Jesus on the Way of the Cross", fourthSorrow.Title);
        Assert.False(fourthSorrow.IsScripture);
    }

    [Fact]
    public void BuildSteps_EnglishBodyContainsEnglishText()
    {
        var steps = BuildSteps(_engine, "en");
        Assert.Contains(steps, s => s.Body.Contains("Hail Mary, full of grace"));
    }

    [Fact]
    public void BuildSteps_LatinBodyContainsLatinText()
    {
        var steps = BuildSteps(_engine, "la");
        Assert.Contains(steps, s => s.Body.Contains("Ave Maria, gratia plena"));
    }
}
