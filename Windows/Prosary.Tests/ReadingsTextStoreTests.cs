using Prosary.Services;
using Prosary.Models;
using Prosary.ViewModels;
using Xunit;

namespace Prosary.Tests;

public class ReadingsTextStoreTests
{
    private const string PairedFixture = """
        {"schemaVersion":1,"editions":[{"id":"peshitta-1905","languageCode":"arc","name":"Fixture Peshitta",
        "attribution":"Fixture credit","sourceURL":"https://example.test","textScript":"Hebr","transliteratedTextScript":"Syrc"}],
        "passages":{"daily|Fixture 1:1":{"peshitta-1905":[{"chapter":1,"verse":1,"text":"בדיקה","transliteratedText":"ܐܒܓ"}]}}}
        """;
    private const string Fixture = """
        {"schemaVersion":1,"editions":[
          {"id":"fixture-en","languageCode":"en","name":"English fixture","attribution":"Fixture credit","sourceURL":"https://example.test/en"},
          {"id":"fixture-he","languageCode":"he","name":"Hebrew fixture","attribution":"Fixture credit","sourceURL":"https://example.test/he"},
          {"id":"fixture-tl","languageCode":"tl","name":"Tagalog fixture","attribution":"Fixture credit","sourceURL":"https://example.test/tl"}],
         "passages":{
          "daily|John 3:16":{"fixture-en":[{"chapter":3,"verse":16,"text":"Exact fixture text."}]},
          "torah|Genesis 1:1":{"fixture-he":[{"chapter":1,"verse":1,"text":"טקסט לבדיקה"}]},
          "daily|Damaged":{"fixture-en":[{"chapter":1,"verse":1,"text":"Valid part"},{"chapter":1,"verse":2,"text":""}]}
        }}
        """;

    [Fact]
    public void MetadataSelectionDoesNotReadThePassageCorpus()
    {
        var metadataReads = 0;
        var textReads = 0;
        var store = new ReadingsTextStore(() => { textReads++; return Fixture; },
            () => { metadataReads++; return Fixture; });
        Assert.Equal(0, metadataReads);
        Assert.Equal("fixture-en", store.ResolveEdition("", "en-US")?.Id);
        Assert.Equal(1, metadataReads);
        Assert.Equal(0, textReads);
        Assert.Single(store.Passage("daily", "John 3:16", "fixture-en"));
        Assert.Single(store.Passage("daily", "John 3:16", "fixture-en"));
        Assert.Equal(1, textReads);
    }

    [Fact]
    public void AutomaticEditionUsesLanguageAliasesWithoutAnEnglishFallback()
    {
        var store = new ReadingsTextStore(() => Fixture);
        Assert.Equal("fixture-he", store.ResolveEdition("", "iw-IL")?.Id);
        Assert.Equal("fixture-tl", store.ResolveEdition("", "fil-PH")?.Id);
        Assert.Null(store.ResolveEdition("", "ar"));
        Assert.Null(store.ResolveEdition("removed-edition", "en"));
        Assert.Equal("fixture-en", store.ResolveEdition("fixture-en", "he")?.Id);
    }

    [Fact]
    public void MissingEditionScopeOrExactCitationDoesNotBorrowAnotherPassage()
    {
        var store = new ReadingsTextStore(() => Fixture);
        Assert.Empty(store.Passage("daily", "John 3:16", "fixture-he"));
        Assert.Empty(store.Passage("torah", "John 3:16", "fixture-en"));
        Assert.Empty(store.Passage("daily", "John 3:16 ", "fixture-en"));
        Assert.Empty(store.Passage("daily", "Damaged", "fixture-en"));
        Assert.Equal("טקסט לבדיקה", Assert.Single(store.Passage("torah", "Genesis 1:1", "fixture-he")).Text);
    }

    [Fact]
    public void AvailableEditionsRequireACompletePassageInTheExactScope()
    {
        var store = new ReadingsTextStore(() => Fixture);
        Assert.Equal(["fixture-en"], store.AvailableEditions("daily", "John 3:16").Select(edition => edition.Id));
        Assert.Empty(store.AvailableEditions("torah", "John 3:16"));
        Assert.Empty(store.AvailableEditions("daily", "John 3:16 "));
        Assert.Empty(store.AvailableEditions("daily", "Damaged"));
        var incompletePair = new ReadingsTextStore(() => PairedFixture.Replace("\"transliteratedText\":\"ܐܒܓ\"", "\"transliteratedText\":\"\""));
        Assert.Empty(incompletePair.AvailableEditions("daily", "Fixture 1:1"));
    }

