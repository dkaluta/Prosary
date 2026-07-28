using Prosary.Models;
using Prosary.Services;
using Prosary.ViewModels;
using Xunit;

namespace Prosary.Tests;

/// <summary>Mirrors iOS's BeadModelsTests.swift / Android's BeadModelsTest.kt.</summary>
/// <summary>Needs the pack fixture: the Rosary-shaped cases build real steps through
/// PrayerEngine, which reads the rosary bundle's devotion.json.</summary>
public class BeadLayoutTests : IClassFixture<PrayerPackLoaderFixture>
{
    public BeadLayoutTests(PrayerPackLoaderFixture _)
    {
    }

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
        var currentIndex = steps.ToList().FindIndex(s => s.HailMaryIndexInDecade == 4);
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
        var engine = new PrayerEngine(new LiturgicalCalendarService());
        // Explicit language: resolving the default-language sentinel reads ApplicationData,
        // which only exists in a packaged app — same convention as RosaryEngineTests.
        var prayer = new Prayer { LanguageCode = "en", Rosary = new RosaryOptions { MysterySelectionMode = MysterySelectionMode.TwentyMystery } };
        var steps = engine.BuildSteps(prayer);
        var layout = BeadLayout.Build(steps, currentIndex: steps.Count / 2, hasClosingCross: true, isDarkTheme: false);

        Assert.Equal(4, layout.GroupColumns.Count);
        Assert.Equal(
            [MysteryGroup.Joyful, MysteryGroup.Luminous, MysteryGroup.Sorrowful, MysteryGroup.Glorious],
            layout.GroupColumns.Select(c => c.Group));
    }

    /// <summary>Presenter mode collapses each decade's 10 Hail Marys + Glory Be into one step
    /// carrying HailMaryIndexInDecade: 10 specifically so the bead track still shows the
    /// traditional 10-bead-per-decade look (beads 1-9 completed, bead 10 current) instead of
    /// collapsing to a single bead — see PrayerEngine.BuildRosarySteps' presenter-mode branch.
    /// This is the crux of that design decision, even though BeadLayout itself needed no code
    /// changes to support it.</summary>
    [Fact]
    public void Build_PresenterModeStep_StillShowsTenTraditionalBottomBeads()
    {
        var engine = new PrayerEngine(new LiturgicalCalendarService());
        var prayer = new Prayer { LanguageCode = "en", Rosary = new RosaryOptions { PresenterMode = true } };
        var steps = engine.BuildSteps(prayer);
        var currentIndex = steps.ToList().FindIndex(s => s.Title == "Hail Mary & Glory Be" && s.DecadeIndex == 0);
        var layout = BeadLayout.Build(steps, currentIndex, hasClosingCross: true, isDarkTheme: false);

        Assert.True(layout.ShowBottomBeads);
        Assert.Equal(10, layout.BottomBeads.Count);
        for (var i = 0; i < 9; i++)
        {
            Assert.Equal(BeadState.Completed, layout.BottomBeads[i].State);
        }
        Assert.Equal(BeadState.Current, layout.BottomBeads[9].State);
    }

    /// <summary>The narrow layout wraps major beads per mystery group — an ungrouped 7-decade
    /// session (Franciscan Crown, Seven Sorrows) must keep every major bead on ONE row (cross +
    /// 7 decades), never an arbitrary 5+2 split.</summary>
    [Fact]
    public void Build_MysteryLessSevenDecadeSession_KeepsMajorBeadsOnOneRow()
    {
        var steps = MysteryLessDecadeSteps(7);
        var layout = BeadLayout.Build(steps, currentIndex: 0, hasClosingCross: false, isDarkTheme: false);

        var row = Assert.Single(layout.TopRows);
        Assert.Equal(8, row.Count); // opening cross + 7 decade beads
        Assert.Equal(7, row.Count(b => b.Kind == BeadKind.Decade));
    }

    /// <summary>A multi-group Rosary still wraps one row per mystery group (the rows-of-5 the
    /// physical rosary loops suggest), with the antiphon/closing cross on the last row.</summary>
    [Fact]
    public void Build_TwentyMysterySession_WrapsOneRowPerGroup()
    {
        var engine = new PrayerEngine(new LiturgicalCalendarService());
        // Explicit language: resolving the default-language sentinel reads ApplicationData,
        // which only exists in a packaged app — same convention as RosaryEngineTests.
        var prayer = new Prayer { LanguageCode = "en", Rosary = new RosaryOptions { MysterySelectionMode = MysterySelectionMode.TwentyMystery } };
        var steps = engine.BuildSteps(prayer);
        var layout = BeadLayout.Build(steps, currentIndex: 0, hasClosingCross: true, isDarkTheme: false);

        Assert.Equal(4, layout.TopRows.Count);
        Assert.Equal(5, layout.TopRows[0].Count(b => b.Kind == BeadKind.Decade));
        Assert.Equal(5, layout.TopRows[3].Count(b => b.Kind == BeadKind.Decade));
        Assert.Equal(BeadKind.Cross, layout.TopRows[0][0].Kind);
        Assert.Equal(BeadKind.Cross, layout.TopRows[3][^1].Kind);
    }
}
