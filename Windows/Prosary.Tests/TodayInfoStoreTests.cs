using Prosary.Models;
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
        Assert.All(TodayInfoStore.Calendars, calendar => Assert.False(string.IsNullOrWhiteSpace(calendar.ReadingsFile)));
    }

    /// <summary>The Evangelizo Hebrew lectionary titles now overlay the complete General Roman
    /// table, rather than appearing as a duplicate calendar choice. Days without a sourced
    /// Hebrew title keep the canonical English title.</summary>
    [Fact]
    public void GeneralRomanCalendarCarriesHebrewTitlesInline()
    {
        TodayInfoStore.SelectedCalendarId = "roman";
        var bartholomew = TodayInfoStore.Feast(new DateOnly(2026, 8, 24));
        Assert.Equal("Saint Bartholomew, Apostle", bartholomew?.Title);
        Assert.Equal("חג בר-תלמי השליח", bartholomew?.LocalizedTitle("he"));
        Assert.Equal("Feast", bartholomew?.Rank);
        var sunday = TodayInfoStore.Feast(new DateOnly(2026, 8, 30));
        Assert.Equal("22nd Sunday of Ordinary Time", sunday?.Title);
        Assert.Equal("יום א ה-22 של הזמן הרגיל", sunday?.LocalizedTitle("he"));
        Assert.Equal("Sunday", sunday?.Rank);
        var gregory = TodayInfoStore.Feast(new DateOnly(2026, 9, 3));
        Assert.Equal(gregory?.Title, gregory?.LocalizedTitle("he"));
    }

    [Fact]
    public void LegacyHebrewRomanSelectionMigratesToGeneralRoman()
    {
        var original = AppSettings.FeastCalendarId;
        try
        {
            AppSettings.SetFeastCalendarId("roman-he");
            Assert.Equal("roman", AppSettings.FeastCalendarId);

            TodayInfoStore.SelectedCalendarId = "roman-he";
            Assert.Equal("roman", TodayInfoStore.ResolvedCalendarId);
            Assert.Equal(
                "Saint Bartholomew, Apostle",
                TodayInfoStore.Feast(new DateOnly(2026, 8, 24))?.Title);
        }
        finally
        {
            AppSettings.SetFeastCalendarId(original);
        }
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
        Assert.Equal("למען כבוד לחיי אדם", intention?.LocalizedTitle("he"));
        Assert.Contains("בכל שלביהם", intention?.LocalizedText("he"));
    }

    [Fact]
    public void ReadingsAndLiturgicalDayResolve()
    {
        var readings = TodayInfoStore.Readings(new DateOnly(2026, 8, 31));
        Assert.Equal(new[] { "1 Cor. 2", "Ps. 119", "Lk. 4" }, readings.Select(r => r.Short));
        Assert.Equal(new[] { "הראשונה אל הקורינתים ב׳", "תהלים קי״ט", "לוקס ד׳" },
            readings.Select(r => r.LocalizedShort("he")));
        Assert.Equal("Luke 4:16–30", readings.Last().Full);
        Assert.Equal("הבשורה על-פי לוקס ד׳ 16–30", readings.Last().LocalizedFull("he"));

        // Rite-specific Hebrew reads the same localized citation map instead of falling back to
        // English or rebuilding punctuation at runtime.
        Assert.Equal(readings.Last().LocalizedFull("he"), readings.Last().LocalizedFull("he-x-gamliel"));

        var day = TodayInfoStore.LiturgicalDay(new DateOnly(2026, 8, 31));
        Assert.StartsWith("Monday · Week ", day.English);
        Assert.EndsWith(" of Ordinary Time", day.English);
        Assert.Contains("בזמן הרגיל", day.Hebrew);
    }

    [Fact]
    public void HebrewEpistleShorthandPreservesFullSourceCitation()
    {
        var corinthians = TodayInfoStore.Readings(new DateOnly(2026, 9, 4)).First();
        Assert.Equal("הראשונה אל הקורינתים ד׳", corinthians.LocalizedShort("he"));
        Assert.Equal(
            "אגרת שאול הראשונה אל הקורינתים ד׳ 1–5",
            corinthians.LocalizedFull("he"));

        var petrine = new ReadingCitation(
            "reading",
            "2 Pet. 2",
            "2 Peter 2:1–3",
            ShortByLanguage: new Dictionary<string, string> { ["he"] = "השנייה של כיפא ב׳" },
            FullByLanguage: new Dictionary<string, string> { ["he"] = "אגרת כיפא השניה ב׳ 1–3" });
        Assert.Equal("השנייה של כיפא ב׳", petrine.LocalizedShort("he"));
        Assert.Equal("אגרת כיפא השניה ב׳ 1–3", petrine.LocalizedFull("he"));
    }

    [Fact]
    public void SwitchingCalendarsAlsoReloadsThatCalendarsReadings()
    {
        var date = new DateOnly(2026, 8, 31);

        TodayInfoStore.SelectedCalendarId = "roman";
        Assert.Equal(new[] { "1 Cor. 2", "Ps. 119", "Lk. 4" }, TodayInfoStore.Readings(date).Select(r => r.Short));

        TodayInfoStore.SelectedCalendarId = "roman1962";
        Assert.Equal(new[] { "Lk. 12" }, TodayInfoStore.Readings(date).Select(r => r.Short));

        TodayInfoStore.SelectedCalendarId = "ugcc";
        Assert.Equal(new[] { "Heb. 9", "Lk. 10" }, TodayInfoStore.Readings(date).Select(r => r.Short));

        TodayInfoStore.SelectedCalendarId = "syriac";
        Assert.Equal(new[] { "Rom. 7", "Lk. 17" }, TodayInfoStore.Readings(date).Select(r => r.Short));

        // Switching back exercises cache invalidation rather than just first-load behavior.
        TodayInfoStore.SelectedCalendarId = "roman";
        Assert.Equal("1 Cor. 2", TodayInfoStore.Readings(date).First().Short);
    }

    [Fact]
    public void ReadingsOutsideASelectedCalendarsCoverageAreEmpty()
    {
        TodayInfoStore.SelectedCalendarId = "syriac";
        Assert.Empty(TodayInfoStore.Readings(new DateOnly(2031, 1, 1)));
    }

    [Fact]
    public void MonthOutsideThePublishedListHasNoIntention()
    {
        Assert.Null(TodayInfoStore.Intention(new DateOnly(2031, 5, 1)));
    }
}
