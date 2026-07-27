using Prosary.Services;
using Xunit;

namespace Prosary.Tests;

public class AngelusEngineTests
{
    [Fact]
    public void BuildSteps_OrdinaryTime_ProducesFixedSevenStepSequence()
    {
        var steps = PrayerEngine.BuildAngelusSteps("en", isEasterSeason: false);

        Assert.Equal(7, steps.Count);
        Assert.Equal(
            ["The Annunciation", "Hail Mary", "The Fiat", "Hail Mary", "The Incarnation", "Hail Mary", "Let Us Pray"],
            steps.Select(s => s.Title));
        Assert.All(steps, s => Assert.False(s.IsAntiphon));
    }

    [Fact]
    public void BuildSteps_EasterSeason_ProducesSingleReginaCaeliStep()
    {
        var steps = PrayerEngine.BuildAngelusSteps("en", isEasterSeason: true);

        Assert.Single(steps);
        Assert.Equal("Regina Caeli", steps[0].Title);
    }

    [Fact]
    public void BuildSteps_NoLanguageCode_DoesNotThrow()
    {
        var steps = PrayerEngine.BuildAngelusSteps(null, isEasterSeason: false);
        Assert.Equal(7, steps.Count);
    }
}
