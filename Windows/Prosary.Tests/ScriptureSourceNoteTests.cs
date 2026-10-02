using System.Text.Json;
using System.Text.Json.Nodes;
using Prosary.Services;
using Prosary.ViewModels;
using Xunit;

namespace Prosary.Tests;

public sealed class ScriptureSourceNoteTests
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);
    public static ScriptureSourceNote ValidNote => new("lje-1-9-qoph-vowel", "unreadablePoint", "בַּקּבָּה", 1, 2, "vowel", [16], "https://example.org/source.pdf#page=16");
    private static ScriptureVerse Verse => new(1, 9, "בַּקּבָּה", SourceNotes: [ValidNote]);

    [Fact]
    public void ExactAnchorCountsHebrewLettersAndRetainsOtherReadableMarks()
    {
        var verse = Verse with { Text = "בַּקּבָּה / בַּקּבָּה", SourceNotes = [ValidNote with { Occurrence = 2 }] };
        Assert.True(ScriptureSourceNote.ValidForVerse(verse, false));
        Assert.Equal("ק", verse.SourceNotes![0].Letter());
        Assert.Equal("בַּקּבָּה", verse.SourceNotes[0].Anchor);
        var dagesh = new ScriptureVerse(1, 1, "בַ", SourceNotes: [ValidNote with { Anchor = "בַ", LetterIndex = 1, Mark = "dagesh" }]);
        Assert.True(ScriptureSourceNote.ValidForVerse(dagesh, false));
    }

    [Fact]
    public void VowelNotePreservesOnlyTheExplicitlyReviewedReadableCompanion()
    {
        var note = ValidNote with { Anchor = "לִם", LetterIndex = 1, RetainedVowels = ["ִ"] };
        var verse = new ScriptureVerse(1, 1, "לִם", SourceNotes: [note]);
        Assert.NotNull(Daily(verse));
        Assert.Equal("לִם", Daily(verse)!.Verses[0].Text);
        Assert.False(ScriptureSourceNote.ValidForVerse(verse with { SourceNotes = [note with { RetainedVowels = null }] }, false));
        Assert.False(ScriptureSourceNote.ValidForVerse(verse with { SourceNotes = [note with { RetainedVowels = ["ָ"] }] }, false));
        Assert.False(ScriptureSourceNote.ValidForVerse(verse with { Text = "לִָם", SourceNotes = [note with { Anchor = "לִָם" }] }, false));
        Assert.False(ScriptureSourceNote.ValidForVerse(verse with { Text = "לִִם", SourceNotes = [note with { Anchor = "ל" }] }, false));
    }

    [Theory]
    [InlineData("כָּלְתָה", 2, "ל")]
    [InlineData("כָּלְתָה", 1, "כ")]
    public void RestoredLetterKeepsReadableVowelAndDageshInPrimaryText(string text, int letterIndex, string letter)
    {
        var note = ValidNote with { Id = "wis-1-16-restored-letter", Kind = "restoredLetter", Mark = "consonant",
            Anchor = text, LetterIndex = letterIndex };
        var verse = new ScriptureVerse(1, 16, text, SourceNotes: [note]);
        Assert.True(ScriptureSourceNote.ValidForVerse(verse, false));
        var passage = Assert.IsType<ScripturePassage>(Daily(verse));
        var restored = Assert.Single(passage.Verses[0].SourceNotes!);
        Assert.Equal(text, passage.Verses[0].Text);
        Assert.Equal(letter, restored.Letter());
        Assert.Equal("restoredLetter", restored.Kind);
        Assert.Equal(note.SourceURL, restored.SourceURL);
    }

    [Theory]
    [InlineData("unreadablePoint", "consonant")]
    [InlineData("restoredLetter", "vowel")]
    [InlineData("restoredLetter", "dagesh")]
    [InlineData("restoredLetter", "letter")]
    [InlineData("unknown", "consonant")]
    public void SourceNoteKindsAcceptOnlyTheirOwnMarkCategories(string kind, string mark)
    {
        var note = ValidNote with { Kind = kind, Mark = mark };
        var verse = Verse with { SourceNotes = [note] };
        Assert.False(ScriptureSourceNote.ValidForVerse(verse, false));
        Assert.Null(Daily(verse));
    }

    [Theory]
    [InlineData("null")]
    [InlineData("[]")]
    [InlineData("[\"ְ\"]")]
    public void RestoredLetterRejectsAnyRetainedVowelsFieldIncludingNull(string retainedJson)
    {
        var note = ValidNote with { Kind = "restoredLetter", Mark = "consonant", Anchor = "כָּלְתָה", LetterIndex = 2 };
        var verse = new ScriptureVerse(1, 16, note.Anchor, SourceNotes: [note]);
        var row = JsonSerializer.SerializeToNode(verse, Json)!;
        row["sourceNotes"]![0]!["retainedVowels"] = JsonNode.Parse(retainedJson);
        Assert.Throws<JsonException>(() => JsonSerializer.Deserialize<ScriptureVerse>(row.ToJsonString(), Json));
        Assert.False(ScriptureSourceNote.ValidForVerse(verse with { SourceNotes = [note with { RetainedVowels = ["ְ"] }] }, false));
    }

    [Theory]
    [InlineData("empty")]
    [InlineData("multiple")]
    [InlineData("duplicate")]
    [InlineData("letter")]
    [InlineData("multipleScalars")]
    [InlineData("dagesh")]
    public void InvalidCompanionDeclarationsCannotAuthorizeAGuessedMark(string mutation)
    {
        var values = mutation switch { "empty" => new List<string>(), "multiple" => ["ִ", "ָ"], "duplicate" => ["ִ", "ִ"],
            "letter" => ["א"], "multipleScalars" => ["ִָ"], _ => new List<string> { "ִ" } };
        var note = ValidNote with { RetainedVowels = values, Mark = mutation == "dagesh" ? "dagesh" : "vowel" };
        Assert.Null(Daily(Verse with { SourceNotes = [note] }));
    }

    [Theory]
    [InlineData("anchor")]
    [InlineData("occurrence")]
    [InlineData("negativeOccurrence")]
    [InlineData("letter")]
    [InlineData("zeroLetter")]
    [InlineData("kind")]
    [InlineData("mark")]
    [InlineData("id")]
    [InlineData("emptyPages")]
    [InlineData("zeroPage")]
    [InlineData("duplicatePages")]
    [InlineData("descendingPages")]
    [InlineData("http")]
    [InlineData("credentials")]
    [InlineData("urlWhitespace")]
    [InlineData("guessedVowel")]
    [InlineData("guessedQamatsQatan")]
    [InlineData("guessedDagesh")]
    [InlineData("shortenedAnchor")]
    [InlineData("duplicateId")]
    [InlineData("duplicatePosition")]
    [InlineData("pairedText")]
    [InlineData("emptyNotes")]
    [InlineData("nullNote")]
    public void InvalidNotesMakeTheCompleteDailyPassageUnavailable(string mutation)
    {
        var verse = Verse;
        var note = ValidNote;
        note = mutation switch
        {
            "anchor" => note with { Anchor = "אחר" },
            "occurrence" => note with { Occurrence = 2 },
            "negativeOccurrence" => note with { Occurrence = 0 },
            "letter" => note with { LetterIndex = 5 },
            "zeroLetter" => note with { LetterIndex = 0 },
            "kind" => note with { Kind = "translation" },
            "mark" => note with { Mark = "consonant" },
            "id" => note with { Id = "Invalid ID" },
            "emptyPages" => note with { SourcePages = [] },
            "zeroPage" => note with { SourcePages = [0] },
            "duplicatePages" => note with { SourcePages = [16, 16] },
            "descendingPages" => note with { SourcePages = [17, 16] },
            "http" => note with { SourceURL = "http://example.org/source.pdf" },
            "credentials" => note with { SourceURL = "https://user:password@example.org/source.pdf" },
            "urlWhitespace" => note with { SourceURL = "https://example.org/source file.pdf" },
            "guessedVowel" => note with { Anchor = "בַּקֻּבָּה" },
            "guessedQamatsQatan" => note with { Anchor = "בַּקׇּבָּה" },
            "guessedDagesh" => note with { Mark = "dagesh" },
            "shortenedAnchor" => note with { Anchor = "בַּק" },
            _ => note,
        };
        verse = verse with { SourceNotes = [note] };
        if (mutation is "guessedVowel" or "guessedQamatsQatan") verse = verse with { Text = note.Anchor };
        if (mutation == "shortenedAnchor") verse = verse with { Text = "בַּקֻּבָּה" };
        if (mutation == "duplicateId") verse = verse with { SourceNotes = [note, note] };
        if (mutation == "duplicatePosition") verse = verse with { SourceNotes = [note, note with { Id = "other-quote", Anchor = "קּבָּה", LetterIndex = 1 }] };
        if (mutation == "pairedText") verse = verse with { TransliteratedText = "ܐ" };
        if (mutation == "emptyNotes") verse = verse with { SourceNotes = [] };
        if (mutation == "nullNote") verse = verse with { SourceNotes = [null!] };
        Assert.False(ScriptureSourceNote.ValidForVerse(verse, false));
        Assert.Null(Daily(verse));
    }

    [Fact]
    public void DailyVersionOneRetainsValidNotesAndPrimaryTextUnchanged()
    {
        var passage = Daily(Verse);
        Assert.NotNull(passage);
        Assert.Equal(Verse.Text, passage.Verses[0].Text);
        Assert.Equal(ValidNote.Id, Assert.Single(passage.Verses[0].SourceNotes!).Id);
        Assert.False(ScriptureSourceNote.ValidForVerse(Verse, true));
    }

    [Theory]
    [InlineData("missingField")]
    [InlineData("unknownField")]
    [InlineData("nullNotes")]
    [InlineData("nonIntegerPosition")]
    [InlineData("fieldCase")]
    [InlineData("nullAlternate")]
    [InlineData("nullRetainedVowels")]
    public void MalformedJsonCannotSilentlyDiscardRequiredNotes(string mutation)
    {
        var row = JsonSerializer.SerializeToNode(Verse, Json)!;
        var note = row["sourceNotes"]![0]!.AsObject();
        if (mutation == "missingField") note.Remove("occurrence");
        if (mutation == "unknownField") note["comment"] = "unknown";
        if (mutation == "nullNotes") row["sourceNotes"] = null;
        if (mutation == "nonIntegerPosition") note["letterIndex"] = 1.5;
        if (mutation == "fieldCase") { note.Remove("kind"); note["Kind"] = "unreadablePoint"; }
        if (mutation == "nullAlternate") row["transliteratedText"] = null;
        if (mutation == "nullRetainedVowels") note["retainedVowels"] = null;
        Assert.Throws<JsonException>(() => JsonSerializer.Deserialize<ScriptureVerse>(row.ToJsonString(), Json));
    }

    [Fact]
    public void DailyReaderKeepsDisclosuresAttachedToTheVerseAndOutsideSelectableText()
    {
        var store = DailyStore(Verse);
        var reader = new ReadingPassageViewModel(store, store.Editions[0], "daily",
            new ReadingCitation("reading", "Letter of Jeremiah 1:9", "Letter of Jeremiah 1:9"), "en", "context", "configuration") { IsExpanded = true };
        var row = Assert.Single(Assert.Single(reader.Chapters).Verses!);
        Assert.Equal(Verse.Text, row.Text);
        Assert.Equal(ValidNote.Id, Assert.Single(row.SourceNotes!).Id);
        Assert.Contains(Verse.Text, reader.PassageText);
        Assert.DoesNotContain(ValidNote.Id, reader.PassageText);
        Assert.DoesNotContain(ValidNote.SourceURL, row.DisplayText);
    }

    private static ScripturePassage? Daily(ScriptureVerse verse) => DailyStore(verse).LoadPassage("daily", "Letter of Jeremiah 1:9", "he-test");
    [Fact]
    public void DailyPassageRejectsRepeatedIdsAcrossDifferentVerses()
    {
        var store = DailyStore(Verse, second: Verse with { Verse = 10 });
        Assert.Null(store.LoadPassage("daily", "Letter of Jeremiah 1:9", "he-test"));
    }

    [Theory]
    [InlineData("Hebr", null)]
    [InlineData(null, "Syrc")]
    [InlineData("Latn", "Grek")]
    public void AnyDeclaredScriptMetadataRejectsPrimaryOnlyAnchors(string? textScript, string? alternateScript)
    {
        var store = DailyStore(Verse, textScript: textScript, alternateScript: alternateScript);
        Assert.Null(store.LoadPassage("daily", "Letter of Jeremiah 1:9", "he-test"));
    }

    private static ReadingsTextStore DailyStore(ScriptureVerse verse, ScriptureVerse? second = null, string? textScript = null, string? alternateScript = null)
    {
        var edition = new ScriptureEdition("he-test", "he", "Hebrew source", "Source credit", "https://example.org/source", textScript, alternateScript);
        var json = JsonSerializer.Serialize(new { schemaVersion = 1, editions = new[] { edition },
            passages = new Dictionary<string, Dictionary<string, ScriptureVerse[]>> {
                ["daily|Letter of Jeremiah 1:9"] = new() { [edition.Id] = second is null ? [verse] : [verse, second] }
            } }, Json);
        return new ReadingsTextStore(() => json);
    }
}
