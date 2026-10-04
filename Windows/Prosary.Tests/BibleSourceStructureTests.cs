using System.IO.Compression;
using System.Security.Cryptography;
using System.Text.Json;
using System.Text.Json.Nodes;
using Prosary.Services;
using Prosary.ViewModels;
using Xunit;

namespace Prosary.Tests;

public sealed class BibleSourceStructureTests : IDisposable
{
    private readonly string _directory = Path.Combine(Path.GetTempPath(), "prosary-source-structure-" + Guid.NewGuid().ToString("N"));
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);
    private sealed record Fixture(BibleEdition Edition, byte[] Bytes);
    private static Fixture Make(string? mutation = null)
    {
        var books = new List<BibleBook> {
            new("SIR", "Sirach", [new(11, 2, true), new(12, 2, true), new(41, 1, false), new(51, 1, false)]) {
                AddressRoutes = [new(12, 1, 11, "sir-12-1"), new(12, 2, 11, "sir-12-2")] },
            new("SUS", "Susanna", [new(1, 1, false)]) };
        if (mutation == "missingRoute") books[0] = books[0] with { AddressRoutes = [new(12, 1, 11, "sir-12-1")] };
        if (mutation == "wrongRoute") books[0] = books[0] with { AddressRoutes = [new(12, 1, 11, "sir-11-33"), new(12, 2, 11, "sir-12-2")] };
        if (mutation == "unmovedRoute") books[0] = books[0] with { AddressRoutes = [.. books[0].AddressRoutes!, new(11, 33, 51, "sir-51-13")] };
        if (mutation == "duplicateRoute") books[0] = books[0] with { AddressRoutes = [.. books[0].AddressRoutes!, new(12, 1, 11, "sir-12-1")] };
        if (mutation == "emptyRoutes") books[0] = books[0] with { AddressRoutes = [] };
        var chapters = new List<BibleChapterText> {
            new(3, "rich-bible", "SIR", 11, [new(11, 33, "Eleven thirty-three"), new(11, 34, "Eleven thirty-four")]) {
                ContentBlocks = [new("sir-11-33", "verse", 11, 33), new("sir-12-1", "verse", 12, 1),
                    new("sir-11-34", "verse", 11, 34), new("sir-12-2", "verse", 12, 2)] },
            new(3, "rich-bible", "SIR", 12, [new(12, 1, "Twelve one"), new(12, 2, "Twelve two")]) {
                ContentBlocks = [new("sir-12-heading", "heading", Text: "Printed heading"), new("sir-12-opening", "passage", Text: "Unnumbered opening")] },
            new(3, "rich-bible", "SIR", 41, [new(41, 14, "Primary range", EndVerse: 16)]) {
                ContentBlocks = [new("sir-41-primary", "verse", 41, 14),
                    new("sir-41-b", "witness", Text: "Printed part bet", PrintedLabel: "יד ב", Addresses: [new(41, 14, Part: "ב")]),
                    new("sir-41-a", "witness", Text: "Printed part alef through sixteen", PrintedLabel: "יד א–טז", Addresses: [new(41, 14, 16, "א")])] },
            new(3, "rich-bible", "SIR", 51, [new(51, 13, "First thirteen")]) {
                ContentBlocks = [new("sir-51-title", "heading", Text: "Source heading"), new("sir-51-13", "verse", 51, 13),
                    new("sir-51-13-again", "witness", Text: "Second thirteen", PrintedLabel: "יג", Addresses: [new(51, 13)]),
                    new("sir-thanksgiving", "passage", Text: "Unnumbered thanksgiving"), new("sir-colophon", "colophon", Text: "Printed closing credit")] },
            new(3, "rich-bible", "SUS", 1, [new(1, 40, "Source Susanna", EndVerse: 41)]) {
                ContentBlocks = [new("sus-40", "verse", 1, 40, PrintedLabel: "כ–כא")] }
        };
        var nodes = chapters.ToDictionary(chapter => $"chapters/{chapter.Book}/{chapter.Chapter}.json", chapter => JsonSerializer.SerializeToNode(chapter, Json)!);
        var first = nodes["chapters/SIR/11.json"]["contentBlocks"]!.AsArray();
        var witnesses = nodes["chapters/SIR/41.json"]["contentBlocks"]!.AsArray();
        switch (mutation)
        {
            case "missingPresentation": first.RemoveAt(0); break;
            case "duplicatePresentation": first.Add(first[0]!.DeepClone()); first[^1]!["id"] = "duplicate-primary"; break;
            case "danglingReference": first[0]!["verse"] = 999; break;
            case "rangeInteriorReference": nodes["chapters/SUS/1.json"]["contentBlocks"]![0]!["verse"] = 41; break;
            case "duplicateBlockId": witnesses[1]!["id"] = "sir-11-33"; break;
            case "implicitDuplicate": nodes["chapters/SIR/12.json"].AsObject().Remove("contentBlocks"); break;
            case "emptyBlocks": nodes["chapters/SIR/11.json"]["contentBlocks"] = new JsonArray(); break;
            case "nullBlocks": nodes["chapters/SIR/11.json"]["contentBlocks"] = null; break;
            case "unknownKind": first[0]!["kind"] = "unsupported"; break;
            case "unknownField": first[0]!["text"] = "Forged duplicated text"; break;
            case "nullOptional": first[0]!["printedLabel"] = null; break;
            case "emptyLabel": witnesses[1]!["printedLabel"] = " "; break;
            case "emptyAddresses": witnesses[1]!["addresses"] = new JsonArray(); break;
            case "equivalentAddress":
                witnesses[1]!["addresses"]!.AsArray().Add(witnesses[1]!["addresses"]![0]!.DeepClone());
                witnesses[1]!["addresses"]![1]!["endVerse"] = 14; break;
            case "primaryPair": nodes["chapters/SIR/11.json"]["verses"]![0]!["transliteratedText"] = "alternate"; break;
            case "duplicateAddress": witnesses[1]!["addresses"]!.AsArray().Add(witnesses[1]!["addresses"]![0]!.DeepClone()); break;
            case "missingAddressChapter": witnesses[1]!["addresses"]![0]!["chapter"] = 99; break;
            case "addressOverLimit": witnesses[1]!["addresses"]![0]!["verse"] = 1001; break;
            case "invalidAddressType": witnesses[1]!["addresses"]![0]!["chapter"] = "41"; break;
            case "emptyPart": witnesses[1]!["addresses"]![0]!["part"] = ""; break;
            case "reversedAddress": witnesses[1]!["addresses"]![0]!["endVerse"] = 13; break;
            case "headingNotes": nodes["chapters/SIR/51.json"]["contentBlocks"]![0]!["sourceNotes"] = new JsonArray(); break;
            case "pairedBlock": witnesses[1]!["transliteratedText"] = "Paired"; break;
            case "badBlockId": first[0]!["id"] = "../bad"; break;
            case "nullBlock": first[0] = null; break;
            case "mismatchedChapterVersion": nodes["chapters/SIR/12.json"]["schemaVersion"] = 2; break;
        }
        if (mutation is "validNotes" or "duplicateNoteIds" or "invalidNoteAnchor")
        {
            var source = nodes["chapters/SIR/51.json"]!;
            source["verses"]![0]!["text"] = "בַּקּבָּה";
            source["verses"]![0]!["sourceNotes"] = JsonSerializer.SerializeToNode(new[] { ScriptureSourceNoteTests.ValidNote with { Id = "primary-note" } }, Json);
            var passage = source["contentBlocks"]![3]!;
            passage["text"] = "בַּקּבָּה";
            passage["sourceNotes"] = JsonSerializer.SerializeToNode(new[] { ScriptureSourceNoteTests.ValidNote with {
                Id = mutation == "duplicateNoteIds" ? "primary-note" : "passage-note", Anchor = mutation == "invalidNoteAnchor" ? "absent" : "בַּקּבָּה" } }, Json);
        }
        if (mutation is "colophonNotes" or "colophonDuplicate" or "colophonAnchor" or "colophonGuessedDot")
        {
            var source = nodes["chapters/SIR/51.json"]!;
            var closing = source["contentBlocks"]![4]!;
            var note = ScriptureSourceNoteTests.ValidNote with { Id = "closing-dot", Anchor = "ו", LetterIndex = 1, Mark = "shuruq" };
            closing["text"] = mutation == "colophonGuessedDot" ? "וּ" : "ו";
            closing["sourceNotes"] = JsonSerializer.SerializeToNode(new[] { note with { Anchor = mutation == "colophonAnchor" ? "absent" : "ו" } }, Json);
            if (mutation == "colophonDuplicate")
            {
                source["verses"]![0]!["text"] = "ו";
                source["verses"]![0]!["sourceNotes"] = JsonSerializer.SerializeToNode(new[] { note }, Json);
            }
        }
        var archiveVersion = 3;
        if (mutation is "legacyBlocks1" or "legacyBlocks2" or "legacyEmptyBlocks1" or "legacyEmptyBlocks2")
        {
            archiveVersion = mutation.EndsWith('1') ? 1 : 2;
            books = books.Select(book => new BibleBook(book.Id, book.Name, book.Chapters)).ToList();
            foreach (var chapter in nodes.Values) chapter["schemaVersion"] = archiveVersion;
            if (mutation.StartsWith("legacyEmpty")) nodes["chapters/SIR/11.json"]["contentBlocks"] = new JsonArray();
        }
        var revision = new string('a', 64);
        nodes.Add("manifest.json", JsonSerializer.SerializeToNode(new BibleManifest(archiveVersion, "rich-bible", revision, books), Json)!);
        var entries = nodes.Select(pair => (pair.Key, Bytes: JsonSerializer.SerializeToUtf8Bytes(pair.Value, Json))).ToList();
        using var output = new MemoryStream();
        using (var zip = new ZipArchive(output, ZipArchiveMode.Create, true))
            foreach (var entry in entries) { using var stream = zip.CreateEntry(entry.Key).Open(); stream.Write(entry.Bytes); }
        var bytes = output.ToArray();
        return new(new("rich-bible", "he", "Source Bible", "Source credit", "https://example.org/source", revision,
            BibleLibraryStore.DownloadPrefix + "rich-bible-" + revision + ".zip", Convert.ToHexStringLower(SHA256.HashData(bytes)), bytes.Length,
            entries.Sum(entry => (long)entry.Bytes.Length), books, ArchiveSchemaVersion: archiveVersion), bytes);
    }
    private BibleLibraryStore Store(Fixture fixture) => new(_directory, JsonSerializer.Serialize(new { schemaVersion = 1, editions = new[] { fixture.Edition } }, Json));
    private static Task Install(BibleLibraryStore store, Fixture fixture) => store.InstallAsync(fixture.Edition.Id, new MemoryStream(fixture.Bytes));

    [Fact]
    public async Task ColophonNotesReachDisplayWithoutBecomingScriptureOrVerseChoices()
    {
        var fixture = Make("colophonNotes"); var store = Store(fixture); await Install(store, fixture);
        var display = await store.LoadDisplayChapterAsync("rich-bible", "SIR", 51);
        var rows = BibleVerseRow.FromDisplay(display, null, "Hebr");
        var closing = rows.Single(row => row.IsColophon);
        Assert.Equal("ו", closing.Text);
        Assert.Equal("shuruq", Assert.Single(closing.SourceNotes!).Mark);
        Assert.False(closing.IsScripture);
        Assert.False(closing.IsVerseChoice);
    }

    [Theory]
    [InlineData("colophonDuplicate")][InlineData("colophonAnchor")][InlineData("colophonGuessedDot")]
    public async Task ColophonNotesUseTheSameStrictEvidenceChecks(string mutation)
    {
        var fixture = Make(mutation);
        await Assert.ThrowsAsync<InvalidDataException>(() => Install(Store(fixture), fixture));
    }

    [Fact]
    public async Task InterleavedPrimaryUnitsReopenOfflineAndNumericJumpsFollowExplicitRoutes()
    {
        var fixture = Make(); await Install(Store(fixture), fixture);
        var store = Store(fixture);
        var display = await store.LoadDisplayChapterAsync("rich-bible", "SIR", 11);
        Assert.Equal(new[] { "Eleven thirty-three", "Twelve one", "Eleven thirty-four", "Twelve two" }, display.Units.Select(unit => unit.Primary!.Text));
        Assert.Equal(new BibleAddressTarget(11, "sir-12-1"), await store.ResolveAddressAsync("rich-bible", "SIR", 12, 1));
        Assert.Equal(new BibleAddressTarget(11, "sir-12-2"), await store.ResolveAddressAsync("rich-bible", "SIR", 12, 2));
        Assert.Null(await store.ResolveAddressAsync("rich-bible", "SIR", 12, 3));
        var rows = BibleVerseRow.FromDisplay(display, fixture.Edition.Scripture, "Hebr");
        Assert.Equal(new[] { "33", "י״ב:א׳", "34", "י״ב:ב׳" }, rows.Select(row => row.VerseLabel));
        Assert.Equal(new[] { "heading", "passage" }, (await store.LoadDisplayChapterAsync("rich-bible", "SIR", 12)).Units.Select(unit => unit.Kind));
    }

    [Fact]
    public async Task RepeatedAndOverlappingWitnessesStayVisibleInPhysicalPickerOrder()
    {
        var fixture = Make(); var store = Store(fixture); await Install(store, fixture);
        var rows = BibleVerseRow.FromDisplay(await store.LoadDisplayChapterAsync("rich-bible", "SIR", 51), fixture.Edition.Scripture, "Hebr");
        Assert.Equal(new[] { "heading", "verse", "witness", "passage", "colophon" }, rows.Select(row => row.Kind));
        Assert.Equal(new[] { "sir-51-13", "sir-51-13-again" }, rows.Where(row => row.IsVerseChoice).Select(row => row.Id));
        Assert.Contains("occurrence 2", rows[2].VerseLabel);
        Assert.Equal("Second thirteen", rows[2].Text);
        Assert.False(rows[2].ContainsVerse(13)); // A numeric jump must not choose the second witness.
        Assert.True(rows[3].IsScripture);
        Assert.False(rows[0].IsScripture); Assert.False(rows[4].IsScripture);
        var overlapping = BibleVerseRow.FromDisplay(await store.LoadDisplayChapterAsync("rich-bible", "SIR", 41), fixture.Edition.Scripture, "Hebr");
        Assert.Equal(3, overlapping.Count);
        Assert.Contains("occurrence 2", overlapping[1].VerseLabel); Assert.Contains("occurrence 3", overlapping[2].VerseLabel);
        Assert.Equal(new BibleAddressTarget(41, "sir-41-primary"), await store.ResolveAddressAsync("rich-bible", "SIR", 41, 16));
    }

    [Fact]
    public async Task PrintedLabelIsVisibleWithoutReplacingTheNumericPrimaryRange()
    {
        var fixture = Make(); var store = Store(fixture); await Install(store, fixture);
        var row = Assert.Single(BibleVerseRow.FromDisplay(await store.LoadDisplayChapterAsync("rich-bible", "SUS", 1), fixture.Edition.Scripture, "Hebr"));
        Assert.Equal("40–41", row.VerseLabel); Assert.Equal("כ–כא", row.PrintedLabel);
        Assert.Contains("Printed label:", row.PrintedLabelAnnotation); Assert.Contains("כ–כא", row.PrintedLabelAnnotation);
        Assert.DoesNotContain("כ–כא", row.DisplayText);
        Assert.Equal(new BibleAddressTarget(1, "sus-40"), await store.ResolveAddressAsync("rich-bible", "SUS", 1, 41));
    }

    [Theory]
    [InlineData("missingPresentation")][InlineData("duplicatePresentation")][InlineData("danglingReference")]
    [InlineData("rangeInteriorReference")][InlineData("duplicateBlockId")][InlineData("implicitDuplicate")]
    [InlineData("missingRoute")][InlineData("wrongRoute")][InlineData("unmovedRoute")][InlineData("duplicateRoute")][InlineData("emptyRoutes")]
    [InlineData("emptyBlocks")][InlineData("nullBlocks")][InlineData("unknownKind")][InlineData("unknownField")]
    [InlineData("nullOptional")][InlineData("emptyLabel")][InlineData("emptyAddresses")][InlineData("duplicateAddress")][InlineData("equivalentAddress")][InlineData("primaryPair")]
    [InlineData("missingAddressChapter")][InlineData("addressOverLimit")][InlineData("invalidAddressType")][InlineData("emptyPart")]
    [InlineData("reversedAddress")][InlineData("headingNotes")][InlineData("pairedBlock")][InlineData("badBlockId")][InlineData("nullBlock")]
    [InlineData("duplicateNoteIds")][InlineData("invalidNoteAnchor")][InlineData("mismatchedChapterVersion")]
    [InlineData("legacyBlocks1")][InlineData("legacyBlocks2")][InlineData("legacyEmptyBlocks1")][InlineData("legacyEmptyBlocks2")]
    public async Task RejectsMalformedSourceStructureBeforeInstallation(string mutation)
    {
        var fixture = Make(mutation); var store = Store(fixture);
        await Assert.ThrowsAsync<InvalidDataException>(() => Install(store, fixture));
        Assert.True(!Directory.Exists(_directory) || Directory.GetFiles(_directory).Length == 0);
    }
    [Fact]
    public async Task VersionThreeNotesSpanPrimaryAndUnnumberedScripture()
    {
        var fixture = Make("validNotes"); var store = Store(fixture); await Install(store, fixture);
        var rows = BibleVerseRow.FromDisplay(await store.LoadDisplayChapterAsync("rich-bible", "SIR", 51), fixture.Edition.Scripture, "Hebr");
        Assert.Equal("primary-note", Assert.Single(rows[1].SourceNotes!).Id);
        Assert.Equal("passage-note", Assert.Single(rows[3].SourceNotes!).Id);
    }
    [Theory][InlineData(1)][InlineData(2)]
    public void OlderVersionsRejectBookRoutesIncludingEmptyArrays(int version)
    {
        var fixture = Make();
        Assert.Empty(Store(fixture with { Edition = fixture.Edition with { ArchiveSchemaVersion = version } }).Editions);
        var books = fixture.Edition.Books.Select(book => book with { AddressRoutes = [] }).ToList();
        Assert.Empty(Store(fixture with { Edition = fixture.Edition with { ArchiveSchemaVersion = version, Books = books } }).Editions);
    }
    [Theory]
    [InlineData("{\"chapter\":1,\"verse\":1,\"displayChapter\":2,\"blockId\":\"v\",\"extra\":1}")]
    [InlineData("{\"chapter\":1,\"verse\":1,\"displayChapter\":2,\"blockId\":null}")]
    [InlineData("{\"chapter\":true,\"verse\":1,\"displayChapter\":2,\"blockId\":\"v\"}")]
    public void RoutesRejectUnknownNullOrWronglyTypedFields(string json) => Assert.Throws<JsonException>(() => JsonSerializer.Deserialize<BibleAddressRoute>(json, Json));
    [Fact]
    public void CatalogRejectsExplicitNullRoutesAndZeroPrimaryCounts()
    {
        var fixture = Make();
        var catalog = JsonSerializer.SerializeToNode(new { schemaVersion = 1, editions = new[] { fixture.Edition } }, Json)!;
        catalog["editions"]![0]!["books"]![0]!["addressRoutes"] = null;
        Assert.Empty(BibleLibraryStore.ParseCatalog(catalog.ToJsonString()));
        var books = fixture.Edition.Books.ToList();
        books[0] = books[0] with { Chapters = [new(11, 0, false)] };
        Assert.Empty(Store(fixture with { Edition = fixture.Edition with { Books = books } }).Editions);
    }

    [Fact]
    public async Task LazyReaderOpensDirectPrimaryReferencesButNotUnrelatedChapters()
    {
        var fixture = Make(); var store = Store(fixture); await Install(store, fixture);
        void Damage(int chapter)
        {
            using var zip = ZipFile.Open(Path.Combine(_directory, "rich-bible.zip"), ZipArchiveMode.Update);
            var name = $"chapters/SIR/{chapter}.json";
            zip.GetEntry(name)!.Delete();
            using var writer = new StreamWriter(zip.CreateEntry(name).Open()); writer.Write("malformed JSON");
        }
        Damage(51);
        Assert.Equal(4, (await store.LoadDisplayChapterAsync("rich-bible", "SIR", 11)).Units.Count);
        Damage(12); // Chapter 12 is directly referenced by chapter 11, so it must be opened and checked.
        await Assert.ThrowsAsync<InvalidDataException>(() => store.LoadDisplayChapterAsync("rich-bible", "SIR", 11));
    }

    [Fact]
    public async Task ForgedRichArchiveDigestCannotReplaceVerifiedOfflineContent()
    {
        var fixture = Make(); var store = Store(fixture); await Install(store, fixture);
        var forged = fixture with { Edition = fixture.Edition with { ArchiveSHA256 = new string('0', 64) } };
        await Assert.ThrowsAsync<InvalidDataException>(() => Install(Store(forged), forged));
        Assert.Equal(4, (await store.LoadDisplayChapterAsync("rich-bible", "SIR", 11)).Units.Count);
        Assert.Single(Directory.GetFiles(_directory));
    }
    [Theory]
    [InlineData("Hebr", "Syrc")][InlineData("Syrc", "Hebr")][InlineData("Hebr", null)][InlineData(null, "Syrc")]
    public void VersionThreeRejectsAnyDeclaredPairedScript(string? primary, string? alternate)
    {
        var fixture = Make();
        Assert.Empty(Store(fixture with { Edition = fixture.Edition with { TextScript = primary, TransliteratedTextScript = alternate } }).Editions);
    }
    [Theory]
    [InlineData("he", "י״א:ל״ד–ל״ה")][InlineData("ar", "١١:٣٤–٣٥")][InlineData("en", "11:34–35")]
    public void MovedRangeLabelsUseEditionNumeralsInRowsAndPicker(string language, string expected)
    {
        var chapter = new BibleChapterText(3, "source", "SIR", 12, [new(12, 1, "Local")]);
        var display = new BibleDisplayChapter(chapter, [new("moved", "verse", new(11, 34, "Moved", EndVerse: 35)), new("local", "verse", chapter.Verses[0])]);
        var edition = new ScriptureEdition("source", language, "Source", "Credit", "https://example.org");
        var rows = BibleVerseRow.FromDisplay(display, edition, "Hebr");
        Assert.Equal(expected, rows[0].VerseLabel); Assert.Contains(expected, rows[0].DisplayText);
        Assert.Equal("1", rows[1].VerseLabel);
    }
    [Fact]
    public void CanonicalChapterRowsIdentifySourceLabelsAndKeepDistinctLiteralAnnotations()
    {
        var chapter = new BibleChapterText(3, "source", "SUS", 1, [new(1, 40, "Source", EndVerse: 41)]);
        var display = new BibleDisplayChapter(chapter, [new("sus-range", "verse", chapter.Verses[0], PrintedLabel: "כ–כא")]);
        var row = Assert.Single(BibleVerseRow.FromDisplay(display, null, "Hebr", usesPrintedLabels: true));
        Assert.Contains("Printed label:", row.VerseLabel);
        Assert.Contains("כ–כא", row.VerseLabel);
        Assert.Equal("Source", row.DisplayText);
        Assert.True(row.HasPrintedLabel);
        Assert.Contains("כ–כא", row.PrintedLabelAnnotation);
        Assert.Contains("40–41", (row with { PrintedLabel = null }).PrintedLabelAnnotation);
        Assert.Equal((row with { PrintedLabel = "40–41" }).VerseLabel,
            (row with { PrintedLabel = "40–41" }).PrintedLabelAnnotation);
        Assert.True(row.ContainsVerse(40));
        Assert.True(row.ContainsVerse(41));
    }
    public void Dispose() { if (Directory.Exists(_directory)) Directory.Delete(_directory, true); }
}
