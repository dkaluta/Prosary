using Prosary.Models;
using Prosary.Services;
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

/// <summary>One prompt per remaining day, never for a day already prayed or already past.
/// Mirrors iOS's MultiDaySeriesReminderTests and Android's SeriesReminderTest.</summary>
public class SeriesReminderTests
{
    private static DateTimeOffset At(int year, int month, int day, int hour = 9) =>
        new(new DateTime(year, month, day, hour, 0, 0), TimeSpan.Zero);

    [Fact]
    public void EveryUnprayedDayGetsOnePromptOnItsOwnDate()
    {
        var run = new MultiDayRun("oAntiphons", At(2026, 12, 17), []);
        var pending = WindowsReminderScheduler.PendingSeriesDays(run, 7, 18, 0, At(2026, 12, 17, 8));

        Assert.Equal([0, 1, 2, 3, 4, 5, 6], pending.Select(p => p.Day));
        Assert.Equal(At(2026, 12, 17, 18), pending[0].When);
        Assert.Equal(At(2026, 12, 23, 18), pending[^1].When);
    }

    [Fact]
    public void PrayedAndPastDaysAreSkipped()
    {
        var run = new MultiDayRun("oAntiphons", At(2026, 12, 17), []).RecordingPrayed(0, At(2026, 12, 17, 19));
        // Two evenings in: day 0 was prayed, day 1's prompt has already fired.
        var pending = WindowsReminderScheduler.PendingSeriesDays(run, 7, 18, 0, At(2026, 12, 18, 20));

        Assert.Equal([2, 3, 4, 5, 6], pending.Select(p => p.Day));
    }

    [Fact]
    public void TheBundlesSuggestedTimeWinsAndNonsenseFallsBack()
    {
        Assert.Equal((7, 30), WindowsReminderScheduler.ReminderTime("07:30"));
        Assert.Equal((18, 0), WindowsReminderScheduler.ReminderTime(null));
        Assert.Equal((18, 0), WindowsReminderScheduler.ReminderTime("25:00"));
    }
}
