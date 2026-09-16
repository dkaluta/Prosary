using Prosary.Models;
using Prosary.Persistence;
using Prosary.Services;
using Prosary.ViewModels;
using Xunit;

namespace Prosary.Tests;

public class BundledReadingsTests
{
    private static ReadingsTextStore Store => ReadingsTextStore.Default;

    [Theory]
    [InlineData("1 Corinthians 8:1b–7; 8:11–13", 8, new[] { 1, 2, 3, 4, 5, 6, 7, 11, 12, 13 })]
    [InlineData("Psalm 139:1–3; 139:13–14ab; 139:23–24", 138, new[] { 1, 2, 3, 4, 13, 14, 23, 24 })]
    public void SeptemberTenthPartialReferencesOpenWholeVersesWithNotice(string citation, int chapter, int[] verseNumbers)
    {
        var edition = Store.ResolveEdition("douay-rheims-1899", "en");
        Assert.NotNull(edition);
        var passage = Store.LoadPassage("daily", citation, edition.Id);
        Assert.NotNull(passage);
        Assert.True(passage.IncludesWholeVerses);
        Assert.Equal(verseNumbers, passage.Verses.Select(verse => verse.Verse));
        Assert.All(passage.Verses, verse => Assert.Equal(chapter, verse.Chapter));
        Assert.All(passage.Verses, verse => Assert.False(string.IsNullOrWhiteSpace(verse.Text)));

        var row = new ReadingPassageViewModel(Store, edition, "daily",
            new ReadingCitation("reading", "Reading", citation), "en", "date", "edition");
        row.IsExpanded = true;
        Assert.True(row.HasPassage);
        Assert.True(row.IncludesWholeVerses);
        Assert.Equal(citation, row.Citation);
        Assert.Contains(passage.Verses.First().Text, row.PassageText);
        Assert.False(Store.LoadPassage("daily", "Luke 6:27–38", edition.Id)!.IncludesWholeVerses);
    }

    [Fact]
    public void SeptemberThirteenthReadingsUseTheSelectedEditionsNumbering()
    {
        var cases = new (string Citation, IEnumerable<string> Expected)[]
        {
            ("Sirach 27:30; 28:1–7", new[] { "27:33" }.Concat(Enumerable.Range(1, 9).Select(v => $"28:{v}"))),
            ("Psalm 103:1–2; 103:3–4; 103:9–10; 103:11–12", new[] { 1, 2, 3, 4, 9, 10, 11, 12 }.Select(v => $"102:{v}")),
            ("Romans 14:7–9", Enumerable.Range(7, 3).Select(v => $"14:{v}")),
            ("Matthew 18:21–35", Enumerable.Range(21, 15).Select(v => $"18:{v}"))
        };
        foreach (var (citation, expected) in cases)
        {
            var passage = Store.LoadPassage("daily", citation, "douay-rheims-1899");
            Assert.NotNull(passage);
            Assert.Equal(expected, passage.Verses.Select(v => $"{v.Chapter}:{v.Verse}"));
            Assert.All(passage.Verses, verse => Assert.False(string.IsNullOrWhiteSpace(verse.Text)));
        }
        var psalmEditions = new Dictionary<string, int>
        {
            ["douay-rheims-1899"] = 102, ["synodal-1876"] = 102,
            ["masoretic-delitzsch"] = 103, ["ang-dating-biblia-1905"] = 103,
            ["crampon-1923"] = 103, ["kulish-1905"] = 103
        };
        foreach (var (editionId, chapter) in psalmEditions)
        {
            var psalm = Store.LoadPassage("daily", cases[1].Citation, editionId);
            Assert.NotNull(psalm);
            Assert.Equal(new[] { 1, 2, 3, 4, 9, 10, 11, 12 }, psalm.Verses.Select(v => v.Verse));
            Assert.All(psalm.Verses, verse => Assert.Equal(chapter, verse.Chapter));
            Assert.True(psalm.IncludesWholeVerses);
        }
        foreach (var editionId in new[] { "martini", "jesuit-arabic-1897" })
            Assert.Null(Store.LoadPassage("daily", cases[1].Citation, editionId));
        var french = Store.LoadPassage("daily", cases[0].Citation, "crampon-1923");
        Assert.NotNull(french);
        Assert.Equal(new[] { "27:30" }.Concat(Enumerable.Range(1, 7).Select(v => $"28:{v}")),
            french.Verses.Select(v => $"{v.Chapter}:{v.Verse}"));
        Assert.All(french.Verses, verse => Assert.False(string.IsNullOrWhiteSpace(verse.Text)));
        Assert.Null(Store.LoadPassage("daily", cases[0].Citation, "masoretic-delitzsch"));
    }

