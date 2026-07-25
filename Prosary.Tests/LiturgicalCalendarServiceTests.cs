using Prosary.Models;
using Prosary.Services;
using Xunit;

namespace Prosary.Tests;

public class LiturgicalCalendarServiceTests
{
    private readonly LiturgicalCalendarService _calendar = new();

    [Theory]
    // Meeus/Jones/Butcher Gregorian Easter algorithm, checked against well-known public Easter
    // dates. Asserting both that the date itself is in-season and the day before is not pins down
    // the exact computed date (an off-by-one Easter calculation would fail one side or the other).
    [InlineData(2023, 4, 9)]
    [InlineData(2024, 3, 31)]
    [InlineData(2025, 4, 20)]
    [InlineData(2026, 4, 5)]
    public void ComputeEasterSunday_MatchesKnownDates(int year, int month, int day)
    {
        var easter = new DateOnly(year, month, day);
        Assert.True(_calendar.IsEasterSeason(easter));
        Assert.False(_calendar.IsEasterSeason(easter.AddDays(-1)));
    }

    [Fact]
    public void GetMysteryGroup_WeekdaysFollowTraditionalAssignment()
    {
        // 2024-01-01 was a Monday; the following six dates cover the rest of that week.
        Assert.Equal(MysteryGroup.Joyful, _calendar.GetMysteryGroup(new DateOnly(2024, 1, 1))); // Mon
        Assert.Equal(MysteryGroup.Sorrowful, _calendar.GetMysteryGroup(new DateOnly(2024, 1, 2))); // Tue
        Assert.Equal(MysteryGroup.Glorious, _calendar.GetMysteryGroup(new DateOnly(2024, 1, 3))); // Wed
        Assert.Equal(MysteryGroup.Luminous, _calendar.GetMysteryGroup(new DateOnly(2024, 1, 4))); // Thu
        Assert.Equal(MysteryGroup.Sorrowful, _calendar.GetMysteryGroup(new DateOnly(2024, 1, 5))); // Fri
        Assert.Equal(MysteryGroup.Joyful, _calendar.GetMysteryGroup(new DateOnly(2024, 1, 6))); // Sat
    }

    [Fact]
    public void GetMysteryGroup_SundayInAdvent_IsJoyful()
    {
        // First Sunday of Advent 2024 (first Sunday on/after Nov 27, 2024).
        var sunday = new DateOnly(2024, 12, 1);
        Assert.Equal(DayOfWeek.Sunday, sunday.DayOfWeek);
        Assert.Equal(MysteryGroup.Joyful, _calendar.GetMysteryGroup(sunday));
    }

    [Fact]
    public void GetMysteryGroup_SundayInLent_IsSorrowful()
    {
        // Ash Wednesday 2024 was Feb 14; Feb 18, 2024 is the following Sunday, within Lent.
        var sunday = new DateOnly(2024, 2, 18);
        Assert.Equal(DayOfWeek.Sunday, sunday.DayOfWeek);
        Assert.Equal(MysteryGroup.Sorrowful, _calendar.GetMysteryGroup(sunday));
    }

    [Fact]
    public void GetMysteryGroup_SundayInOrdinaryTime_IsGlorious()
    {
        // Sept 1, 2024 — well after Pentecost (May 19, 2024), well before Advent (Dec 1, 2024).
        var sunday = new DateOnly(2024, 9, 1);
        Assert.Equal(DayOfWeek.Sunday, sunday.DayOfWeek);
        Assert.Equal(MysteryGroup.Glorious, _calendar.GetMysteryGroup(sunday));
    }

    [Fact]
    public void IsEasterSeason_TrueFromEasterThroughDayBeforePentecost()
    {
        var easter = new DateOnly(2024, 3, 31);
        var pentecost = easter.AddDays(49); // 2024-05-19

        Assert.True(_calendar.IsEasterSeason(easter));
        Assert.True(_calendar.IsEasterSeason(pentecost.AddDays(-1)));
        Assert.False(_calendar.IsEasterSeason(pentecost));
        Assert.False(_calendar.IsEasterSeason(easter.AddDays(-1)));
    }

    [Fact]
    public void GetSeasonColor_Pentecost_IsRed()
    {
        var pentecost = new DateOnly(2024, 5, 19);
        var color = _calendar.GetSeasonColor(pentecost);
        Assert.Equal(0xB2, color.R);
        Assert.Equal(0x22, color.G);
        Assert.Equal(0x22, color.B);
    }

    [Fact]
    public void GetSeasonColor_Advent_IsViolet()
    {
        var color = _calendar.GetSeasonColor(new DateOnly(2024, 12, 1));
        Assert.Equal(0x6A, color.R);
        Assert.Equal(0x3E, color.G);
        Assert.Equal(0x8E, color.B);
    }

    [Fact]
    public void GetSeasonColor_ChristmasDay_IsGold()
    {
        var color = _calendar.GetSeasonColor(new DateOnly(2024, 12, 25));
        Assert.Equal(0xB8, color.R);
        Assert.Equal(0x86, color.G);
        Assert.Equal(0x0B, color.B);
    }

    [Fact]
    public void GetSeasonColor_OrdinaryTime_IsGreen()
    {
        var color = _calendar.GetSeasonColor(new DateOnly(2024, 9, 1));
        Assert.Equal(0x2E, color.R);
        Assert.Equal(0x7D, color.G);
        Assert.Equal(0x32, color.B);
    }

    [Fact]
    public void GetSeasonalMarianAntiphon_MatchesSeason()
    {
        Assert.Equal(MarianAntiphonOption.AlmaRedemptorisMater, _calendar.GetSeasonalMarianAntiphon(new DateOnly(2024, 12, 1))); // Advent
        Assert.Equal(MarianAntiphonOption.AveReginaCaelorum, _calendar.GetSeasonalMarianAntiphon(new DateOnly(2024, 2, 18))); // Lent
        Assert.Equal(MarianAntiphonOption.ReginaCaeli, _calendar.GetSeasonalMarianAntiphon(new DateOnly(2024, 3, 31))); // Easter
        Assert.Equal(MarianAntiphonOption.SalveRegina, _calendar.GetSeasonalMarianAntiphon(new DateOnly(2024, 9, 1))); // Ordinary Time
    }
}
