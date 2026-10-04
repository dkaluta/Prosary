using System.IO.Compression;
using System.Net.Http;
using System.Security.Cryptography;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;

namespace Prosary.Services;

public sealed record BibleChapter(int Number, int VerseCount, bool IsComplete)
{
    private string? _canonicalReference;
    [JsonIgnore] public bool HasCanonicalReference { get; private set; }
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? CanonicalReference { get => _canonicalReference; init { _canonicalReference = value; HasCanonicalReference = true; } }
}
public sealed record BibleBook(string Id, string Name, List<BibleChapter> Chapters,
    string? TransliteratedName = null, string? Attribution = null, string? SourceURL = null, string? Introduction = null)
{
    private List<BibleAddressRoute>? _addressRoutes;
    [JsonIgnore] public bool HasAddressRoutes { get; private set; }
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public List<BibleAddressRoute>? AddressRoutes { get => _addressRoutes; init { _addressRoutes = value; HasAddressRoutes = true; } }
    private string? _canonicalReference;
    [JsonIgnore] public bool HasCanonicalReference { get; private set; }
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? CanonicalReference { get => _canonicalReference; init { _canonicalReference = value; HasCanonicalReference = true; } }
    public string? IntroductionForChapter(int number) => Chapters.FirstOrDefault()?.Number == number ? Introduction : null;
}
public sealed record BibleEdition(string Id, string LanguageCode, string Name, string Attribution, string SourceURL,
    string Revision, string DownloadURL, string ArchiveSHA256, long ArchiveByteCount, long UnpackedByteCount,
    List<BibleBook> Books, string? TextScript = null, string? TransliteratedTextScript = null, int ArchiveSchemaVersion = 1)
{
    public ScriptureEdition Scripture => new(Id, LanguageCode, Name, Attribution, SourceURL, TextScript, TransliteratedTextScript);
}
public sealed record BibleManifest(int SchemaVersion, string EditionId, string Revision, List<BibleBook> Books);
public sealed record BibleChapterText(int SchemaVersion, string EditionId, string Book, int Chapter, List<ScriptureVerse> Verses)
{
    private List<BibleContentBlock>? _contentBlocks;
    [JsonIgnore] public bool HasContentBlocks { get; private set; }
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public List<BibleContentBlock>? ContentBlocks { get => _contentBlocks; init { _contentBlocks = value; HasContentBlocks = true; } }
}