    [Fact]
    public void BundledCatalogHasNineEditionsAndPreservesTheSevenFullBibleEditions()
    {
        Assert.Equal(9, Store.Editions.Count);
        Assert.Equal(new[] { "ar", "arc", "en", "fr", "he", "it", "ru", "tl", "uk" },
            Store.Editions.Select(edition => edition.LanguageCode).Order());
        foreach (var edition in Store.Editions)
        {
            Assert.NotNull(edition.SourceUri);
            Assert.False(string.IsNullOrWhiteSpace(edition.Attribution));
            // Arabic currently contains only the passages reviewed against the old print.
            if (edition.LanguageCode is "ar" or "arc") continue;
            var passage = Store.Passage("daily", "Luke 6:27–38", edition.Id);
            Assert.Equal(Enumerable.Range(27, 12), passage.Select(verse => verse.Verse));
            Assert.All(passage, verse => Assert.Equal(6, verse.Chapter));
            Assert.All(passage, verse => Assert.False(string.IsNullOrWhiteSpace(verse.Text)));
        }
    }

    [Fact]
    public void BundledPeshittaCarriesBothScriptsForTheSameOrderedVerses()
    {
        var edition = Store.ResolveEdition("peshitta-1905", "en");
        Assert.NotNull(edition);
        Assert.True(edition.HasAramaicScripts);
        Assert.Equal("arc", edition.LanguageCode);
        var passage = Store.LoadPassage("daily", "Luke 6:27–38", edition.Id);
        Assert.NotNull(passage);
        Assert.Equal(Enumerable.Range(27, 12), passage.Verses.Select(verse => verse.Verse));
        Assert.All(passage.Verses, verse =>
        {
            Assert.Equal(6, verse.Chapter);
            Assert.Equal(PrayerTypography.Script.Hebrew, PrayerTypography.ScriptOf(verse.DisplayedText(edition, "Hebr")));
            Assert.Equal(PrayerTypography.Script.Syriac, PrayerTypography.ScriptOf(verse.DisplayedText(edition, "Syrc")));
            Assert.Equal(verse.TransliteratedText, verse.DisplayedText(edition, "Syrc"));
        });
    }

    [Fact]
    public void BundledOldJesuitArabicOpensReviewedPassagesWithoutBorrowingMissingText()
    {
        var edition = Store.ResolveEdition("", "ar-LB");
        Assert.NotNull(edition);
        Assert.Equal("jesuit-arabic-1897", edition.Id);
        Assert.Contains("1897", edition.Name);
        Assert.NotNull(edition.SourceUri);
        Assert.False(string.IsNullOrWhiteSpace(edition.Attribution));

        var verses = Store.Passage("daily", "Luke 1:26–38", edition.Id);
        Assert.Equal(Enumerable.Range(26, 13), verses.Select(verse => verse.Verse));
        Assert.All(verses, verse => Assert.Equal(1, verse.Chapter));
        Assert.Equal("فقالت مريم هاءنذا أمة الرب فليكن لي بحسب قولك. وانصرف الملاك من عندها.", verses.Last().Text);
        var row = new ReadingPassageViewModel(Store, edition, "daily",
            new ReadingCitation("gospel", "Lk", "Luke 1:26–38"), "en", "date", "edition");
        row.IsExpanded = true;
        Assert.True(row.IsRightToLeft);
        Assert.Contains(verses.Last().Text, row.PassageText);

        Assert.Empty(Store.Passage("daily", "Luke 6:27–38", edition.Id));
        Assert.Empty(Store.Passage("torah", "Genesis 47:28–50:26", edition.Id));
    }

