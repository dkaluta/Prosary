using Prosary.Services;
using Xunit;

namespace Prosary.Tests;

/// <summary>
/// Exercises the bundled Shared/data datasets behind the Home "Today" section: fixed and
/// movable feasts (incl. the Latin Patriarchate of Jerusalem propers overlaid on the General
/// Roman Calendar), the switchable-calendar registry (calendars.json) and its per-calendar
/// feast tables, the Pope's monthly intention, and the graceful out-of-range null that hides
/// the row. Mirrors iOS's TodayInfoStoreTests.swift / Android's TodayInfoStoreTest.kt.
/// </summary>
public class TodayInfoStoreTests
{
    // The store is process-global static state; every case starts from the unset selection —
    // the LPJ default — and the store reloads live on selection change, so no teardown is
    // needed (xunit builds a fresh instance of this class per test, running this before each).
    public TodayInfoStoreTests()
    {
        TodayInfoStore.SelectedCalendarId = null;
    }

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
    public void CalendarRegistryListsTheShippedCalendarsInPickerOrder()
    {
        Assert.Equal(
            new[] { "lpj", "roman", "roman1962", "ugcc", "syriac" },
            TodayInfoStore.Calendars.Select(c => c.Id));
        Assert.Equal("lpj", TodayInfoStore.ResolvedCalendarId);
    }

    /// <summary>The Syriac Catholic table comes from Evangelizo.org's Daily Gospel (credited
    /// on the About screen): the Antiochene year names its Sundays from the season's anchor
    /// feasts, and Evangelizo's plain-date ferial titles are omitted like ferial days
    /// everywhere else.</summary>
    [Fact]
    public void SyriacCalendarNamesTheAntiocheneSeasons()
    {
        TodayInfoStore.SelectedCalendarId = "syriac";
        var sunday = TodayInfoStore.Feast(new DateOnly(2026, 10, 25));
        Assert.Equal("Sixth Sunday after the Feast of the Cross", sunday?.Title);
        Assert.Equal("Sunday", sunday?.Rank);
        Assert.Equal(
            "Assumption of the Mother of God",
            TodayInfoStore.Feast(new DateOnly(2026, 8, 15))?.Title);
        Assert.Null(TodayInfoStore.Feast(new DateOnly(2026, 7, 27)));
    }

    /// <summary>October 25, 2026 wears four different faces: the LPJ's patronal solemnity, a
    /// plain Sunday of Ordinary Time in the general calendar, Christ the King in the 1962
    /// books (which place the feast on October's last Sunday), and a numbered Sunday after
    /// Pentecost in the Byzantine reckoning.</summary>
    [Fact]
    public void SwitchingCalendarsResolvesEachCalendarsOwnFeast()
    {
        Assert.Equal(
            "Our Lady, Queen of Palestine and of the Holy Land",
            TodayInfoStore.Feast(new DateOnly(2026, 10, 25))?.Title);

        TodayInfoStore.SelectedCalendarId = "roman";
        Assert.Equal(
            "30th Sunday of Ordinary Time",
            TodayInfoStore.Feast(new DateOnly(2026, 10, 25))?.Title);

        TodayInfoStore.SelectedCalendarId = "roman1962";
        var vetus = TodayInfoStore.Feast(new DateOnly(2026, 10, 25));
        Assert.Equal("Christ the King", vetus?.Title);
        Assert.Equal("1st Class", vetus?.Rank);

        TodayInfoStore.SelectedCalendarId = "ugcc";
        Assert.Equal(
            "22nd Sunday after Pentecost",
            TodayInfoStore.Feast(new DateOnly(2026, 10, 25))?.Title);
    }

    /// <summary>The UGCC dataset is the diasporic (fully Gregorian) usage prayed in the Holy
    /// Land: Pascha falls with the Gregorian computus (April 5, 2026 — the same day as the
    /// Roman Easter), and a fixed Great Feast landing in Holy Week is joined, never
    /// displaced — in 2027 the Annunciation falls on Great and Holy Thursday.</summary>
    [Fact]
    public void UkrainianCalendarPraysTheGregorianPascha()
    {
        TodayInfoStore.SelectedCalendarId = "ugcc";
        var pascha = TodayInfoStore.Feast(new DateOnly(2026, 4, 5));
        Assert.Equal("The Resurrection of Our Lord — Holy Pascha", pascha?.Title);
        Assert.Equal("Great Feast", pascha?.Rank);
        Assert.Equal(
            "The Protection of the Most Holy Theotokos (Pokrov)",
            TodayInfoStore.Feast(new DateOnly(2026, 10, 1))?.Title);
        Assert.Equal(
            "The Annunciation of the Most Holy Theotokos; Great and Holy Thursday",
            TodayInfoStore.Feast(new DateOnly(2027, 3, 25))?.Title);
    }

    [Fact]
    public void UnknownCalendarIdFallsBackToTheDefault()
    {
        TodayInfoStore.SelectedCalendarId = "narnia";
        Assert.Equal("lpj", TodayInfoStore.ResolvedCalendarId);
        Assert.Equal(
            "Our Lady, Queen of Palestine and of the Holy Land",
            TodayInfoStore.Feast(new DateOnly(2026, 10, 25))?.Title);
    }

    [Fact]
    public void VetusOrdoKeepsSeptuagesimaAndClassRanks()
    {
        TodayInfoStore.SelectedCalendarId = "roman1962";
        var septuagesima = TodayInfoStore.Feast(new DateOnly(2026, 2, 1));
        Assert.Equal("Septuagesima Sunday", septuagesima?.Title);
        Assert.Equal("2nd Class", septuagesima?.Rank);
        Assert.Equal("1st Class", TodayInfoStore.Feast(new DateOnly(2026, 12, 25))?.Rank);
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
