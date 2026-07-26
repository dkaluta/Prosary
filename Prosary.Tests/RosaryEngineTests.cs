using Prosary.Models;
using Prosary.Services;
using Xunit;

namespace Prosary.Tests;

public class RosaryEngineTests
{
    private readonly PrayerEngine _engine = new(new LiturgicalCalendarService());

    private static Prayer SpecificRosary(RosaryOptions? options = null) => new()
    {
        Kind = PrayerKind.Rosary,
        LanguageCode = "en",
        Rosary = options ?? new RosaryOptions
        {
            MysterySelectionMode = MysterySelectionMode.Specific,
            SpecificMysteryGroup = MysteryGroup.Joyful,
        },
    };

    [Fact]
    public void BuildSteps_SpecificGroup_HasFiveDecades()
    {
        var steps = _engine.BuildSteps(SpecificRosary());
        var decadeIndices = steps.Where(s => s.DecadeIndex.HasValue).Select(s => s.DecadeIndex!.Value).Distinct();
        Assert.Equal([0, 1, 2, 3, 4], decadeIndices.OrderBy(i => i));
    }

    [Fact]
    public void BuildSteps_FifteenMystery_HasFifteenDecades()
    {
        var prayer = SpecificRosary(new RosaryOptions { MysterySelectionMode = MysterySelectionMode.FifteenMystery });
        var steps = _engine.BuildSteps(prayer);
        var decadeIndices = steps.Where(s => s.DecadeIndex.HasValue).Select(s => s.DecadeIndex!.Value).Distinct();
        Assert.Equal(15, decadeIndices.Count());
        Assert.Equal(0, decadeIndices.Min());
        Assert.Equal(14, decadeIndices.Max());
    }

    [Fact]
    public void BuildSteps_TwentyMystery_HasTwentyDecades()
    {
        var prayer = SpecificRosary(new RosaryOptions { MysterySelectionMode = MysterySelectionMode.TwentyMystery });
        var steps = _engine.BuildSteps(prayer);
        var decadeIndices = steps.Where(s => s.DecadeIndex.HasValue).Select(s => s.DecadeIndex!.Value).Distinct();
        Assert.Equal(20, decadeIndices.Count());
    }

    [Fact]
    public void BuildSteps_EachDecade_HasTenHailMarys()
    {
        var steps = _engine.BuildSteps(SpecificRosary());
        for (var d = 0; d < 5; d++)
        {
            var hailMarys = steps.Where(s => s.DecadeIndex == d && s.HailMaryIndexInDecade.HasValue).ToList();
            Assert.Equal(10, hailMarys.Count);
            Assert.Equal(Enumerable.Range(1, 10), hailMarys.Select(s => s.HailMaryIndexInDecade!.Value));
        }
    }

    [Fact]
    public void BuildSteps_IncludeApostlesCreedFalse_OmitsCreedStep()
    {
        var prayer = SpecificRosary(new RosaryOptions
        {
            MysterySelectionMode = MysterySelectionMode.Specific,
            SpecificMysteryGroup = MysteryGroup.Joyful,
            IncludeApostlesCreed = false,
        });
        var steps = _engine.BuildSteps(prayer);
        Assert.DoesNotContain(steps, s => s.Title == "Apostles' Creed");
    }

    [Fact]
    public void BuildSteps_IncludeApostlesCreedTrue_IncludesCreedStep()
    {
        var prayer = SpecificRosary(new RosaryOptions
        {
            MysterySelectionMode = MysterySelectionMode.Specific,
            SpecificMysteryGroup = MysteryGroup.Joyful,
            IncludeApostlesCreed = true,
        });
        var steps = _engine.BuildSteps(prayer);
        Assert.Contains(steps, s => s.Title == "Apostles' Creed");
    }

    [Fact]
    public void BuildSteps_FinalSignOfCross_IsLastStepWhenIncluded()
    {
        var prayer = SpecificRosary(new RosaryOptions
        {
            MysterySelectionMode = MysterySelectionMode.Specific,
            SpecificMysteryGroup = MysteryGroup.Joyful,
            IncludeFinalSignOfCross = true,
        });
        var steps = _engine.BuildSteps(prayer);
        Assert.Equal("Sign of the Cross", steps[^1].Title);
    }

