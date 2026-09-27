using System.IO.Compression;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Prosary.Services;
using Prosary.ViewModels;
using Xunit;

namespace Prosary.Tests;

public sealed class BibleLibraryStoreTests : IDisposable
{
    private readonly string _directory = Path.Combine(Path.GetTempPath(), "prosary-bible-tests-" + Guid.NewGuid().ToString("N"));
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);
    private sealed record Fixture(BibleEdition Edition, byte[] Bytes);
    private static List<BibleBook> Books => [new("GEN", "Genesis", [new(1, 2, false), new(3, 1, true)]),
        new("EXO", "Exodus", [new(2, 1, true)])];

    private static Fixture Make(string id = "test-bible", string revision = "a", string? mutation = null, bool paired = false, string? introduction = null)
    {
        var books = Books;
        books[0] = books[0] with { Introduction = introduction };
        if (mutation == "sourceOrder") books[0].Chapters[0] = new(1, 5, false);
        var manifest = new BibleManifest(1, id, new string(revision[0], 64), books);
        var entries = new List<(string Name, byte[] Bytes)>();
        void Add(string name, object value) => entries.Add((name, JsonSerializer.SerializeToUtf8Bytes(value, Json)));
        Add("manifest.json", mutation == "manifest" ? manifest with { EditionId = "wrong" } : manifest);
        foreach (var book in books)
        foreach (var chapter in book.Chapters)
        {
            // A partial chapter deliberately has a gap: source labels must remain 2 and 4.
            var labels = chapter.Number == 1 ? new[] { 2, 4 } : new[] { 1 };
            if (mutation == "sourceOrder" && chapter.Number == 1) labels = [24, 26, 27, 25, 28];
            var verses = labels.Select(number => new ScriptureVerse(chapter.Number, number, "Source " + number,
                paired ? "Paired " + number : null)).ToList();
            if (book.Id == "GEN" && chapter.Number == 1)
            {
                if (mutation == "duplicateVerse") verses[1] = verses[1] with { Verse = 2 };
                if (mutation == "descendingVerse") verses.Reverse();
                if (mutation == "wrongChapter") verses[0] = verses[0] with { Chapter = 2 };
                if (mutation == "emptyText") verses[0] = verses[0] with { Text = " " };
                if (mutation == "missingPair") verses[0] = verses[0] with { TransliteratedText = null };
                if (mutation == "verseCount") verses.RemoveAt(0);
                if (mutation == "combined") verses[0] = verses[0] with { EndVerse = 3 };
                if (mutation == "overlappingRange") verses[0] = verses[0] with { EndVerse = 4 };
                if (mutation == "reversedRange") verses[0] = verses[0] with { EndVerse = 1 };
                if (mutation == "nonAdjacentOverlap") { verses.Reverse(); verses[1] = verses[1] with { EndVerse = 4 }; }
            }
            Add($"chapters/{book.Id}/{chapter.Number}.json", new BibleChapterText(1, id, book.Id, chapter.Number, verses));
        }
        if (mutation == "traversal") entries.Add(("../outside.json", Encoding.UTF8.GetBytes("{}")));
        if (mutation == "directory") entries.Add(("chapters/", []));
        if (mutation == "duplicateEntry") entries.Add(entries[1]);
        if (mutation == "missingEntry") entries.RemoveAt(1);
        if (mutation == "oversizeEntry") entries[1] = (entries[1].Name, new byte[BibleLibraryStore.MaxChapterBytes + 1]);
        using var bytes = new MemoryStream();
        using (var archive = new ZipArchive(bytes, ZipArchiveMode.Create, true))
            foreach (var (name, data) in entries)
            {
                using var output = archive.CreateEntry(name).Open();
                output.Write(data);
            }
        var raw = bytes.ToArray();
        var edition = new BibleEdition(id, paired ? "arc" : "en", "Test Bible", "Source credit", "https://example.org/source",
            manifest.Revision, BibleLibraryStore.DownloadPrefix + id + "-" + manifest.Revision + ".zip",
            Convert.ToHexStringLower(SHA256.HashData(raw)), raw.Length, entries.Sum(entry => (long)entry.Bytes.Length), books,
            paired ? "Hebr" : null, paired ? "Syrc" : null);
        return new(edition, raw);
    }
    private BibleLibraryStore Store(params Fixture[] fixtures) => new(_directory,
        JsonSerializer.Serialize(new { schemaVersion = 1, editions = fixtures.Select(fixture => fixture.Edition) }, Json));
    private static Task Install(BibleLibraryStore store, Fixture fixture, CancellationToken cancellation = default) =>
        store.InstallAsync(fixture.Edition.Id, new MemoryStream(fixture.Bytes, false), cancellationToken: cancellation);

    [Fact]
    public void BundledCatalogKeepsEveryEditionAndSourceBookInventory()
    {
        var json = File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "Data", "bible-catalog.json"));
        using var document = JsonDocument.Parse(json);
        var editions = BibleLibraryStore.ParseCatalog(json);
        Assert.Equal(document.RootElement.GetProperty("editions").GetArrayLength(), editions.Count);
        Assert.Equal(10, editions.Count);
        Assert.Contains(editions, edition => edition.Id == "brenton-lxx");
        Assert.All(editions, edition => Assert.All(edition.Books, book => Assert.NotEmpty(book.Chapters)));
    }

    [Fact]
    public async Task InstalledArchiveReopensOfflineAndPreservesPartialSourceVerseLabels()
    {
        var fixture = Make(paired: true);
        var store = Store(fixture);
        await Install(store, fixture);
        var reopened = Store(fixture);
        var installed = await reopened.InstalledAsync(fixture.Edition.Id);
        Assert.NotNull(installed);
        Assert.False(installed.Books[0].Chapters[0].IsComplete);
        var chapter = await reopened.LoadChapterAsync(fixture.Edition.Id, "GEN", 1);
        Assert.Equal(new[] { 2, 4 }, chapter.Verses.Select(verse => verse.Verse));
        Assert.Equal("Source 2", chapter.Verses[0].DisplayedText(fixture.Edition.Scripture, "Hebr"));
        Assert.Equal("Paired 2", chapter.Verses[0].DisplayedText(fixture.Edition.Scripture, "Syrc"));
        await Assert.ThrowsAsync<InvalidDataException>(() => reopened.LoadChapterAsync(fixture.Edition.Id, "GEN", 2));
    }

    [Theory]
    [InlineData("manifest")]
    [InlineData("duplicateVerse")]
    [InlineData("wrongChapter")]
    [InlineData("emptyText")]
    [InlineData("missingPair")]
    [InlineData("verseCount")]
    [InlineData("traversal")]
    [InlineData("directory")]
    [InlineData("duplicateEntry")]
    [InlineData("missingEntry")]
    [InlineData("oversizeEntry")]
    [InlineData("overlappingRange")]
    [InlineData("reversedRange")]
    [InlineData("nonAdjacentOverlap")]
    public async Task RejectsMalformedArchiveWithoutInstallingOrLeavingTemporaryFiles(string mutation)
    {
        var fixture = Make(mutation: mutation, paired: true);
        var store = Store(fixture);
        await Assert.ThrowsAsync<InvalidDataException>(() => Install(store, fixture));
        Assert.Null(await store.InstalledAsync(fixture.Edition.Id));
        Assert.Empty(Directory.GetFiles(_directory));
    }

    [Theory]
    [InlineData(-1)]
    [InlineData(1)]
    [InlineData(0)]
    public async Task RejectsWrongByteCountOrDigest(int sizeChange)
    {
        var fixture = Make();
        var bytes = fixture.Bytes.ToList();
        if (sizeChange < 0) bytes.RemoveAt(bytes.Count - 1);
        else if (sizeChange > 0) bytes.Add(0);
        else bytes[0] ^= 1;
        await Assert.ThrowsAsync<InvalidDataException>(() => Store(fixture).InstallAsync(fixture.Edition.Id, new MemoryStream(bytes.ToArray())));
        Assert.Empty(Directory.GetFiles(_directory));
    }

    [Fact]
    public async Task FailedUpdateAndCancellationKeepThePreviouslyVerifiedRevision()
    {
        var original = Make();
        await Install(Store(original), original);
        var update = Make(revision: "b", mutation: "duplicateVerse");
        var store = Store(update);
        await Assert.ThrowsAsync<InvalidDataException>(() => Install(store, update));
        using var cancelled = new CancellationTokenSource();
        cancelled.Cancel();
        await Assert.ThrowsAnyAsync<OperationCanceledException>(() => Install(store, update, cancelled.Token));
        Assert.Equal(original.Edition.Revision, (await store.InstalledAsync(original.Edition.Id))?.Revision);
        Assert.Equal(2, (await store.LoadChapterAsync(original.Edition.Id, "GEN", 1)).Verses.Count);
        Assert.Single(Directory.GetFiles(_directory));
    }

    [Fact]
    public async Task RemovalOnlyDeletesTheChosenEditionAndNotifiesReaders()
    {
        var first = Make();
        var other = Make(id: "other-bible");
        var store = Store(first, other);
        await Install(store, first);
        await Install(store, other);
        // A neighboring daily-reading asset is outside the optional Bible archive lifecycle.
        var dailyPath = Path.Combine(_directory, "readings-texts.json");
        await File.WriteAllTextAsync(dailyPath, "bundled daily content");
        var changes = new List<string>();
        store.Changed += changes.Add;
        await store.RemoveAsync(first.Edition.Id);
        Assert.Equal(new[] { first.Edition.Id }, changes);
        Assert.Null(await store.InstalledAsync(first.Edition.Id));
        Assert.NotNull(await store.InstalledAsync(other.Edition.Id));
        await Assert.ThrowsAsync<FileNotFoundException>(() => store.LoadChapterAsync(first.Edition.Id, "GEN", 1));
        Assert.Equal("bundled daily content", await File.ReadAllTextAsync(dailyPath));
    }

    [Theory]
    [InlineData("http://raw.githubusercontent.com/dkaluta/Prosary/main/Shared/dist/bibles/test.zip")]
    [InlineData("https://raw.githubusercontent.com.evil.test/dkaluta/Prosary/main/Shared/dist/bibles/test.zip")]
    [InlineData("https://raw.githubusercontent.com/dkaluta/Prosary/main/Shared/dist/bibles/test.zip?x=1")]
    [InlineData("https://raw.githubusercontent.com/dkaluta/Prosary/main/Shared/dist/bibles/test.zip#x")]
    [InlineData("https://raw.githubusercontent.com/dkaluta/Prosary/main/Shared/dist/bibles/nested/test.zip")]
    public void CatalogRejectsDownloadLocationOutsideTheExactAllowlist(string url) =>
        Assert.False(BibleLibraryStore.ValidDownloadUri(url));

    [Fact]
    public void CatalogRejectsWrongFilenameEvenOnTheAllowedHost()
    {
        var fixture = Make();
        Assert.Empty(Store(fixture with { Edition = fixture.Edition with { DownloadURL = BibleLibraryStore.DownloadPrefix + "other.zip" } }).Editions);
    }

    [Fact]
    public void NavigationUsesOnlyAvailableChaptersAndCrossesBookBoundaries()
    {
        Assert.Null(BibleNavigation.Adjacent(Books, new("GEN", 1), -1));
        Assert.Equal(new BibleLocation("GEN", 3), BibleNavigation.Adjacent(Books, new("GEN", 1), 1));
        Assert.Equal(new BibleLocation("EXO", 2), BibleNavigation.Adjacent(Books, new("GEN", 3), 1));
        Assert.Equal(new BibleLocation("GEN", 3), BibleNavigation.Adjacent(Books, new("EXO", 2), -1));
        Assert.Null(BibleNavigation.Adjacent(Books, new("EXO", 2), 1));
        Assert.Null(BibleNavigation.Adjacent(Books, new("GEN", 2), 1));
    }
    [Fact]
    public async Task PrintedCombinedVerseKeepsItsRangeAndJumpFindsTheContainingUnit()
    {
        var fixture = Make(mutation: "combined");
        var store = Store(fixture);
        await Install(store, fixture);
        var chapter = await store.LoadChapterAsync(fixture.Edition.Id, "GEN", 1);
        var verse = chapter.Verses[0];
        Assert.Equal("2–3", verse.VerseLabel);
        var row = new BibleVerseRow(verse.Verse, verse.Text, verse.EndVerse);
        Assert.True(row.ContainsVerse(2));
        Assert.True(row.ContainsVerse(3));
        Assert.False(row.ContainsVerse(4));
        Assert.Contains("2–3", row.DisplayText);
    }
    [Fact]
    public async Task UnnumberedIntroductionIsPreservedOnlyForTheFirstAvailableChapter()
    {
        var fixture = Make(introduction: "Source opening before the numbered text.");
        var store = Store(fixture);
        await Install(store, fixture);
        var manifest = await store.InstalledAsync(fixture.Edition.Id);
        Assert.NotNull(manifest);
        var book = manifest.Books[0];
        Assert.Equal("Source opening before the numbered text.", book.IntroductionForChapter(1));
        Assert.Null(book.IntroductionForChapter(3));
        var chapter = await store.LoadChapterAsync(fixture.Edition.Id, book.Id, 1);
        Assert.Equal(new[] { 2, 4 }, chapter.Verses.Select(verse => verse.Verse));
    }
    [Fact]
    public async Task PrintedVerseOrderIsPreservedRatherThanSortedNumerically()
    {
        var fixture = Make(mutation: "sourceOrder");
        var store = Store(fixture);
        await Install(store, fixture);
        var chapter = await store.LoadChapterAsync(fixture.Edition.Id, "GEN", 1);
        Assert.Equal(new[] { 24, 26, 27, 25, 28 }, chapter.Verses.Select(verse => verse.Verse));
    }
    [Theory]
    [InlineData(null, true)]
    [InlineData(2, true)]
    [InlineData(3, true)]
    [InlineData(4, true)]
    [InlineData(1, false)]
    [InlineData(0, false)]
    public void DailyPassagesValidateCombinedVerseEndpoints(int? endVerse, bool available)
    {
        var fixture = Make();
        // Daily appointments validate each unit's endpoint; unlike a complete Bible
        // chapter, their ordered selections may repeat a verse across units.
        var json = JsonSerializer.Serialize(new { schemaVersion = 1, editions = new[] { fixture.Edition },
            passages = new Dictionary<string, Dictionary<string, ScriptureVerse[]>> {
                ["daily|Genesis 1:2–4"] = new() { [fixture.Edition.Id] = [new(1, 2, "Combined", EndVerse: endVerse), new(1, 4, "Next")] }
            } }, Json);
        var store = new ReadingsTextStore(() => json);
        Assert.Equal(available, store.LoadPassage("daily", "Genesis 1:2–4", fixture.Edition.Id) is not null);
    }
    public void Dispose() { if (Directory.Exists(_directory)) Directory.Delete(_directory, true); }
}
