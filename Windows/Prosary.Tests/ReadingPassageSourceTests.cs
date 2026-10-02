using System.Text.Json;
using System.Text.Json.Nodes;
using Prosary.Models;
using Prosary.Services;
using Prosary.ViewModels;
using Xunit;

namespace Prosary.Tests;

public sealed class ReadingPassageSourceTests
{
    private const string Fixture = """
        {"schemaVersion":1,"editions":[{"id":"hebrew","languageCode":"he","name":"Base Bible",
          "attribution":"Base credit","sourceURL":"https://example.test/base"}],
         "passages":{"daily|Fixture":{"hebrew":[
          {"chapter":4,"verse":2,"endVerse":3,"text":"בַּקּבָּה"},
          {"chapter":3,"verse":1,"text":"Second chapter"},
          {"chapter":4,"verse":5,"text":"Return to chapter"}]},
          "daily|Ordinary":{"hebrew":[{"chapter":1,"verse":1,"text":"Ordinary text"}]}},
         "wholeVersePassages":["daily|Fixture"],
         "passageSources":{"daily|Fixture":{"hebrew":{"book":"SIR","name":"Source title",
          "attribution":"Actual translator credit","sourceURL":"https://example.test/source","isComplete":false,
          "contentBlocks":[
           {"id":"first","kind":"verse","chapter":4,"verse":2,"printedLabel":"ב–ג"},
           {"id":"variant","kind":"witness","printedLabel":"ב","text":"Distinct witness","addresses":[{"chapter":4,"verse":2}]},
           {"id":"unnumbered","kind":"passage","text":"בַּקּבָּה"},
           {"id":"second","kind":"verse","chapter":3,"verse":1},
           {"id":"third","kind":"verse","chapter":4,"verse":5}]}}}}
        """;
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);
    private static JsonNode Note(string id) => JsonSerializer.SerializeToNode(
        ScriptureSourceNoteTests.ValidNote with { Id = id }, Json)!;
    private static JsonNode Data()
    {
        var data = JsonNode.Parse(Fixture)!;
        data["passages"]!["daily|Fixture"]!["hebrew"]![0]!["sourceNotes"] = new JsonArray(Note("primary-point"));
        data["passageSources"]!["daily|Fixture"]!["hebrew"]!["contentBlocks"]![2]!["sourceNotes"] = new JsonArray(Note("passage-point"));
        return data;
    }
    private static ReadingsTextStore Store(JsonNode data) => new(() => data.ToJsonString());

    [Fact]
    public void ActualSourceCreditAndWholeOrderedBlocksReachTheReader()
    {
        var store = Store(Data());
        var passage = Assert.IsType<ScripturePassage>(store.LoadPassage("daily", "Fixture", "hebrew"));
        Assert.True(passage.IncludesWholeVerses);
        Assert.False(passage.Source!.IsComplete);
        var displays = passage.SourceDisplays(store.Editions[0])!;
        Assert.Equal(new[] { 4, 3, 4 }, displays.Select(display => display.Chapter.Chapter));
        Assert.Equal(new[] { "first", "variant", "unnumbered", "second", "third" },
            displays.SelectMany(display => display.Units).Select(unit => unit.Id));
        var row = new ReadingPassageViewModel(store, store.Editions[0], "daily",
            new ReadingCitation("reading", "Fixture", "Fixture"), "en", "context", "configuration");
        Assert.False(row.HasSourceName);
        row.IsExpanded = true;
        Assert.True(row.HasSourceName);
        Assert.True(row.IsPartial);
        Assert.Equal("Base Bible", row.EditionName);
        Assert.Equal("Source title", row.SourceName);
        Assert.Equal("Actual translator credit", row.Attribution);
        Assert.Equal(new Uri("https://example.test/source"), row.SourceUri);
        Assert.Equal(new[] { 4, 3, 4 }, row.Chapters.Select(chapter => chapter.Number));
        var first = row.Chapters[0].Verses!;
        Assert.Equal(new[] { "verse", "witness", "passage" }, first.Select(unit => unit.Kind));
        Assert.Equal("2–3", first[0].VerseLabel);
        Assert.Equal("ב–ג", first[0].PrintedLabel);
        Assert.True(first[0].HasPrintedLabel);
        Assert.Equal("primary-point", Assert.Single(first[0].SourceNotes!).Id);
        Assert.Equal("passage-point", Assert.Single(first[2].SourceNotes!).Id);
        Assert.Contains("Distinct witness", row.PassageText);
        Assert.DoesNotContain("\u20660\u2069", first[2].DisplayText);
    }

    [Fact]
    public void DescriptorWithoutBlocksKeepsSourceCreditAndOrdinaryOrderedRows()
    {
        var data = Data(); data["passageSources"]!["daily|Fixture"]!["hebrew"]!.AsObject().Remove("contentBlocks");
        var store = Store(data);
        var passage = Assert.IsType<ScripturePassage>(store.LoadPassage("daily", "Fixture", "hebrew"));
        Assert.Null(passage.SourceDisplays(store.Editions[0]));
        Assert.Equal("Source title", passage.Source!.Name);
        Assert.Equal(new[] { 4, 3, 4 }, passage.Verses.Select(row => row.Chapter));
        var ordinary = Assert.IsType<ScripturePassage>(store.LoadPassage("daily", "Ordinary", "hebrew"));
        Assert.Null(ordinary.Source);
    }

    [Theory]
    [InlineData("unknownField")][InlineData("missingCredit")][InlineData("blankName")]
    [InlineData("wrongBook")][InlineData("httpSource")][InlineData("credentials")]
    [InlineData("nullCompleteness")][InlineData("stringCompleteness")]
    [InlineData("nullBlocks")][InlineData("emptyBlocks")][InlineData("nullBlock")]
    [InlineData("badBlockId")][InlineData("duplicateBlockId")][InlineData("unknownKind")]
    [InlineData("missingPrimary")][InlineData("duplicatePrimary")][InlineData("danglingPrimary")]
    [InlineData("rangeInterior")][InlineData("wrongOrder")][InlineData("overlappingPrimary")]
    [InlineData("duplicateNoteIds")][InlineData("invalidBlockAnchor")]
    [InlineData("emptyWitnessAddresses")][InlineData("nullWitnessAddress")][InlineData("duplicateWitnessAddress")]
    [InlineData("pairedRow")][InlineData("pairedEdition")]
    public void InvalidDescriptorCannotFallBackToUncreditedOrFlattenedText(string mutation)
    {
        var data = Data();
        var source = data["passageSources"]!["daily|Fixture"]!["hebrew"]!;
        var blocks = source["contentBlocks"]!.AsArray();
        var verses = data["passages"]!["daily|Fixture"]!["hebrew"]!.AsArray();
        switch (mutation)
        {
            case "unknownField": source["translatorGuess"] = "Other"; break;
            case "missingCredit": source.AsObject().Remove("attribution"); break;
            case "blankName": source["name"] = " "; break;
            case "wrongBook": source["book"] = "Sirach"; break;
            case "httpSource": source["sourceURL"] = "http://example.test/source"; break;
            case "credentials": source["sourceURL"] = "https://user:password@example.test/source"; break;
            case "nullCompleteness": source["isComplete"] = null; break;
            case "stringCompleteness": source["isComplete"] = "false"; break;
            case "nullBlocks": source["contentBlocks"] = null; break;
            case "emptyBlocks": source["contentBlocks"] = new JsonArray(); break;
            case "nullBlock": blocks[1] = null; break;
            case "badBlockId": blocks[1]!["id"] = "Bad ID"; break;
            case "duplicateBlockId": blocks[1]!["id"] = "first"; break;
            case "unknownKind": blocks[1]!["kind"] = "invented"; break;
            case "missingPrimary": blocks.RemoveAt(4); break;
            case "duplicatePrimary": blocks.Add(blocks[0]!.DeepClone()); blocks[^1]!["id"] = "duplicate"; break;
            case "danglingPrimary": blocks[4]!["verse"] = 99; break;
            case "rangeInterior": blocks[0]!["verse"] = 3; break;
            case "wrongOrder":
                var first = blocks[0]!.DeepClone(); blocks[0] = blocks[4]!.DeepClone(); blocks[4] = first; break;
            case "overlappingPrimary": verses[2]!["verse"] = 3; blocks[4]!["verse"] = 3; break;
            case "duplicateNoteIds": blocks[2]!["sourceNotes"]![0]!["id"] = "primary-point"; break;
            case "invalidBlockAnchor": blocks[2]!["text"] = "Different text"; break;
            case "emptyWitnessAddresses": blocks[1]!["addresses"] = new JsonArray(); break;
            case "nullWitnessAddress": blocks[1]!["addresses"]![0] = null; break;
            case "duplicateWitnessAddress": blocks[1]!["addresses"]!.AsArray().Add(blocks[1]!["addresses"]![0]!.DeepClone()); break;
            case "pairedRow": verses[1]!["transliteratedText"] = "ܐ"; break;
            case "pairedEdition": data["editions"]![0]!["transliteratedTextScript"] = "Syrc"; break;
        }
        var store = Store(data);
        Assert.Null(store.LoadPassage("daily", "Fixture", "hebrew"));
        Assert.Empty(store.AvailableEditions("daily", "Fixture"));
    }

    [Theory]
    [InlineData("null")][InlineData("[]")][InlineData("{}")]
    public void PresentMalformedSourceTableIsNotTreatedAsAbsent(string sourceTable)
    {
        var data = Data(); data["passageSources"] = JsonNode.Parse(sourceTable);
        Assert.Null(Store(data).LoadPassage("daily", "Fixture", "hebrew"));
    }

    [Theory]
    [InlineData("key")][InlineData("edition")]
    public void OrphanedSourceDescriptorsAreRejected(string mutation)
    {
        var data = Data();
        if (mutation == "key") data["passages"]!.AsObject().Remove("daily|Fixture");
        else data["passageSources"]!["daily|Fixture"]!["unknown"] = data["passageSources"]!["daily|Fixture"]!["hebrew"]!.DeepClone();
        Assert.Null(Store(data).LoadPassage("daily", "Fixture", "hebrew"));
    }

    [Theory]
    [InlineData("daily", "")][InlineData("torah", "")]
    [InlineData("daily", "   ")][InlineData("torah", "   ")]
    [InlineData("daily", "\t\r\n")][InlineData("torah", "\t\r\n")]
    [InlineData("daily", "\u00a0")][InlineData("torah", "\u00a0")]
    public void EmptySourceCitationIsRejectedEvenWithMatchingPassage(string scope, string citation)
    {
        var data = Data();
        var key = $"{scope}|{citation}";
        foreach (var tableName in new[] { "passages", "passageSources" })
        {
            var table = data[tableName]!.AsObject();
            var value = table["daily|Fixture"]!.DeepClone();
            table.Remove("daily|Fixture");
            table[key] = value;
        }
        data["wholeVersePassages"] = new JsonArray(key);
        var store = Store(data);
        Assert.Empty(store.Editions);
        Assert.Null(store.LoadPassage(scope, citation, "hebrew"));
    }

    [Fact]
    public void DuplicateDescriptorFieldsAreRejected()
    {
        var json = Fixture.Replace("\"isComplete\":false", "\"isComplete\":false,\"isComplete\":true");
        Assert.Null(new ReadingsTextStore(() => json).LoadPassage("daily", "Fixture", "hebrew"));
    }
}