    [Fact]
    public void BuildSteps_FinalSignOfCross_OmittedWhenDisabled()
    {
        var prayer = SpecificRosary(new RosaryOptions
        {
            MysterySelectionMode = MysterySelectionMode.Specific,
            SpecificMysteryGroup = MysteryGroup.Joyful,
            IncludeFinalSignOfCross = false,
            MarianAntiphon = MarianAntiphonOption.None,
            IncludeStMichaelPrayer = false,
        });
        var steps = _engine.BuildSteps(prayer);
        Assert.NotEqual("Sign of the Cross", steps[^1].Title);
    }

    [Fact]
    public void BuildSteps_EternalRestAfterEachDecade_AddsOneStepPerDecade()
    {
        var prayer = SpecificRosary(new RosaryOptions
        {
            MysterySelectionMode = MysterySelectionMode.Specific,
            SpecificMysteryGroup = MysteryGroup.Joyful,
            EternalRestForDeceased = EternalRestPlacement.AfterEachDecade,
        });
        var steps = _engine.BuildSteps(prayer);
        Assert.Equal(5, steps.Count(s => s.Title == "For the Faithful Departed"));
    }

    [Fact]
    public void BuildSteps_EternalRestAtEndOnly_AddsExactlyOneStep()
    {
        var prayer = SpecificRosary(new RosaryOptions
        {
            MysterySelectionMode = MysterySelectionMode.Specific,
            SpecificMysteryGroup = MysteryGroup.Joyful,
            EternalRestForDeceased = EternalRestPlacement.AtEndOnly,
        });
        var steps = _engine.BuildSteps(prayer);
        Assert.Single(steps.Where(s => s.Title == "For the Faithful Departed"));
    }

    [Fact]
    public void BuildSteps_MarianAntiphonNone_HasNoAntiphonStep()
    {
        var prayer = SpecificRosary(new RosaryOptions
        {
            MysterySelectionMode = MysterySelectionMode.Specific,
            SpecificMysteryGroup = MysteryGroup.Joyful,
            MarianAntiphon = MarianAntiphonOption.None,
        });
        var steps = _engine.BuildSteps(prayer);
        Assert.DoesNotContain(steps, s => s.IsAntiphon);
    }

    [Fact]
    public void BuildSteps_MarianAntiphonSalveRegina_AddsExactlyOneAntiphonStep()
    {
        var prayer = SpecificRosary(new RosaryOptions
        {
            MysterySelectionMode = MysterySelectionMode.Specific,
            SpecificMysteryGroup = MysteryGroup.Joyful,
            MarianAntiphon = MarianAntiphonOption.SalveRegina,
        });
        var steps = _engine.BuildSteps(prayer);
        var antiphonSteps = steps.Where(s => s.IsAntiphon).ToList();
        Assert.Single(antiphonSteps);
        Assert.Equal("Hail, Holy Queen (Salve Regina)", antiphonSteps[0].Title);
    }

    [Fact]
    public void ResolveMysteryGroups_Specific_ReturnsSingleChosenGroup()
    {
        var prayer = SpecificRosary(new RosaryOptions
        {
            MysterySelectionMode = MysterySelectionMode.Specific,
            SpecificMysteryGroup = MysteryGroup.Sorrowful,
        });
        Assert.Equal([MysteryGroup.Sorrowful], _engine.ResolveMysteryGroups(prayer));
    }

    [Fact]
    public void ResolveMysteryGroups_TwentyMystery_IsChronologicalOrder()
    {
        var prayer = SpecificRosary(new RosaryOptions { MysterySelectionMode = MysterySelectionMode.TwentyMystery });
        Assert.Equal(
            [MysteryGroup.Joyful, MysteryGroup.Luminous, MysteryGroup.Sorrowful, MysteryGroup.Glorious],
            _engine.ResolveMysteryGroups(prayer));
    }
}
