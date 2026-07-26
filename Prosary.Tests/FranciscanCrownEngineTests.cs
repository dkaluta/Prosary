using Prosary.Models;
using Prosary.Services;
using Xunit;

namespace Prosary.Tests;

/// <summary>Mirrors iOS's FranciscanCrownEngineTests.swift / Android's FranciscanCrownEngineTest.kt.</summary>
public class FranciscanCrownEngineTests
{
    private readonly FranciscanCrownEngine _engine = new(new LiturgicalCalendarService());

    [Fact]
    public void BuildSteps_SevenDecadesOfTenHailMarys()
    {
        var steps = _engine.BuildSteps("en");
        var decadeIndices = steps.Where(s => s.DecadeIndex.HasValue).Select(s => s.DecadeIndex!.Value).Distinct();
        Assert.Equal(Enumerable.Range(0, 7), decadeIndices.OrderBy(i => i));

        for (var d = 0; d < 7; d++)
        {
            var hailMarysInDecade = steps.Count(s => s.DecadeIndex == d && s.HailMaryIndexInDecade.HasValue);
            Assert.Equal(10, hailMarysInDecade);
        }
    }

    [Fact]
    public void BuildSteps_NoStepHasAMystery()
    {
        // Franciscan Crown steps deliberately leave Mystery null (see BeadLayout's
        // generalization) — the Seven Joys aren't Rosary "mysteries" even though 6 of the 7
        // reuse mystery imageKeys.
        var steps = _engine.BuildSteps("en");
        Assert.All(steps, s => Assert.Null(s.Mystery));
    }

    [Fact]
    public void BuildSteps_TwoClosingHailMarysAndOneClosingOurFather()
    {
        var steps = _engine.BuildSteps("en");
        var nonDecadeHailMarys = steps.Count(s => !s.DecadeIndex.HasValue && s.Title.StartsWith("Hail Mary"));
        Assert.Equal(2, nonDecadeHailMarys);

        var nonDecadeOurFathers = steps.Count(s => !s.DecadeIndex.HasValue && s.Title == "Our Father");
        Assert.Equal(1, nonDecadeOurFathers);
    }

    [Fact]
    public void BuildSteps_EndsWithAntiphonThenClosingCross()
    {
        var steps = _engine.BuildSteps("en");
        Assert.True(steps[^2].IsAntiphon);
        Assert.Equal("Sign of the Cross", steps[^1].Title);
    }

    [Fact]
    public void BuildSteps_FirstJoyIsAnnunciationReusingExistingMysteryContent()
    {
        var steps = _engine.BuildSteps("en");
        var firstJoy = steps.First(s => s.DecadeIndex == 0 && s.IsScripture);
        Assert.Equal("The Annunciation", firstJoy.Title);
        Assert.Equal("joyful_01_annunciation", firstJoy.ImageKey);
    }

    [Fact]
    public void BuildSteps_FourthJoyIsTheNewAdorationOfTheMagiContent()
    {
        var steps = _engine.BuildSteps("en");
        var fourthJoy = steps.First(s => s.DecadeIndex == 3 && s.IsScripture);
        Assert.Equal("The Adoration of the Magi", fourthJoy.Title);
        Assert.Equal("franciscan_04_adoration_of_the_magi", fourthJoy.ImageKey);
    }

    [Fact]
    public void BuildSteps_EnglishBodyContainsEnglishText()
    {
        var steps = _engine.BuildSteps("en");
        Assert.Contains(steps, s => s.Body.Contains("Hail Mary, full of grace"));
    }

    [Fact]
    public void BuildSteps_LatinBodyContainsLatinText()
    {
        var steps = _engine.BuildSteps("la");
        Assert.Contains(steps, s => s.Body.Contains("Ave Maria, gratia plena"));
    }
}
