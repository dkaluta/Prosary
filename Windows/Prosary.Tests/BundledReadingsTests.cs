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
    public void BundledCatalogHasEightEditionsAndPreservesTheSevenFullBibleEditions()
    {
        Assert.Equal(8, Store.Editions.Count);
        Assert.Equal(new[] { "ar", "en", "fr", "he", "it", "ru", "tl", "uk" },
            Store.Editions.Select(edition => edition.LanguageCode).Order());
        foreach (var edition in Store.Editions)
        {
            Assert.NotNull(edition.SourceUri);
            Assert.False(string.IsNullOrWhiteSpace(edition.Attribution));
            // Arabic currently contains only the passages reviewed against the old print.
            if (edition.LanguageCode == "ar") continue;
            var passage = Store.Passage("daily", "Luke 6:27–38", edition.Id);
            Assert.Equal(Enumerable.Range(27, 12), passage.Select(verse => verse.Verse));
            Assert.All(passage, verse => Assert.Equal(6, verse.Chapter));
            Assert.All(passage, verse => Assert.False(string.IsNullOrWhiteSpace(verse.Text)));
        }
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
    public void SelectingAnotherDateReplacesExpandedRowsAndMissingDateClearsThem()
    {
        var previousEdition = AppSettings.ReadingsEditionId;
        try
        {
            AppSettings.SetReadingsEditionId("douay-rheims-1899");
            var today = new HomeViewModel(new EmptyPresetStore(), new LiturgicalCalendarService());
            var reader = new DesktopReadingsViewModel(Store);
            today.SelectedTodayDate = new DateTimeOffset(2026, 9, 10, 0, 0, 0, TimeSpan.Zero);
            today.TodayReadings = [new ReadingCitation("gospel", "Lk", "Luke 6:27–38")];
            reader.Refresh(today);
            var first = Assert.Single(reader.Daily);
            first.IsExpanded = true;
            Assert.True(first.HasPassage);

            // Even if two appointed dates happen to repeat a citation, each day
            // has its own expansion state. An unrelated timer refresh retains it.
            reader.Refresh(today);
            Assert.Same(first, Assert.Single(reader.Daily));
            today.SelectedTodayDate = today.SelectedTodayDate!.Value.AddDays(1);
            today.TodayReadings = [new ReadingCitation("gospel", "Lk", "Luke 6:27–38")];
            reader.Refresh(today);
            var second = Assert.Single(reader.Daily);
            Assert.NotSame(first, second);
            Assert.False(second.IsExpanded);
            Assert.Empty(second.PassageText);

            today.SelectedTodayDate = today.MaximumTodayDate;
            reader.Refresh(today);
            Assert.Empty(reader.Daily);
            Assert.Empty(reader.Torah);
        }
        finally { AppSettings.SetReadingsEditionId(previousEdition); }
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
