using Prosary.Models;
using Xunit;

namespace Prosary.Tests;

/// The rules that make a multi-day devotion behave like a calendar rather than a counter.
public class MultiDayRunTests
{
    private const int Nine = 9;
    private static readonly DateTimeOffset Start = new(2026, 8, 5, 9, 0, 0, TimeSpan.Zero);
    private static DateTimeOffset Day(int offset) => Start.AddDays(offset);

    [Fact]
    public void PrayingTwiceInOneDayDoesNotAdvance()
    {
        var run = new MultiDayRun("novena", Start, []).RecordingPrayed(0, Start);
        Assert.True(run.HasPrayedToday(Start));
        Assert.Equal(0, run.DueDay(Nine, Start));
        Assert.Equal(1, run.NextUnprayedDay(Nine));
    }

    [Fact]
    public void TheNextCalendarDayOffersTheNextDay()
    {
        var run = new MultiDayRun("novena", Start, []).RecordingPrayed(0, Start);
        Assert.False(run.HasPrayedToday(Day(1)));
        Assert.Equal(new MultiDayRun.Resumption.Resume(1), run.GetResumption(Nine, Day(1)));
        Assert.Null(run.MissedDay(Nine, Day(1)));
    }

    [Fact]
    public void AMissedDayOffersBothItAndTheCalendarDay()
    {
        var run = new MultiDayRun("novena", Start, []).RecordingPrayed(0, Start);
        Assert.Equal(1, run.MissedDay(Nine, Day(2)));
        Assert.Equal(2, run.DueDay(Nine, Day(2)));
        Assert.Equal(new MultiDayRun.Resumption.Choose(1, 2), run.GetResumption(Nine, Day(2)));
    }

    [Fact]
    public void TheDayCountComesFromTheDevotion()
    {
        var run = new MultiDayRun("triduum", Start, [])
            .RecordingPrayed(0, Start).RecordingPrayed(1, Day(1)).RecordingPrayed(2, Day(2));
        Assert.True(run.IsComplete(3));
        Assert.Equal(new MultiDayRun.Resumption.Complete(), run.GetResumption(3, Day(2)));
        Assert.False(run.IsComplete(33));
    }

    [Fact]
    public void DueDayNeverRunsPastTheLastDay() =>
        Assert.Equal(8, new MultiDayRun("novena", Start, []).DueDay(Nine, Day(400)));
}