    [Fact]
    public void BundledHebrewNewTestamentKeepsSourceVowelsAndTheUnpointedDivineName()
    {
        var edition = Store.ResolveEdition("", "iw-IL");
        Assert.NotNull(edition);
        Assert.Equal("masoretic-delitzsch", edition.Id);
        Assert.DoesNotContain("ללא ניקוד", edition.Attribution);
        Assert.Contains("1901", edition.Attribution);
        Assert.Contains("delitz.fr", edition.Attribution);
        Assert.Equal("https://delitz.fr/12/", edition.SourceURL);

        foreach (var citation in new[] { "Luke 6:27–38", "1 Corinthians 8:1b–7; 8:11–13" })
        {
            var verses = Store.Passage("daily", citation, edition.Id);
            Assert.NotEmpty(verses);
            Assert.All(verses, verse => Assert.True(verse.Text.Any(IsVowelPoint)));
            var row = new ReadingPassageViewModel(Store, edition, "daily",
                new ReadingCitation("reading", "Reading", citation), "en", "date", "edition");
            row.IsExpanded = true;
            Assert.True(row.IsRightToLeft);
            Assert.All(verses, verse => Assert.Contains(verse.Text, row.PassageText));
            Assert.Equal(edition.Attribution, row.Attribution);
            Assert.Equal(edition.SourceUri, row.SourceUri);
        }

        var annunciation = Store.Passage("daily", "Luke 1:26–38", edition.Id);
        const string marks = @"[\u0591-\u05BD\u05BF\u05C1\u05C2\u05C4\u05C5\u05C7]*";
        var names = System.Text.RegularExpressions.Regex.Matches(
            string.Join(" ", annunciation.Select(verse => verse.Text)), $"י{marks}ה{marks}ו{marks}ה{marks}");
        Assert.NotEmpty(names);
        Assert.All(names.Cast<System.Text.RegularExpressions.Match>(), name => Assert.False(name.Value.Any(IsVowelPoint)));

        static bool IsVowelPoint(char character) => character is >= '\u05B0' and <= '\u05BC' or '\u05C7';
    }

    [Fact]
    public void BundledHebrewTorahKeepsCantillationIncludingOnTheDivineName()
    {
        var edition = Store.ResolveEdition("", "iw-IL");
        Assert.Equal("masoretic-delitzsch", edition?.Id);
        var verses = Store.Passage("torah", "Deuteronomy 11:26–16:17", edition!.Id);
        var verse = Assert.Single(verses.Where(item => item.Chapter == 11 && item.Verse == 27));
        Assert.Equal("אֶֽת־הַבְּרָכָ֑ה אֲשֶׁ֣ר תִּשְׁמְע֗וּ אֶל־מִצְוֹת֙ יהו֣ה אֱלֹֽהֵיכֶ֔ם אֲשֶׁ֧ר אָנֹכִ֛י מְצַוֶּ֥ה אֶתְכֶ֖ם הַיֹּֽום׃", verse.Text);
        var row = new ReadingPassageViewModel(Store, edition, "torah",
            new ReadingCitation("torah", "Dt", "Deuteronomy 11:26–16:17"), "en", "date", "edition");
        row.IsExpanded = true;
        Assert.True(row.IsRightToLeft);
        Assert.Contains(verse.Text, row.PassageText);
    }

    [Fact]
    public void BundledMissingLanguageScopeOrCitationNeverBorrowsText()
    {
        Assert.Null(Store.ResolveEdition("", "es"));
        Assert.Null(Store.ResolveEdition("removed-edition", "en"));
        Assert.Empty(Store.Passage("daily", "Luke 6:27–38", "removed-edition"));
        Assert.Empty(Store.Passage("torah", "Luke 6:27–38", "douay-rheims-1899"));
        Assert.Empty(Store.Passage("daily", "Luke 6:27–38 ", "douay-rheims-1899"));
        Assert.Empty(Store.Passage("daily", "Luke 999:1", "douay-rheims-1899"));
        Assert.Equal("ang-dating-biblia-1905", Store.ResolveEdition("", "fil-PH")?.Id);
    }

