using Prosary.Services;
using Prosary.ViewModels;
using Xunit;

namespace Prosary.Tests;

public class ReadingsTextStoreTests
{
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

}
