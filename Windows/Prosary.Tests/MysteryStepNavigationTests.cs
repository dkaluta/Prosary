using Prosary.Models;
using Prosary.Services;
using Xunit;

namespace Prosary.Tests;

public class MysteryStepNavigationTests : IClassFixture<PrayerPackLoaderFixture>
{
    private readonly PrayerEngine _engine = new(new LiturgicalCalendarService());

    public MysteryStepNavigationTests(PrayerPackLoaderFixture _) { }

    [Theory]
    [InlineData(MysterySelectionMode.SingleMystery, 1, false)]
    [InlineData(MysterySelectionMode.SingleMystery, 1, true)]
    [InlineData(MysterySelectionMode.Specific, 5, false)]
    [InlineData(MysterySelectionMode.Specific, 5, true)]
    [InlineData(MysterySelectionMode.TodaysMysteries, 5, false)]
    [InlineData(MysterySelectionMode.TodaysMysteries, 5, true)]
    [InlineData(MysterySelectionMode.FifteenMystery, 15, false)]
    [InlineData(MysterySelectionMode.FifteenMystery, 15, true)]
    [InlineData(MysterySelectionMode.TwentyMystery, 20, false)]
    [InlineData(MysterySelectionMode.TwentyMystery, 20, true)]
    public void FinalMysteryWithoutClosingPrayersHasCompletionTarget(
        MysterySelectionMode mode, int count, bool presenter)
    {
        var options = new RosaryOptions { MysterySelectionMode = mode, SpecificMysteryOrder = 5,
            MarianAntiphon = MarianAntiphonOption.None, IncludeClosingIntentions = false,
            IncludeStMichaelPrayer = false, IncludeLitanyOfLoreto = false, IncludeRosaryCollect = false,
            IncludeFinalSignOfCross = false, PresenterMode = presenter };
        var steps = _engine.BuildSteps(new Prayer { Kind = PrayerKind.Rosary, LanguageCode = "en", Rosary = options });
        var starts = Enumerable.Range(0, steps.Count)
            .Where(index => steps[index].DecadeIndex is { } decade
                && !steps.Take(index).Any(step => step.DecadeIndex == decade)).ToList();
        Assert.Equal(count, starts.Count);
        Assert.Equal(count - 1, steps[^1].DecadeIndex);
        foreach (var index in Enumerable.Range(0, steps.Count).Where(index => steps[index].DecadeIndex == count - 1))
            Assert.Equal(steps.Count, MysteryStepNavigation.Next(steps, index));
        Assert.Null(MysteryStepNavigation.Next(steps, steps.Count));
        if (count > 1)
        {
            Assert.Equal(starts[^1], MysteryStepNavigation.Next(steps, starts[count - 2]));
            Assert.Equal(starts[count - 2], MysteryStepNavigation.Previous(steps, steps.Count - 1));
        }
        else
        {
            Assert.Null(MysteryStepNavigation.Previous(steps, steps.Count - 1));
        }
    }
}
