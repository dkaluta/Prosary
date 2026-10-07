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
    [Fact]
    public void PopePublicationRequiresStablePrayerIdentityAndExplicitOptIn()
    {
        var intention = new PopeIntention("Published title", "English body", new() { ["he"] = "כותרת" },
            new() { ["he"] = "גוף" }, TranslationCreditByLanguage: new() { ["he"] = "Prosary Hebrew translation" });
        var step = new RosaryStep("Renamed heading", null, "Sourced prayer") { PrayerKey = "intentioPontificis" };
        Assert.Null(PopeIntentionPrayerContext.Resolve(step, intention, "he"));
        Assert.Null(PopeIntentionPrayerContext.Resolve(step, null, "he", true));
        Assert.Null(PopeIntentionPrayerContext.Resolve(step with { PrayerKey = null, Title = "For the Pope's intentions" }, intention, "he", true));
        var publication = PopeIntentionPrayerContext.Resolve(step, intention, "iw-IL", true);
        Assert.Equal("he", publication?.LanguageCode);
        Assert.Equal("Prosary Hebrew translation", publication?.TranslationCredit);
        Assert.Equal("Sourced prayer", step.Body);
    }

    [Fact]
    public void PopePublicationFallbackUsesTheEnglishCreditAndCompleteEdition()
    {
        var intention = new PopeIntention("English title", "English body", new() { ["he"] = "כותרת" }, new(),
            TranslationCreditByLanguage: new() { ["he"] = "Hebrew editorial credit", ["en"] = "English published source" });
        var step = new RosaryStep("Pope", null, "Prayer") { PrayerKey = "intentioPontificis" };
        foreach (var language in new[] { "he", "he-x-gamliel", "arc", "la" })
        {
            var publication = PopeIntentionPrayerContext.Resolve(step, intention, language, true);
            Assert.Equal("en", publication?.LanguageCode);
            Assert.Equal("English title", publication?.Title);
            Assert.Equal("English body", publication?.Text);
            Assert.Equal("English published source", publication?.TranslationCredit);
        }
    }
    // The store is process-global static state; every case starts from the unset selection —
    // the LPJ default — and the store reloads live on selection change, so no teardown is
    // needed (xunit builds a fresh instance of this class per test, running this before each).
    [Fact]
    public void ImportedCitationKeepsSourceMassAndPrintedReference()
    {
        var citation = System.Text.Json.JsonSerializer.Deserialize<ReadingCitation>(
            """{"type":"reading","short":"1 Cor. 3","full":"1 Corinthians 3:9–11,16–17","sourceText":"1Cor3:9-11.16-17","sourceGroup":"Vigil Mass"}""",
            new System.Text.Json.JsonSerializerOptions { PropertyNameCaseInsensitive = true });
        Assert.NotNull(citation);
        Assert.Equal("1Cor3:9-11.16-17", citation.SourceText);
        Assert.Equal("Vigil Mass", citation.SourceGroup);
        Assert.Equal("1 Corinthians 3:9–11,16–17", citation.LocalizedFull("he"));
    }

    public TodayInfoStoreTests()
    {
        TodayInfoStore.SelectedCalendarId = null;
        AppSettings.SetEasternPaschaStyle("julian");
    }

    [Theory]
    [InlineData("lpj", "julian", "roman")]
    [InlineData("roman", "julian", "roman")]
    [InlineData("ugcc", "julian", "ugcc")]
    [InlineData("ugcc", "gregorian", "ugcc-gregorian")]
    [InlineData("stjames", "julian", "stjames")]
    public void CitationsCaptureTheActualSelectedDatasetAndKeepItAfterLaterCalendarChanges(string calendar, string pascha, string dataset)
    {
        var previousCalendar = TodayInfoStore.SelectedCalendarId;
        var previousPascha = AppSettings.EasternPaschaStyle;
        try
        {
            TodayInfoStore.SelectedCalendarId = calendar;
            AppSettings.SetEasternPaschaStyle(pascha);
            using var document = System.Text.Json.JsonDocument.Parse(File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "Data", $"readings-{dataset}.json")));
            var date = DateOnly.ParseExact(document.RootElement.GetProperty("days").EnumerateObject().First().Name,
                "yyyy-MM-dd", System.Globalization.CultureInfo.InvariantCulture);
            var citations = TodayInfoStore.Readings(date);
            Assert.NotEmpty(citations);
            Assert.All(citations, citation => Assert.Equal(dataset, citation.ReadingDatasetId));

            TodayInfoStore.SelectedCalendarId = "maronite";
            _ = TodayInfoStore.Readings(date);
            Assert.All(citations, citation => Assert.Equal(dataset, citation.ReadingDatasetId));
            Assert.DoesNotContain("readingDatasetId", System.Text.Json.JsonSerializer.Serialize(citations), StringComparison.OrdinalIgnoreCase);
        }
        finally
        {
            TodayInfoStore.SelectedCalendarId = previousCalendar;
            AppSettings.SetEasternPaschaStyle(previousPascha);
        }
    }

    [Fact]
    public void RomanSaintExcerptsRetainSourceAndExactLanguageWithoutChangingSundayPrecedence()
    {
        foreach (var calendar in new[] { "lpj", "roman", "roman1962" })
        {
            TodayInfoStore.SelectedCalendarId = calendar;
            var feast = TodayInfoStore.Feast(new DateOnly(2027, 10, 4));
            Assert.NotNull(feast);
            var english = Assert.Single(feast.LocalizedDescriptions("en"));
            Assert.Contains("Franciscans", english.Text);
            Assert.Equal("publication.evangelizo.ws", english.SourceUri?.Host);
            Assert.Contains("Evangelizo", english.Credit ?? "");
            foreach (var language in new[] { "he", "ru", "tl", "uk" })
                Assert.Empty(feast.LocalizedDescriptions(language));
            var sunday = TodayInfoStore.Feast(new DateOnly(2026, 10, 4));
            Assert.NotNull(sunday);
            Assert.Empty(sunday.LocalizedDescriptions("en"));
        }
    }

    [Fact]
    public void FixedSolemnityResolves()
    {
        var feast = TodayInfoStore.Feast(new DateOnly(2026, 12, 25));
        Assert.Equal("Christmas", feast?.Title);
        Assert.Equal("Solemnity", feast?.Rank);
    }

    [Fact]
    public void FeastListIsChronologicalAndFollowsTheSelectedCalendar()
    {
        TodayInfoStore.SelectedCalendarId = "lpj";
        var local = TodayInfoStore.FeastsAndSolemnities();
        Assert.NotEmpty(local);
        Assert.Equal(local.Select(entry => entry.Date).OrderBy(date => date), local.Select(entry => entry.Date));
        Assert.All(local, entry => Assert.Contains(entry.Feast.Rank,
            new[] { "Solemnity", "Feast", "Great Feast", "1st Class", "2nd Class" }));
        Assert.Contains(local, entry => entry.Date == new DateOnly(2026, 10, 25)
            && entry.Feast.Title.Contains("Palestine"));
        TodayInfoStore.SelectedCalendarId = "roman";
        Assert.DoesNotContain(TodayInfoStore.FeastsAndSolemnities(), entry =>
            entry.Date == new DateOnly(2026, 10, 25) && entry.Feast.Title.Contains("Palestine"));
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
            new[] { "lpj", "stjames", "roman", "roman1962", "franciscan-conventual-italy", "augustinian-discalced", "ugcc", "ugcc-julian", "syriac", "mission-provisional", "maronite" },
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
        Assert.Equal("חג בר־תלמי השליח", bartholomew?.LocalizedTitle("he"));
        Assert.Equal("Feast", bartholomew?.Rank);
        var sunday = TodayInfoStore.Feast(new DateOnly(2026, 8, 30));
        Assert.Equal("22nd Sunday of Ordinary Time", sunday?.Title);
        Assert.Equal("יום א ה־22 של הזמן הרגיל", sunday?.LocalizedTitle("he"));
        Assert.Equal("Sunday", sunday?.Rank);
        Assert.NotNull(TodayInfoStore.Feast(new DateOnly(2026, 9, 3)));
    }

    [Fact]
    public void OldStyleJulianCalendarKeepsChristmasAndPaschaOnTheirOwnDates()
    {
        TodayInfoStore.SelectedCalendarId = "ugcc-julian";
        AppSettings.SetEasternPaschaStyle("gregorian");
        try
        {
            Assert.Equal("ugcc-julian", TodayInfoStore.ResolvedCalendarId);
            foreach (var year in new[] { 2026, 2027 })
            {
                Assert.Equal("The Nativity of Our Lord", TodayInfoStore.Feast(new DateOnly(year, 1, 7))?.Title);
                Assert.Equal("The Holy Theophany of Our Lord", TodayInfoStore.Feast(new DateOnly(year, 1, 19))?.Title);
                Assert.NotEqual("The Nativity of Our Lord", TodayInfoStore.Feast(new DateOnly(year, 12, 25))?.Title);
            }
            Assert.Equal("The Resurrection of Our Lord — Holy Pascha", TodayInfoStore.Feast(new DateOnly(2026, 4, 12))?.Title);
            Assert.Equal("The Resurrection of Our Lord — Holy Pascha", TodayInfoStore.Feast(new DateOnly(2027, 5, 2))?.Title);
            Assert.Empty(TodayInfoStore.Readings(new DateOnly(2026, 1, 7)));
            TodayInfoStore.SelectedCalendarId = "ugcc";
            Assert.Equal("The Nativity of Our Lord", TodayInfoStore.Feast(new DateOnly(2026, 12, 25))?.Title);
        }
        finally { AppSettings.SetEasternPaschaStyle("julian"); }
    }

    [Fact]
    public void EveryCalendarLocalizesItsOwnFeastWithoutChangingItsTitleOrRank()
    {
        var expected = new[]
        {
            ("lpj", "Exaltation of the Holy Cross", "Feast"),
            ("roman", "Exaltation of the Holy Cross", "Feast"),
            ("roman1962", "Exaltation of the Holy Cross", "2nd Class"),
            ("ugcc", "The Exaltation of the Precious and Life-Giving Cross", "Great Feast"),
            ("syriac", "Exaltation of the Holy Cross—Feast", "Feast"),
        };
        foreach (var (calendarId, title, rank) in expected)
        {
            TodayInfoStore.SelectedCalendarId = calendarId;
            var feast = TodayInfoStore.Feast(new DateOnly(2026, 9, 14));
            Assert.NotNull(feast);
            Assert.Equal(title, feast.Title);
            Assert.Equal(rank, feast.Rank);
            Assert.Equal("חג תפארת הצלב", feast.LocalizedTitle("he"));
            Assert.Equal("חג תפארת הצלב", feast.LocalizedTitle("he-x-gamliel"));
            Assert.Equal(title, feast.LocalizedTitle("en"));
        }
    }

    [Fact]
    public void FeastWithoutATranslationKeepsItsOwnTitle()
    {
        var feast = new FeastDay("Untranslated feast", "Feast");
        Assert.Equal("Untranslated feast", feast.LocalizedTitle("he"));
        Assert.Equal("Untranslated feast", feast.LocalizedTitle("he-x-gamliel"));
    }

    [Fact]
    public void TeresaOfCalcuttaLocalizesWithoutReplacingAnotherCalendarsDay()
    {
        foreach (var calendarId in new[] { "lpj", "roman" })
        {
            TodayInfoStore.SelectedCalendarId = calendarId;
            var feast = TodayInfoStore.Feast(new DateOnly(2026, 9, 5));
            Assert.NotNull(feast);
            Assert.Equal("Saint Teresa of Calcutta, Virgin", feast.Title);
            Assert.Equal("Optional Memorial", feast.Rank);
            Assert.Equal("תרזה הקדושה מקלקוטה, בתולה", feast.LocalizedTitle("he"));
            Assert.Equal("תרזה הקדושה מקלקוטה, בתולה", feast.LocalizedTitle("he-x-gamliel"));
            Assert.Equal("Saint Teresa of Calcutta, Virgin", feast.LocalizedTitle("en"));

            // September 5 falls on Sunday in 2027; translating a saint must not change precedence.
            var sunday = TodayInfoStore.Feast(new DateOnly(2027, 9, 5));
            Assert.Equal("23rd Sunday of Ordinary Time", sunday?.Title);
            Assert.Equal("Sunday", sunday?.Rank);
        }

        TodayInfoStore.SelectedCalendarId = "roman1962";
        var vetus = TodayInfoStore.Feast(new DateOnly(2026, 9, 5));
        Assert.Equal("St. Lawrence Justinian", vetus?.Title);
        Assert.Equal("3rd Class", vetus?.Rank);
        TodayInfoStore.SelectedCalendarId = "ugcc";
        Assert.Null(TodayInfoStore.Feast(new DateOnly(2026, 9, 5)));

        TodayInfoStore.SelectedCalendarId = "syriac";
        var syriac = TodayInfoStore.Feast(new DateOnly(2026, 9, 5));
        Assert.Equal("St. Charbel", syriac?.Title);
        Assert.Equal("Feast", syriac?.Rank);
    }

    [Fact]
    public void SaintTitlesRetainTheirRolesAcrossCalendarAliases()
    {
        var expected = new[]
        {
            ("roman", "2026-05-26", "Saint Philip Neri, Priest", "Memorial", "פיליפוס נרי, כהן"),
            ("roman", "2026-10-22", "Saint John Paul II, Pope", "Optional Memorial", "יוחנן פאולוס השני, אפיפיור"),
            ("roman", "2026-07-15", "Saint Bonaventure, Bishop and Doctor of the Church", "Memorial", "בונבנטורה הקדוש, הגמון ודוקטור הכנסייה"),
            ("roman1962", "2026-07-14", "St. Bonaventure", "3rd Class", "בונבנטורה הקדוש, הגמון ודוקטור הכנסייה"),
            ("roman", "2026-07-03", "Saint Thomas the Apostle", "Feast", "תאמא השליח"),
            ("syriac", "2026-10-06", "St. Thomas", "Feast", "תאמא השליח"),
            ("roman1962", "2026-12-21", "St. Thomas", "2nd Class", "תאמא השליח"),
            ("roman", "2026-01-28", "Saint Thomas Aquinas, Priest and Doctor of the Church", "Memorial", "תומאס אקווינס, כהן ודוקטור הכנסייה"),
        };
        foreach (var (calendarId, feastDate, title, rank, hebrew) in expected)
        {
            TodayInfoStore.SelectedCalendarId = calendarId;
            var feast = TodayInfoStore.Feast(DateOnly.ParseExact(feastDate, "yyyy-MM-dd", System.Globalization.CultureInfo.InvariantCulture));
            Assert.NotNull(feast);
            Assert.Equal(title, feast.Title);
            Assert.Equal(rank, feast.Rank);
            Assert.Equal(hebrew, feast.LocalizedTitle("he"));
            Assert.Equal(hebrew, feast.LocalizedTitle("he-x-gamliel"));
            Assert.Equal(title, feast.LocalizedTitle("en"));
        }
    }

    [Fact]
    public void FeastRanksFollowTodayLanguageWithoutChangingCanonicalValues()
    {
        var expected = new[]
        {
            ("Solemnity", "מועד"),
            ("Feast", "חג"),
            ("Memorial", "זיכרון"),
            ("Optional Memorial", "זיכרון רשות"),
            ("Sunday", "יום ראשון"),
            ("Great Feast", "חג גדול"),
            ("Holy Week", "השבוע הקדוש"),
            ("Fast", "צום"),
            ("1st Class", "דרגה ראשונה"),
            ("2nd Class", "דרגה שנייה"),
            ("3rd Class", "דרגה שלישית"),
        };
        foreach (var (rank, hebrew) in expected)
        {
            var feast = new FeastDay("Feast", rank);
            Assert.Equal(hebrew, feast.LocalizedRank("he"));
            Assert.Equal(hebrew, feast.LocalizedRank("he-x-gamliel"));
            Assert.Equal(rank, feast.LocalizedRank("en"));
            Assert.Equal(rank, feast.Rank);
        }
        var unknown = new FeastDay("Feast", "Future rank");
        Assert.Equal("Future rank", unknown.LocalizedRank("he"));
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
    /// feasts. Plain-date ferial titles are omitted, while their saints and saints listed
    /// alongside a Sunday remain visible.</summary>
    [Fact]
    public void SyriacCalendarNamesTheAntiocheneSeasons()
    {
        TodayInfoStore.SelectedCalendarId = "syriac";
        var sunday = TodayInfoStore.Feast(new DateOnly(2026, 10, 25));
        Assert.Equal("Sixth Sunday after the Feast of the Cross; St. Phyton", sunday?.Title);
        Assert.Equal("Sunday", sunday?.Rank);
        Assert.Equal(
            "Assumption of the Mother of God",
            TodayInfoStore.Feast(new DateOnly(2026, 8, 15))?.Title);
        Assert.Equal("St. Pentalmon", TodayInfoStore.Feast(new DateOnly(2026, 7, 27))?.Title);
    }

    [Theory]
    [InlineData(9, 30,
        "St. Gregory the Illuminator; St. Jerome of Stridon",
        "عيد القدّيس غريغوريوس النورانيّ رئيس كهنة أرمينيا - الدرجة ب -; عيد القدّيس هيرونيموس الكاهن والملفان - الدرجة ب -",
        2)]
    [InlineData(10, 1,
        "St. Ananias; St. Abi; Saint Thérèse of the Child Jesus, Virgin and Doctor of the Church",
        "عيد القدّيس حننيا الرسول - الدرجة ج -; عيد القدّيس أباي الشهيد - الدرجة ج -; عيد القدّيسة تريزا الطفل يسوع،",
        3)]
    public void SyriacCalendarIncludesEveryEnglishAndArabicSourceObservance(
        int month, int day, string english, string arabic, int observanceCount)
    {
        TodayInfoStore.SelectedCalendarId = "syriac";
        var feast = TodayInfoStore.Feast(new DateOnly(2026, month, day));

        Assert.NotNull(feast);
        Assert.Equal(english, feast.Title);
        Assert.Equal("Feast", feast.Rank);
        Assert.Equal(english, feast.LocalizedTitle("en"));
        Assert.Equal(arabic, feast.LocalizedTitle("ar"));
        foreach (var language in new[] { "en", "he", "ar", "ru", "tl", "fr", "it", "uk" })
            Assert.Equal(observanceCount, feast.LocalizedTitle(language).Split("; ").Length);
    }

    [Fact]
    public void SyriacRepeatedEnglishNameKeepsItsDistinctLocalizedIdentity()
    {
        TodayInfoStore.SelectedCalendarId = "syriac";
        var hermit = TodayInfoStore.Feast(new DateOnly(2026, 9, 18));
        var apostle = TodayInfoStore.Feast(new DateOnly(2026, 11, 16));

        Assert.NotNull(hermit);
        Assert.NotNull(apostle);
        Assert.Equal("St. Matthew", hermit.Title);
        Assert.Equal("St. Matthew", apostle.Title);
        Assert.Equal("חג מתי הקדוש המוודה, אב המנזר, דרגה ג׳", hermit.LocalizedTitle("he"));
        Assert.Equal("חג מתי השליח והמבשר", apostle.LocalizedTitle("he"));
        Assert.Equal("Saint Matthew the Hermit, Confessor and Abbot", Assert.Single(hermit.Observances!).Identity);
        Assert.Equal("Saint Matthew, Apostle", Assert.Single(apostle.Observances!).Identity);
        Assert.NotEqual(hermit.LocalizedTitle("ar"), apostle.LocalizedTitle("ar"));
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
            "21st Sunday after Pentecost",
            TodayInfoStore.Feast(new DateOnly(2026, 10, 25))?.Title);
    }

    /// <summary>The explicit Gregorian choice retains the diaspora calendar; the default
    /// Ukrainian choice follows Julian Pascha while retaining Gregorian fixed dates.</summary>
    [Fact]
    public void UkrainianCalendarPraysTheGregorianPascha()
    {
        TodayInfoStore.SelectedCalendarId = "ugcc";
        AppSettings.SetEasternPaschaStyle("gregorian");
        try
        {
            var pascha = TodayInfoStore.Feast(new DateOnly(2026, 4, 5));
            Assert.Equal("The Resurrection of Our Lord — Holy Pascha", pascha?.Title);
            Assert.Equal("Great Feast", pascha?.Rank);
            Assert.Equal("The Protection of the Most Holy Theotokos (Pokrov)",
                TodayInfoStore.Feast(new DateOnly(2026, 10, 1))?.Title);
            Assert.Equal("The Annunciation of the Most Holy Theotokos; Great and Holy Thursday",
                TodayInfoStore.Feast(new DateOnly(2027, 3, 25))?.Title);
        }
        finally { AppSettings.SetEasternPaschaStyle("julian"); }
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
        Assert.Equal(new[] { "קור״א ב׳", "תה׳ קי״ט", "לוק׳ ד׳" },
            readings.Select(r => r.LocalizedShort("he")));
        Assert.Equal("Luke 4:16–30", readings.Last().Full);
        Assert.Equal("הבשורה על־פי לוקס ד׳ 16–30", readings.Last().LocalizedFull("he"));

        // Rite-specific Hebrew reads the same localized citation map instead of falling back to
        // English or rebuilding punctuation at runtime.
        Assert.Equal(readings.Last().LocalizedFull("he"), readings.Last().LocalizedFull("he-x-gamliel"));

        var day = TodayInfoStore.LiturgicalDay(new DateOnly(2026, 8, 31));
        Assert.StartsWith("Monday · Week ", day.English);
        Assert.EndsWith(" of Ordinary Time", day.English);
        Assert.Contains("בזמן הרגיל", day.Hebrew);
        Assert.Contains("השבוע ה־", day.Hebrew);
        Assert.DoesNotContain("ה-", day.Hebrew);
    }

    [Fact]
    public void HebrewEpistleShorthandPreservesFullSourceCitation()
    {
        var corinthians = TodayInfoStore.Readings(new DateOnly(2026, 9, 4)).First();
        Assert.Equal("קור״א ד׳", corinthians.LocalizedShort("he"));
        Assert.Equal(
            "אגרת שאול הראשונה אל הקורינתים ד׳ 1–5",
            corinthians.LocalizedFull("he"));

        var petrine = new ReadingCitation(
            "reading",
            "2 Pet. 2",
            "2 Peter 2:1–3",
            ShortByLanguage: new Dictionary<string, string> { ["he"] = "כיפ״ב ב׳" },
            FullByLanguage: new Dictionary<string, string> { ["he"] = "אגרת כיפא השניה ב׳ 1–3" });
        Assert.Equal("כיפ״ב ב׳", petrine.LocalizedShort("he"));
        Assert.Equal("אגרת כיפא השניה ב׳ 1–3", petrine.LocalizedFull("he"));
    }

    [Fact]
    public void OtherCalendarsLocalizeTheirOwnAppointedReadingsInHebrew()
    {
        TodayInfoStore.SelectedCalendarId = "roman1962";
        var vetus = TodayInfoStore.Readings(new DateOnly(2026, 9, 3));
        Assert.Equal("תס״א ב׳", vetus.First().LocalizedShort("he"));
        Assert.Equal("הבשורה  על־פי יוחנן כ״א 15–17", vetus.Last().LocalizedFull("he"));

        TodayInfoStore.SelectedCalendarId = "ugcc";
        AppSettings.SetEasternPaschaStyle("gregorian");
        try
        {
            var byzantine = TodayInfoStore.Readings(new DateOnly(2026, 9, 3));
            Assert.Equal("גלט׳ ג׳", byzantine.First().LocalizedShort("he"));
            Assert.Equal("אגרת שאול אל הגלטים ג׳ 23–ד׳ 5", byzantine.First().LocalizedFull("he"));
            Assert.Equal("כיפ״ב א׳", TodayInfoStore.Readings(new DateOnly(2026, 8, 6)).First().LocalizedShort("he"));
        }
        finally { AppSettings.SetEasternPaschaStyle("julian"); }

        TodayInfoStore.SelectedCalendarId = "syriac";
        var syriac = TodayInfoStore.Readings(new DateOnly(2026, 9, 3));
        Assert.Equal("פיל׳ א׳", syriac.First().LocalizedShort("he-x-gamliel"));
        Assert.Equal("אגרת שאול אל הפיליפים א׳ 12–21", syriac.First().LocalizedFull("he"));
        Assert.Equal("טימ״ב ב׳", TodayInfoStore.Readings(new DateOnly(2026, 8, 8)).First().LocalizedShort("he"));
        var syriacAugustFirst = TodayInfoStore.Readings(new DateOnly(2026, 8, 1));
        Assert.Equal(new[] { "Hebrews 11:32–40", "Matthew 10:24–33" },
            syriacAugustFirst.Select(r => r.Full));
        Assert.Equal(new[] { "עבר׳ י״א", "מתי י׳" },
            syriacAugustFirst.Select(r => r.LocalizedShort("he")));
    }

    [Fact]
    public void SwitchingCalendarsAlsoReloadsThatCalendarsReadings()
    {
        var date = new DateOnly(2026, 8, 31);

        TodayInfoStore.SelectedCalendarId = "roman";
        Assert.Equal(new[] { "1 Cor. 2", "Ps. 119", "Lk. 4" }, TodayInfoStore.Readings(date).Select(r => r.Short));

        TodayInfoStore.SelectedCalendarId = "roman1962";
        Assert.Equal(new[] { "Sir. 31", "Lk. 12" }, TodayInfoStore.Readings(date).Select(r => r.Short));

        TodayInfoStore.SelectedCalendarId = "ugcc";
        Assert.Equal(new[] { "2 Cor. 12", "Mk. 4", "Heb. 9", "Lk. 10" }, TodayInfoStore.Readings(date).Select(r => r.Short));

        TodayInfoStore.SelectedCalendarId = "syriac";
        Assert.Equal(new[] { "Rom. 7", "Lk. 17" }, TodayInfoStore.Readings(date).Select(r => r.Short));

        // Switching back exercises cache invalidation rather than just first-load behavior.
        TodayInfoStore.SelectedCalendarId = "roman";
        Assert.Equal("1 Cor. 2", TodayInfoStore.Readings(date).First().Short);
    }

    [Theory]
    [InlineData("lpj")]
    [InlineData("roman")]
    [InlineData("roman1962")]
    [InlineData("ugcc")]
    [InlineData("syriac")]
    [InlineData("maronite")]
    public void ReadingsOutsideASelectedCalendarsCoverageAreEmpty(string calendarId)
    {
        TodayInfoStore.SelectedCalendarId = calendarId;
        Assert.Empty(TodayInfoStore.Readings(new DateOnly(2031, 1, 1)));
    }

    [Fact]
    public void MonthOutsideThePublishedListHasNoIntention()
    {
        Assert.Null(TodayInfoStore.Intention(new DateOnly(2031, 5, 1)));
    }
}