/// <summary>Optional Bible archives, independent of prayer packs and bundled daily passages.</summary>
public sealed class BibleLibraryStore
{
    public const long MaxArchiveBytes = 32L * 1024 * 1024;
    public const long MaxExpandedBytes = 128L * 1024 * 1024;
    public const int MaxChapterBytes = 2 * 1024 * 1024;
    public const string DownloadPrefix = "https://raw.githubusercontent.com/dkaluta/Prosary/main/Shared/dist/bibles/";
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);
    private static readonly HttpClient Http = new(new HttpClientHandler { AllowAutoRedirect = false })
        { Timeout = TimeSpan.FromMinutes(5) };
    private readonly string _directory;
    private readonly SemaphoreSlim _files = new(1, 1);
    public IReadOnlyList<BibleEdition> Editions { get; }
    public event Action<string>? Changed;
    private static readonly Lazy<BibleLibraryStore> DefaultInstance = new(() => new(
        Path.Combine(Windows.Storage.ApplicationData.Current.LocalFolder.Path, "Bibles"), ReadBundledCatalog()));
    public static BibleLibraryStore Default => DefaultInstance.Value;

    private static string ReadBundledCatalog()
    {
        try { return File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "Data", "bible-catalog.json")); }
        catch (IOException) { return "{}"; }
    }

    public BibleLibraryStore(string directory, string catalogJson)
    {
        _directory = directory;
        Editions = ParseCatalog(catalogJson);
    }

    private sealed record Catalog(int SchemaVersion, List<BibleEdition>? Editions);
    public static IReadOnlyList<BibleEdition> ParseCatalog(string json)
    {
        try
        {
            var catalog = JsonSerializer.Deserialize<Catalog>(json, Json);
            if (catalog?.SchemaVersion != 1 || catalog.Editions is null) return [];
            var seen = new HashSet<string>(StringComparer.Ordinal);
            return catalog.Editions.Where(edition => ValidEdition(edition) && seen.Add(edition.Id)).ToList();
        }
        catch (JsonException) { return []; }
    }

    private static bool Hash(string? value) => value is not null && Regex.IsMatch(value, "^[a-f0-9]{64}$", RegexOptions.CultureInvariant);
    private static bool Id(string? value) => value is not null && Regex.IsMatch(value, "^[a-z0-9][a-z0-9-]{0,79}$", RegexOptions.CultureInvariant);
    private static bool ValidEdition(BibleEdition? edition) => edition is not null && Id(edition.Id)
        && !string.IsNullOrWhiteSpace(edition.LanguageCode) && !string.IsNullOrWhiteSpace(edition.Name)
        && !string.IsNullOrWhiteSpace(edition.Attribution) && edition.Scripture.SourceUri is not null
        && Hash(edition.Revision) && Hash(edition.ArchiveSHA256) && ValidDownloadUri(edition.DownloadURL)
        && edition.DownloadURL == DownloadPrefix + edition.Id + "-" + edition.Revision + ".zip"
        && edition.ArchiveByteCount is > 0 and <= MaxArchiveBytes
        && edition.UnpackedByteCount is > 0 and <= MaxExpandedBytes && ValidBooks(edition.Books)
        && edition.ArchiveSchemaVersion is 1 or 2 or 3
        && edition.Books.All(book => BibleSourceStructure.ValidRoutes(book, edition.ArchiveSchemaVersion))
        && (edition.ArchiveSchemaVersion != 3 || edition.TextScript is null && edition.TransliteratedTextScript is null)
        && ((edition.TextScript is null && edition.TransliteratedTextScript is null) || edition.Scripture.HasAramaicScripts);

    public static bool ValidDownloadUri(string? value) => Uri.TryCreate(value, UriKind.Absolute, out var uri)
        && uri.Scheme == Uri.UriSchemeHttps && uri.AbsoluteUri.StartsWith(DownloadPrefix, StringComparison.Ordinal)
        && uri.Query.Length == 0 && uri.Fragment.Length == 0 && uri.UserInfo.Length == 0
        && uri.AbsolutePath.EndsWith(".zip", StringComparison.Ordinal)
        && !uri.AbsolutePath["/dkaluta/Prosary/main/Shared/dist/bibles/".Length..].Contains('/');

    private static bool ValidBooks(List<BibleBook>? books) => books is { Count: > 0 and <= 100 }
        && books.All(book => book is not null && Regex.IsMatch(book.Id ?? "", "^[A-Z0-9]{1,12}$", RegexOptions.CultureInvariant)
            && !string.IsNullOrWhiteSpace(book.Name) && book.Chapters is { Count: > 0 and <= 2000 }
            && (book.Introduction is null || !string.IsNullOrWhiteSpace(book.Introduction))
            && (!book.HasCanonicalReference || !string.IsNullOrWhiteSpace(book.CanonicalReference))
            && book.Chapters.All(chapter => chapter is not null && chapter.Number is > 0 and <= 2000 && chapter.VerseCount is > 0 and <= 2000
                && (!chapter.HasCanonicalReference || !string.IsNullOrWhiteSpace(chapter.CanonicalReference)))
            && book.Chapters.Select(chapter => chapter.Number).SequenceEqual(book.Chapters.Select(chapter => chapter.Number).Distinct().Order())
            && (book.SourceURL is null || Uri.TryCreate(book.SourceURL, UriKind.Absolute, out var source)
                && source.Scheme is "https" or "http"))
        && books.Select(book => book.Id).Distinct(StringComparer.Ordinal).Count() == books.Count
        && books.Sum(book => book.Chapters.Count) <= 5000;

    private BibleEdition Edition(string id) => Editions.FirstOrDefault(edition => edition.Id == id)
        ?? throw new InvalidDataException("Unknown Bible edition.");
    private string ArchivePath(string id) { _ = Edition(id); return Path.Combine(_directory, id + ".zip"); }

    public async Task<BibleManifest?> InstalledAsync(string id, CancellationToken cancellationToken = default)
    {
        var path = ArchivePath(id);
        await _files.WaitAsync(cancellationToken);
        try
        {
            if (!File.Exists(path)) return null;
            return await Task.Run(() =>
            {
                using var archive = ZipFile.OpenRead(path);
                var manifest = ReadEntry<BibleManifest>(archive.GetEntry("manifest.json"));
                return manifest.SchemaVersion == Edition(id).ArchiveSchemaVersion && manifest.EditionId == id && Hash(manifest.Revision)
                    && ValidBooks(manifest.Books) && manifest.Books.All(book => BibleSourceStructure.ValidRoutes(book, manifest.SchemaVersion)) ? manifest : null;
            }, cancellationToken);
        }
        catch (Exception error) when (error is IOException or JsonException or UnauthorizedAccessException) { return null; }
        finally { _files.Release(); }
    }

    public async Task DownloadAsync(string id, IProgress<double>? progress = null, CancellationToken cancellationToken = default)
    {
        var edition = Edition(id);
        using var response = await Http.GetAsync(edition.DownloadURL, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
        response.EnsureSuccessStatusCode();
        if (response.Content.Headers.ContentLength is { } size && size != edition.ArchiveByteCount)
            throw new InvalidDataException("The Bible download size does not match its catalog.");
        await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
        await InstallAsync(id, stream, progress, cancellationToken);
    }

    /// <summary>Streams to a private temporary file; failed verification never replaces an installed edition.</summary>
    public async Task InstallAsync(string id, Stream input, IProgress<double>? progress = null, CancellationToken cancellationToken = default)
    {
        var edition = Edition(id);
        Directory.CreateDirectory(_directory);
        var temporary = Path.Combine(_directory, ".download-" + Guid.NewGuid().ToString("N") + ".tmp");
        try
        {
            using var digest = IncrementalHash.CreateHash(HashAlgorithmName.SHA256);
            long received = 0;
            await using (var output = new FileStream(temporary, FileMode.CreateNew, FileAccess.Write, FileShare.None, 81920, true))
            {
                var buffer = new byte[81920];
                int count;
                while ((count = await input.ReadAsync(buffer, cancellationToken)) > 0)
                {
                    if (count > edition.ArchiveByteCount - received || count > MaxArchiveBytes - received)
                        throw new InvalidDataException("The Bible download exceeds its declared size.");
                    digest.AppendData(buffer, 0, count);
                    await output.WriteAsync(buffer.AsMemory(0, count), cancellationToken);
                    received += count;
                    progress?.Report((double)received / edition.ArchiveByteCount * 100);
                }
                await output.FlushAsync(cancellationToken);
            }
            if (received != edition.ArchiveByteCount || Convert.ToHexStringLower(digest.GetHashAndReset()) != edition.ArchiveSHA256)
                throw new InvalidDataException("The Bible download failed verification.");
            await Task.Run(() => ValidateArchive(temporary, edition, cancellationToken), cancellationToken);
            await _files.WaitAsync(cancellationToken);
            try
            {
                cancellationToken.ThrowIfCancellationRequested();
                File.Move(temporary, ArchivePath(id), overwrite: true);
            }
            finally { _files.Release(); }
            Changed?.Invoke(id);
        }
        finally { if (File.Exists(temporary)) File.Delete(temporary); }
    }

    public static void ValidateArchive(string path, BibleEdition edition, CancellationToken cancellationToken = default)
    {
        if (!ValidEdition(edition)) throw new InvalidDataException("Invalid Bible catalog entry.");
        using var archive = ZipFile.OpenRead(path);
        var expected = edition.Books.SelectMany(book => book.Chapters.Select(chapter => $"chapters/{book.Id}/{chapter.Number}.json"))
            .Append("manifest.json").ToHashSet(StringComparer.Ordinal);
        if (archive.Entries.Count != expected.Count)
            throw new InvalidDataException("The Bible archive does not match its declared inventory.");
        long expanded = 0;
        foreach (var entry in archive.Entries)
        {
            if (!expected.Remove(entry.FullName) || entry.Length is <= 0 or > MaxChapterBytes
                || entry.Length > MaxExpandedBytes - expanded)
                throw new InvalidDataException("The Bible archive contains an invalid entry.");
            expanded += entry.Length;
        }
        if (expanded != edition.UnpackedByteCount)
            throw new InvalidDataException("The Bible archive expanded size does not match its catalog.");
        var manifest = ReadEntry<BibleManifest>(archive.GetEntry("manifest.json"));
        if (manifest.SchemaVersion != edition.ArchiveSchemaVersion || manifest.EditionId != edition.Id || manifest.Revision != edition.Revision
            || JsonSerializer.Serialize(manifest.Books, Json) != JsonSerializer.Serialize(edition.Books, Json))
            throw new InvalidDataException("The Bible manifest does not match its catalog.");
        foreach (var book in edition.Books)
        {
            var noteIds = new HashSet<string>(StringComparer.Ordinal);
            var chapters = new Dictionary<int, BibleChapterText>();
            foreach (var chapter in book.Chapters)
            {
                cancellationToken.ThrowIfCancellationRequested();
                var text = ReadEntry<BibleChapterText>(archive.GetEntry($"chapters/{book.Id}/{chapter.Number}.json"));
                ValidateChapter(text, edition, book.Id, chapter, noteIds);
                BibleSourceStructure.ValidateBlocks(text, edition, book, noteIds);
                chapters.Add(chapter.Number, text);
            }
            BibleSourceStructure.ValidateBook(book, chapters);
        }
    }

    private static T ReadEntry<T>(ZipArchiveEntry? entry)
    {
        if (entry is null || entry.Length is <= 0 or > MaxChapterBytes) throw new InvalidDataException("Invalid Bible entry.");
        using var stream = entry.Open();
        using var bytes = new MemoryStream();
        var buffer = new byte[8192];
        int count;
        while ((count = stream.Read(buffer)) > 0)
        {
            if (bytes.Length + count > entry.Length) throw new InvalidDataException("Expanded Bible entry exceeded its declaration.");
            bytes.Write(buffer, 0, count);
        }
        if (bytes.Length != entry.Length) throw new InvalidDataException("Incomplete Bible entry.");
        try { return JsonSerializer.Deserialize<T>(bytes.ToArray(), Json) ?? throw new InvalidDataException("Invalid Bible JSON."); }
        catch (JsonException error) { throw new InvalidDataException("Invalid Bible JSON.", error); }
    }

    private static void ValidateChapter(BibleChapterText? text, BibleEdition edition, string book, BibleChapter chapter, HashSet<string>? bookNoteIds = null)
    {
        bookNoteIds ??= new HashSet<string>(StringComparer.Ordinal);
        if (text is null || text.SchemaVersion != edition.ArchiveSchemaVersion || text.EditionId != edition.Id || text.Book != book || text.Chapter != chapter.Number
            || text.Verses is null || text.Verses.Count != chapter.VerseCount
            || text.Verses.Any(verse => verse is null || verse.Chapter != chapter.Number || verse.Verse <= 0 || verse.EndVerse < verse.Verse
                || string.IsNullOrWhiteSpace(verse.Text) || edition.Scripture.HasAramaicScripts && string.IsNullOrWhiteSpace(verse.TransliteratedText)
                || verse.SourceNotes is not null && edition.ArchiveSchemaVersion is not (2 or 3)
                || !ScriptureSourceNote.ValidForVerse(verse, edition.TextScript is not null || edition.TransliteratedTextScript is not null, bookNoteIds))
            || text.HasContentBlocks && (edition.ArchiveSchemaVersion != 3 || text.ContentBlocks is not { Count: > 0 })
            || OverlappingVerseRanges(text.Verses))
            throw new InvalidDataException("Invalid Bible chapter.");
    }

    private static bool OverlappingVerseRanges(IEnumerable<ScriptureVerse> verses)
    {
        // Printed editions can deliberately order labels 24,26,27,25,28. Sort a
        // validation copy only; the stored array remains the reading/picker order.
        var ordered = verses.OrderBy(verse => verse.Verse).ToList();
        return ordered.Zip(ordered.Skip(1)).Any(pair => pair.Second.Verse <= (pair.First.EndVerse ?? pair.First.Verse));
    }

    private BibleBook ReadBook(ZipArchive archive, BibleEdition edition, string book)
    {
        var manifest = ReadEntry<BibleManifest>(archive.GetEntry("manifest.json"));
        if (manifest.SchemaVersion != edition.ArchiveSchemaVersion || manifest.EditionId != edition.Id || !ValidBooks(manifest.Books)
            || manifest.Books.Any(item => !BibleSourceStructure.ValidRoutes(item, manifest.SchemaVersion)))
            throw new InvalidDataException("Invalid installed Bible manifest.");
        return manifest.Books.FirstOrDefault(item => item.Id == book) ?? throw new InvalidDataException("The selected book is not available.");
    }
    private static BibleChapterText ReadChapter(ZipArchive archive, BibleEdition edition, BibleBook book, int chapter)
    {
        var metadata = book.Chapters.FirstOrDefault(item => item.Number == chapter)
            ?? throw new InvalidDataException("The selected chapter is not available.");
        var result = ReadEntry<BibleChapterText>(archive.GetEntry($"chapters/{book.Id}/{chapter}.json"));
        var noteIds = new HashSet<string>(StringComparer.Ordinal);
        ValidateChapter(result, edition, book.Id, metadata, noteIds);
        BibleSourceStructure.ValidateBlocks(result, edition, book, noteIds);
        return result;
    }
    private async Task<T> ReadInstalledAsync<T>(string id, string book, Func<ZipArchive, BibleEdition, BibleBook, T> read, CancellationToken cancellationToken)
    {
        var edition = Edition(id);
        await _files.WaitAsync(cancellationToken);
        try
        {
            return await Task.Run(() =>
            {
                using var archive = ZipFile.OpenRead(ArchivePath(id));
                return read(archive, edition, ReadBook(archive, edition, book));
            }, cancellationToken);
        }
        finally { _files.Release(); }
    }
    public Task<BibleChapterText> LoadChapterAsync(string id, string book, int chapter, CancellationToken cancellationToken = default) =>
        ReadInstalledAsync(id, book, (archive, edition, metadata) => ReadChapter(archive, edition, metadata, chapter), cancellationToken);

    /// <summary>Read whole units pinned by the daily corpus; an older revision cannot change their wording.</summary>
    public Task<IReadOnlyList<ScriptureVerse>> LoadReviewedPassageAsync(string id, string book,
        IReadOnlyList<ScriptureVerse> expected, CancellationToken cancellationToken = default) =>
        ReadInstalledAsync<IReadOnlyList<ScriptureVerse>>(id, book, (archive, edition, metadata) =>
        {
            if (expected.Count == 0) throw new InvalidDataException("Empty reviewed Bible passage.");
            var chapters = expected.Select(verse => verse.Chapter).Distinct().ToDictionary(number => number,
                number => ReadChapter(archive, edition, metadata, number));
            return expected.Select(reviewed =>
            {
                var unit = chapters[reviewed.Chapter].Verses.FirstOrDefault(verse => verse.Verse == reviewed.Verse);
                // Source note lists have reference equality in records. Compare their serialized
                // representation as well, so identical independently loaded units remain valid.
                if (unit is null || unit.Chapter != reviewed.Chapter || unit.Verse != reviewed.Verse
                    || unit.EndVerse != reviewed.EndVerse || unit.Text != reviewed.Text
                    || unit.TransliteratedText != reviewed.TransliteratedText
                    || JsonSerializer.Serialize(unit.SourceNotes) != JsonSerializer.Serialize(reviewed.SourceNotes))
                    throw new InvalidDataException("Installed Bible differs from the reviewed daily source.");
                return unit;
            }).ToList();
        }, cancellationToken);

    /// <summary>Only the display chapter and its direct primary references are opened; blocks never recurse.</summary>
    public Task<BibleDisplayChapter> LoadDisplayChapterAsync(string id, string book, int chapter, CancellationToken cancellationToken = default) =>
        ReadInstalledAsync(id, book, (archive, edition, metadata) =>
        {
            var display = ReadChapter(archive, edition, metadata, chapter);
            var primary = new Dictionary<int, BibleChapterText> { [chapter] = display };
            foreach (var number in (display.ContentBlocks ?? []).Where(block => block.Kind == "verse").Select(block => block.Chapter!.Value).Distinct())
            {
                cancellationToken.ThrowIfCancellationRequested();
                if (!primary.ContainsKey(number)) primary.Add(number, ReadChapter(archive, edition, metadata, number));
            }
            return new BibleDisplayChapter(display, BibleSourceStructure.Resolve(display, primary));
        }, cancellationToken);

    public Task<BibleAddressTarget?> ResolveAddressAsync(string id, string book, int chapter, int verse, CancellationToken cancellationToken = default) =>
        ReadInstalledAsync<BibleAddressTarget?>(id, book, (archive, edition, metadata) =>
        {
            var source = ReadChapter(archive, edition, metadata, chapter);
            var primary = source.Verses.FirstOrDefault(item => verse >= item.Verse && verse <= (item.EndVerse ?? item.Verse));
            if (primary is null) return null;
            var route = metadata.AddressRoutes?.FirstOrDefault(item => item.Chapter == chapter && item.Verse == primary.Verse);
            if (route is not null) return new(route.DisplayChapter, route.BlockId);
            var block = source.ContentBlocks?.SingleOrDefault(item => item.Kind == "verse" && item.Chapter == chapter && item.Verse == primary.Verse);
            if (source.ContentBlocks is not null && block is null) throw new InvalidDataException("Missing primary presentation.");
            return new(chapter, block?.Id ?? BibleSourceStructure.PrimaryId(chapter, primary.Verse));
        }, cancellationToken);

    public async Task RemoveAsync(string id, CancellationToken cancellationToken = default)
    {
        await _files.WaitAsync(cancellationToken);
        try { File.Delete(ArchivePath(id)); }
        finally { _files.Release(); }
        Changed?.Invoke(id);
    }
}
