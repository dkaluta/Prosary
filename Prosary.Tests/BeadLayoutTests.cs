using Prosary.Models;
using Prosary.Services;
using Prosary.ViewModels;
using Xunit;

namespace Prosary.Tests;

/// <summary>Mirrors iOS's BeadModelsTests.swift / Android's BeadModelsTest.kt.</summary>
public class BeadLayoutTests
{
    /// <summary>Synthesizes a decade-based session with no Mystery at all — the shape every one
    /// of Franciscan Crown/Seven Sorrows/Divine Mercy Chaplet's steps has (unlike the Rosary,
    /// which always sets Mystery). Before the bead-track generalization, BeadLayout.Build
    /// silently produced zero GroupColumns for a session like this instead of one ungrouped
    /// column.</summary>
    private static List<RosaryStep> MysteryLessDecadeSteps(int decadeCount)
    {
        var steps = new List<RosaryStep> { new("Opening", null, "") };
        for (var d = 0; d < decadeCount; d++)
        {
            steps.Add(new RosaryStep("Our Father", null, "", DecadeIndex: d));
            for (var h = 1; h <= 10; h++)
            {
                steps.Add(new RosaryStep("Hail Mary", null, "", DecadeIndex: d, HailMaryIndexInDecade: h));
            }
        }
        return steps;
    }

    [Fact]
    public void Build_MysteryLessDecadeSteps_ProducesOneUngroupedColumn()
    {
        var steps = MysteryLessDecadeSteps(3);
        var layout = BeadLayout.Build(steps, currentIndex: steps.Count / 2, hasClosingCross: false, isDarkTheme: false);

        Assert.Single(layout.GroupColumns);
        Assert.Null(layout.GroupColumns[0].Group);
        Assert.Equal(3, layout.GroupColumns[0].Beads.Count);
    }

    [Fact]
    public void Build_MysteryLessDecadeSteps_KeepsDecadesInOrder()
    {
        var steps = MysteryLessDecadeSteps(3);
        var currentIndex = steps.FindIndex(s => s.DecadeIndex == 1 && s.HailMaryIndexInDecade == 5);
        var layout = BeadLayout.Build(steps, currentIndex, hasClosingCross: false, isDarkTheme: false);

        var beads = layout.GroupColumns[0].Beads;
        Assert.Equal(3, beads.Count);
        Assert.Equal(BeadState.Completed, beads[0].State);
        Assert.Equal(BeadState.Current, beads[1].State);
        Assert.Equal(BeadState.Upcoming, beads[2].State);
    }

    [Fact]
    public void Build_MysteryLessDecadeSteps_StillPopulatesBottomBeads()
    {
        var steps = MysteryLessDecadeSteps(1);
        var currentIndex = steps.FindIndex(s => s.HailMaryIndexInDecade == 4);
        var layout = BeadLayout.Build(steps, currentIndex, hasClosingCross: false, isDarkTheme: false);

        Assert.True(layout.ShowBottomBeads);
        Assert.Equal(10, layout.BottomBeads.Count);
        Assert.Equal(BeadState.Current, layout.BottomBeads[3].State);
    }

    /// <summary>Sanity check that the existing Rosary-shaped (mystery-grouped) behavior is
    /// unaffected by the generalization — still one column per distinct MysteryGroup in session
    /// order.</summary>
    [Fact]
    public void Build_MysteryGroupedSteps_StillGroupsByMysteryGroup()
    {
        var engine = new RosaryEngine(new LiturgicalCalendarService());
        var prayer = new Prayer { Rosary = new RosaryOptions { MysterySelectionMode = MysterySelectionMode.TwentyMystery } };
        var steps = engine.BuildSteps(prayer);
        var layout = BeadLayout.Build(steps, currentIndex: steps.Count / 2, hasClosingCross: true, isDarkTheme: false);

        Assert.Equal(4, layout.GroupColumns.Count);
        Assert.Equal(
            [MysteryGroup.Joyful, MysteryGroup.Luminous, MysteryGroup.Sorrowful, MysteryGroup.Glorious],
            layout.GroupColumns.Select(c => c.Group));
    }
}