    [Fact]
    public void UnavailableReaderOffersAvailableEditionsWithoutChangingThePreferenceUntilChosen()
    {
        var previous = AppSettings.ReadingsEditionId;
        try
        {
            AppSettings.SetReadingsEditionId("fixture-he");
            var store = new ReadingsTextStore(() => Fixture);
            var row = new ReadingPassageViewModel(store, store.ResolveEdition("fixture-he", "en"), "daily",
                new ReadingCitation("gospel", "Jn 3:16", "John 3:16"), "en", "context", "configuration");
            Assert.Empty(row.AvailableEditions);
            row.IsExpanded = true;
            Assert.True(row.IsUnavailable);
            Assert.True(row.HasAvailableEditions);
            Assert.Equal("fixture-he", AppSettings.ReadingsEditionId);
            var choice = Assert.Single(row.AvailableEditions);
            Assert.Equal("English fixture", choice.Label);
            row.SelectedAvailableEdition = new ReadingEditionChoice("fixture-tl", "Not available");
            Assert.Equal("fixture-he", AppSettings.ReadingsEditionId);
            row.SelectedAvailableEdition = choice;
            Assert.Equal("fixture-en", AppSettings.ReadingsEditionId);
        }
        finally { AppSettings.SetReadingsEditionId(previous); }
    }

    [Fact]
    public void WholeVerseMetadataIsOptionalAndMatchesTheOriginalScopedCitation()
    {
        var legacy = new ReadingsTextStore(() => Fixture);
        Assert.False(legacy.LoadPassage("daily", "John 3:16", "fixture-en")!.IncludesWholeVerses);

        var store = new ReadingsTextStore(() => Fixture
            .Replace("\"passages\":{", "\"wholeVersePassages\":[\"daily|John 3:16b\",\"daily|Damaged\"],\"passages\":{")
            .Replace("\"daily|John 3:16\":", "\"daily|John 3:16b\":"));
        var passage = store.LoadPassage("daily", "John 3:16b", "fixture-en");
        Assert.NotNull(passage);
        Assert.True(passage.IncludesWholeVerses);
        Assert.Equal("Exact fixture text.", Assert.Single(passage.Verses).Text);
        Assert.False(store.LoadPassage("torah", "Genesis 1:1", "fixture-he")!.IncludesWholeVerses);
        Assert.Null(store.LoadPassage("torah", "John 3:16b", "fixture-en"));
        Assert.Null(store.LoadPassage("daily", "John 3:16b ", "fixture-en"));
        Assert.Null(store.LoadPassage("daily", "John 3:16b", "fixture-he"));
        Assert.Null(store.LoadPassage("daily", "Damaged", "fixture-en"));
    }

    [Theory]
    [InlineData("fixture-en", true)]
    [InlineData("fixture-he", false)]
    public void ReaderShowsTheWholeVerseNoticeOnlyForAnAvailableExpandedPassage(string editionId, bool expectedNotice)
    {
        var store = new ReadingsTextStore(() => Fixture
            .Replace("\"passages\":{", "\"wholeVersePassages\":[\"daily|John 3:16b\"],\"passages\":{")
            .Replace("\"daily|John 3:16\":", "\"daily|John 3:16b\":"));
        var row = new ReadingPassageViewModel(store, store.ResolveEdition(editionId, "en"), "daily",
            new ReadingCitation("gospel", "Jn 3:16b", "John 3:16b"), "en", "context", "configuration");
        Assert.False(row.IncludesWholeVerses);
        row.IsExpanded = true;
        Assert.Equal(expectedNotice, row.HasPassage);
        Assert.Equal(expectedNotice, row.IncludesWholeVerses);
        Assert.Equal("John 3:16b", row.Citation);
    }

    [Theory]
    [InlineData("not-json")]
    [InlineData("{\"schemaVersion\":2,\"editions\":[],\"passages\":{}}")]
    public void InvalidOrUnsupportedCorpusIsUnavailable(string json)
    {
        var store = new ReadingsTextStore(() => json);
        Assert.Empty(store.Editions);
        Assert.Empty(store.Passage("daily", "John 3:16", "fixture-en"));
    }

