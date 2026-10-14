using System.Globalization;
using Prosary.Services;
using Prosary.ViewModels;
using Xunit;

namespace Prosary.Tests;

public class CalendarEventPresentationTests
{
    [Fact]
    public void EachSourcedObservanceHasItsOwnDetailsAndMissingLanguagesStayExplicit()
    {
        var feast = new FeastDay("Combined title", "Memorial", Observances:
            [new("First", "first", DescriptionByLanguage: new() { ["en"] = "Exact first paragraph.\nSecond paragraph." }),
             new("Second", "second", DescriptionByLanguage: new() { ["he"] = "מקור" })]);
        var rows = LiturgicalCalendarViewModel.RowsForDate(new DateOnly(2026, 10, 14), feast, CultureInfo.InvariantCulture, "en").ToArray();
        Assert.Equal(["First", "Second"], rows.Select(row => row.Title));
        Assert.Equal("Exact first paragraph.", rows[0].Summary);
        Assert.Empty(rows[1].SourceDescriptions);
    }

    [Fact]
    public void PublishedCalendarIncludesMemorialsWhileTheLegacyRankedListKeepsItsMeaning()
    {
        var previous = TodayInfoStore.SelectedCalendarId;
        try
        {
            TodayInfoStore.SelectedCalendarId = "roman";
            var events = TodayInfoStore.PublishedEvents();
            Assert.Contains(events, entry => entry.Feast.Rank == "Memorial");
            Assert.Equal(events.OrderBy(entry => entry.Date), events);
            Assert.DoesNotContain(TodayInfoStore.FeastsAndSolemnities(), entry => entry.Feast.Rank == "Memorial");
        }
        finally { TodayInfoStore.SelectedCalendarId = previous; }
    }

    [Fact]
    public void ASourceReflectionRetainsItsOwnCreditWhenNoDescriptionExists()
    {
        var observance = new FeastObservance("Event", "event",
            DescriptionCreditByLanguage: new() { ["en"] = "Source credit" },
            ReflectionByLanguage: new() { ["en"] = "Exact reflection." });
        var row = Assert.Single(LiturgicalCalendarViewModel.RowsForDate(new DateOnly(2026, 10, 14),
            new FeastDay("Event", "Memorial", Observances: [observance]), CultureInfo.InvariantCulture, "en"));
        Assert.Equal("Exact reflection.", row.Summary);
        Assert.Equal("Source credit", Assert.Single(row.SourceDescriptions).Credit);
    }

    [Fact]
    public void ScriptureOfDayUsesSourceOrderEvenWhenPresentationOrderIsReversed()
    {
        var first = new ReadingCitation("reading", "First", "First");
        var gospel = new ReadingCitation("gospel", "Gospel", "Gospel");
        var secondGospel = new ReadingCitation("gospel", "Later", "Later");
        ReadingCitation[] source = [first, gospel, secondGospel];
        Assert.Same(gospel, ReadingCitation.ScriptureOfDay(source));
        Assert.Equal([secondGospel, gospel, first], ReadingCitation.DisplayOrder(source, true));
        Assert.Same(first, ReadingCitation.ScriptureOfDay([first]));
        Assert.Null(ReadingCitation.ScriptureOfDay([]));
    }

    [Fact]
    public void EventDetailLabelsUseCivilGregorianDatesInAnAlternateSystemCalendar()
    {
        var culture = CultureInfo.GetCultureInfo("ar-SA");
        var expectedCulture = (CultureInfo)culture.Clone();
        expectedCulture.DateTimeFormat.Calendar = new GregorianCalendar();
        var date = new DateOnly(2026, 10, 14);
        var row = Assert.Single(LiturgicalCalendarViewModel.RowsForDate(date, new FeastDay("Event", "Memorial"), culture, "ar"));
        Assert.Equal(date.ToString("D", expectedCulture), row.DateLabel);
    }
}