    [Fact]
    public void PassagesExpandOnEntryAndContextChangesWhileRefreshKeepsUserCollapses()
    {
        var previousEdition = AppSettings.ReadingsEditionId;
        var previousCalendar = TodayInfoStore.SelectedCalendarId;
        try
        {
            AppSettings.SetReadingsEditionId("douay-rheims-1899");
            var today = new HomeViewModel(new EmptyPresetStore(), new LiturgicalCalendarService());
            var reader = new DesktopReadingsViewModel(Store);
            today.SelectedTodayDate = new DateTimeOffset(2026, 9, 10, 0, 0, 0, TimeSpan.Zero);
            today.TodayReadings = [new ReadingCitation("gospel", "Lk", "Luke 6:27–38")];
            today.TodayTorahPortion = new TorahPortion("2026-09-12", "Vayechi", null, false,
                [new ReadingCitation("torah", "Gn", "Genesis 47:28–50:26")], null);
            reader.Open(today);
            var first = Assert.Single(reader.Daily);
            Assert.True(first.IsExpanded);
            Assert.True(first.HasPassage);
            var torah = Assert.Single(reader.Torah);
            Assert.True(torah.IsExpanded);
            first.IsExpanded = false;
            torah.IsExpanded = false;

            // Even if two appointed dates happen to repeat a citation, each day
            // has its own expansion state. An unrelated timer refresh retains it.
            reader.Refresh(today);
            Assert.Same(first, Assert.Single(reader.Daily));
            Assert.False(first.IsExpanded);
            Assert.Same(torah, Assert.Single(reader.Torah));
            Assert.False(torah.IsExpanded);

            AppSettings.SetReadingsEditionId("masoretic-delitzsch");
            reader.Refresh(today);
            Assert.False(Assert.Single(reader.Daily).IsExpanded);
            Assert.False(Assert.Single(reader.Torah).IsExpanded);
            reader.Open(today);
            Assert.True(Assert.Single(reader.Daily).IsExpanded);
            Assert.True(Assert.Single(reader.Torah).IsExpanded);

            today.SelectedTodayDate = today.SelectedTodayDate!.Value.AddDays(1);
            today.TodayReadings = [new ReadingCitation("gospel", "Lk", "Luke 6:27–38")];
            today.TodayTorahPortion = new TorahPortion("2026-09-12", "Vayechi", null, false,
                [new ReadingCitation("torah", "Gn", "Genesis 47:28–50:26")], null);
            reader.Refresh(today);
            var second = Assert.Single(reader.Daily);
            Assert.NotSame(first, second);
            Assert.True(second.IsExpanded);
            Assert.True(second.HasPassage);
            var secondTorah = Assert.Single(reader.Torah);
            Assert.True(secondTorah.IsExpanded);
            second.IsExpanded = false;
            secondTorah.IsExpanded = false;

            // A calendar change opens the new appointments even when their
            // citations happen to match those in the previous calendar.
            TodayInfoStore.SelectedCalendarId = TodayInfoStore.ResolvedCalendarId == "roman" ? "roman1962" : "roman";
            reader.Refresh(today);
            Assert.True(Assert.Single(reader.Daily).IsExpanded);
            Assert.True(Assert.Single(reader.Torah).IsExpanded);

            today.SelectedTodayDate = today.MaximumTodayDate;
            reader.Refresh(today);
            Assert.Empty(reader.Daily);
            Assert.Empty(reader.Torah);
        }
        finally
        {
            AppSettings.SetReadingsEditionId(previousEdition);
            TodayInfoStore.SelectedCalendarId = previousCalendar;
        }
    }

    private sealed class EmptyPresetStore : IPresetStore
    {
        public Task<List<Prayer>> GetAllAsync() => Task.FromResult(new List<Prayer>());
        public Task<Prayer?> GetDefaultAsync(PrayerKind kind) => Task.FromResult<Prayer?>(null);
        public Task<Prayer?> GetAsync(Guid id) => Task.FromResult<Prayer?>(null);
        public Task SaveAsync(Prayer prayer) => Task.CompletedTask;
        public Task<bool> UpdateIfPresentAsync(Prayer prayer) => Task.FromResult(false);
        public Task DeleteAsync(Prayer prayer) => Task.CompletedTask;
    }
}
