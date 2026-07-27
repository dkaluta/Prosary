using Prosary.Models;
using Prosary.Services;
using Xunit;

namespace Prosary.Tests;

/// <summary>Mirrors iOS's StationsEngineTests.swift / Android's StationsEngineTest.kt.</summary>
public class StationsEngineTests
{
    private readonly PrayerEngine _engine = new(new LiturgicalCalendarService());

    private IReadOnlyList<RosaryStep> BuildSteps(string? languageCode) =>
        _engine.BuildSteps(new Prayer { Kind = PrayerKind.StationsOfTheCross, LanguageCode = languageCode ?? LanguageCatalog.DefaultSentinel });

    [Fact]
    public void BuildSteps_OpeningPrayerThenFourteenStationsThenClosingPrayer()
    {
        var steps = BuildSteps("en");
        Assert.Equal("Sign of the Cross", steps[0].Title);
        Assert.Equal("Opening Prayer", steps[1].Title);
        Assert.Equal("Closing Prayer", steps[^1].Title);

        var stationSteps = steps.Skip(2).SkipLast(1).ToList();
        Assert.Equal(14, stationSteps.Count);
    }

    [Fact]
    public void BuildSteps_StationsAreInOrderWithCorrectOrdinalSubtitles()
    {
        var stationSteps = BuildSteps("en").Skip(2).SkipLast(1).ToList();
        Assert.Equal("1st Station", stationSteps[0].Subtitle);
        Assert.Equal("14th Station", stationSteps[13].Subtitle);
    }

    [Fact]
    public void BuildSteps_NoStepHasABeadTrackShape()
    {
        // Stations has no decades/beads — the flow UI shows a plain progress bar instead (see
        // ARCHITECTURE.md's "Bead progress track" section).
        var steps = BuildSteps("en");
        Assert.All(steps, s => Assert.True(s.Mystery is null && s.DecadeIndex is null && s.HailMaryIndexInDecade is null));
    }

    [Fact]
    public void BuildSteps_EachStationBodyContainsTheSharedVersicleAndResponse()
    {
        var stationSteps = BuildSteps("en").Skip(2).SkipLast(1);
        Assert.All(stationSteps, s =>
        {
            Assert.Contains("We adore You, O Christ, and we bless You", s.Body);
            Assert.Contains("Because by Your holy Cross You have redeemed the world", s.Body);
        });
    }

    [Fact]
    public void BuildSteps_FirstStationIsCondemnedToDeath()
    {
        var firstStation = BuildSteps("en").Skip(2).First();
        Assert.Equal("Jesus is Condemned to Death", firstStation.Title);
        Assert.Equal("station_01_condemned_to_death", firstStation.ImageOverrideKey);
    }

    [Fact]
    public void BuildSteps_EnglishBodyContainsEnglishText()
    {
        Assert.Contains(BuildSteps("en"), s => s.Body.Contains("We adore You"));
    }

    [Fact]
    public void BuildSteps_LatinBodyContainsLatinText()
    {
        Assert.Contains(BuildSteps("la"), s => s.Body.Contains("Adoramus te, Christe"));
    }
}
