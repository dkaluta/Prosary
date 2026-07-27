using Prosary.Services;
using Xunit;

namespace Prosary.Tests;

/// <summary>
/// Exercises the bundled Shared/data datasets behind the Home "Today" section: fixed and
/// movable feasts (incl. the Latin Patriarchate of Jerusalem propers overlaid on the General
/// Roman Calendar), the Pope's monthly intention, and the graceful out-of-range null that hides
/// the row. Mirrors iOS's TodayInfoStoreTests.swift / Android's TodayInfoStoreTest.kt.
/// </summary>
public class TodayInfoStoreTests
{
    [Fact]
    public void FixedSolemnityResolves()
    {
        var feast = TodayInfoStore.Feast(new DateOnly(2026, 12, 25));
        Assert.Equal("Christmas", feast?.Title);
        Assert.Equal("Solemnity", feast?.Rank);
    }

    [Fact]
    public void MovableFeastIsBakedInPerYear()
    {
        // Easter falls on April 5 in 2026; Good Friday 2027 is March 26 — both must resolve.
        Assert.Equal("Solemnity", TodayInfoStore.Feast(new DateOnly(2026, 4, 5))?.Rank);
        Assert.NotNull(TodayInfoStore.Feast(new DateOnly(2027, 3, 26)));
    }

    /// <summary>The Holy Land calendar's own principal feast overlays the General Roman Calendar
    /// — in 2026 October 25 is a Sunday of Ordinary Time in the GRC, but the diocese's patronal
    /// solemnity takes precedence.</summary>
    [Fact]
    public void LatinPatriarchatePropersOverlayTheGeneralCalendar()
    {
        var feast = TodayInfoStore.Feast(new DateOnly(2026, 10, 25));
        Assert.Equal("Our Lady, Queen of Palestine and of the Holy Land", feast?.Title);
        Assert.Equal("Solemnity", feast?.Rank);

        Assert.Equal(
            "Dedication of the Basilica of the Holy Sepulchre",
            TodayInfoStore.Feast(new DateOnly(2026, 7, 15))?.Title);
    }

    [Fact]
    public void FerialDayHasNoFeast()
    {
        Assert.Null(TodayInfoStore.Feast(new DateOnly(2026, 7, 27)));
    }

    [Fact]
    public void DateOutsideTheGeneratedYearsHasNoFeast()
    {
        Assert.Null(TodayInfoStore.Feast(new DateOnly(2031, 12, 25)));
    }

    [Fact]
    public void MonthIntentionResolves()
    {
        var intention = TodayInfoStore.Intention(new DateOnly(2026, 7, 27));
        Assert.Equal("For respect for human life", intention?.Title);
        Assert.Contains("human life in all its stages", intention?.Text);
    }

    [Fact]
    public void MonthOutsideThePublishedListHasNoIntention()
    {
        Assert.Null(TodayInfoStore.Intention(new DateOnly(2031, 5, 1)));
    }
}