    [Fact]
    public void ExpandingLooksUpRawCitationWhileDisplayingItsLocalizedFullTitle()
    {
        var reads = 0;
        var store = new ReadingsTextStore(() => { reads++; return Fixture; }, () => Fixture);
        var edition = store.ResolveEdition("fixture-en", "he");
        var citation = new ReadingCitation("gospel", "Jn 3:16", "John 3:16",
            FullByLanguage: new() { ["he"] = "כותרת לבדיקה" });
        var row = new ReadingPassageViewModel(store, edition, "daily", citation, "he", "context", "configuration");
        Assert.Equal("כותרת לבדיקה", row.Citation);
        Assert.Equal(0, reads);
        row.IsExpanded = true;
        Assert.True(row.HasPassage);
        Assert.False(row.IncludesWholeVerses);
        Assert.Contains("Exact fixture text.", row.PassageText);
        Assert.False(row.IsRightToLeft);
        Assert.Equal("Fixture credit", row.Attribution);
        Assert.Equal(1, reads);
        row.IsExpanded = false;
        row.IsExpanded = true;
        Assert.Equal(1, reads);
    }
    [Fact]
    public void ReaderPreservesTheCorporaHebrewMarksAndUsesItsEditionDirection()
    {
        const string authored = "יהו֑ה";
        var store = new ReadingsTextStore(() => Fixture.Replace("טקסט לבדיקה", authored));
        var edition = store.ResolveEdition("", "he");
        var row = new ReadingPassageViewModel(store, edition, "torah",
            new ReadingCitation("torah", "Gen 1:1", "Genesis 1:1"), "en", "context", "configuration");
        row.IsExpanded = true;
        Assert.True(row.IsRightToLeft);
        Assert.True(row.HasPassage);
        Assert.Contains(authored, row.PassageText);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData(" ")]
    public void PairedScriptPassageRejectsMissingOrEmptyAlternateInsteadOfMixingScripts(string? alternate)
    {
        var replacement = alternate is null ? "\"unused\":true" : $"\"transliteratedText\":\"{alternate}\"";
        var store = new ReadingsTextStore(() => PairedFixture.Replace("\"transliteratedText\":\"ܐܒܓ\"", replacement));
        Assert.True(store.Editions.Single().HasAramaicScripts);
        Assert.Null(store.LoadPassage("daily", "Fixture 1:1", "peshitta-1905"));
    }

    [Fact]
    public void AramaicReaderFollowsDefaultUntilLocalToggleAndRendersTheSelectedScript()
    {
        var previous = AppSettings.AramaicDefaultScript;
        try
        {
            AppSettings.SetAramaicDefaultScript("Syrc");
            var store = new ReadingsTextStore(() => PairedFixture);
            var edition = store.ResolveEdition("peshitta-1905", "en");
            var row = new ReadingPassageViewModel(store, edition, "daily",
                new ReadingCitation("reading", "Fixture", "Fixture 1:1"), "en", "context", "configuration") { IsExpanded = true };
            Assert.True(row.HasScriptToggle);
            Assert.Contains("ܐܒܓ", row.PassageText);
            Assert.DoesNotContain("בדיקה", row.PassageText);
            Assert.True(row.IsRightToLeft);
            Assert.Equal(PrayerTypography.ResolveBodyFontFamily("arc", true, PrayerTypography.Script.Syriac), row.BodyFontFamily);

            AppSettings.SetAramaicDefaultScript("Hebr");
            row.RefreshTypography();
            Assert.Contains("בדיקה", row.PassageText);
            Assert.Equal(PrayerTypography.ResolveBodyFontFamily("arc", true, PrayerTypography.Script.Hebrew), row.BodyFontFamily);
            row.ToggleScriptCommand.Execute(null);
            Assert.Equal("Syrc", row.ScriptOverride);
            Assert.Equal("Hebr", AppSettings.AramaicDefaultScript);
            row.IsExpanded = false;
            row.RefreshTypography();
            row.IsExpanded = true;
            Assert.Contains("ܐܒܓ", row.PassageText);
            Assert.True(row.IsRightToLeft);
        }
        finally { AppSettings.SetAramaicDefaultScript(previous); }
    }

}
