using Prosary.Services;
using Xunit;

namespace Prosary.Tests;

public sealed class LocalReminderTimeTests
{
    [Fact]
    public void CivilDaysUseTheirOwnDaylightSavingOffset()
    {
        var zone = TimeZoneInfo.FindSystemTimeZoneById("Eastern Standard Time");
        foreach (var pair in new[] { (new DateOnly(2026, 3, 7), 23), (new DateOnly(2026, 10, 31), 25) }) {
            var before = LocalReminderTime.OnDate(pair.Item1, 9, 0, zone);
            var after = LocalReminderTime.OnDate(pair.Item1.AddDays(1), 9, 0, zone);
            Assert.Equal(9, after.Hour);
            Assert.Equal(pair.Item2, (after - before).TotalHours);
        }
    }

    [Fact]
    public void SpringGapUsesTheFirstRealMinute()
    {
        var zone = TimeZoneInfo.FindSystemTimeZoneById("Eastern Standard Time");
        var fire = LocalReminderTime.OnDate(new DateOnly(2026, 3, 8), 2, 30, zone);
        Assert.Equal(3, fire.Hour);
        Assert.Equal(0, fire.Minute);
    }
}
