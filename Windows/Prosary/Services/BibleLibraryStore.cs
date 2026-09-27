using System.IO.Compression;
using System.Net.Http;
using System.Security.Cryptography;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace Prosary.Services;

public sealed record BibleChapter(int Number, int VerseCount, bool IsComplete);
public sealed record BibleBook(string Id, string Name, List<BibleChapter> Chapters,
    string? TransliteratedName = null, string? Attribution = null, string? SourceURL = null, string? Introduction = null)
{
    public string? IntroductionForChapter(int number) => Chapters.FirstOrDefault()?.Number == number ? Introduction : null;
}
public sealed record BibleEdition(string Id, string LanguageCode, string Name, string Attribution, string SourceURL,
    string Revision, string DownloadURL, string ArchiveSHA256, long ArchiveByteCount, long UnpackedByteCount,
    List<BibleBook> Books, string? TextScript = null, string? TransliteratedTextScript = null)
{
    public ScriptureEdition Scripture => new(Id, LanguageCode, Name, Attribution, SourceURL, TextScript, TransliteratedTextScript);
}
public sealed record BibleManifest(int SchemaVersion, string EditionId, string Revision, List<BibleBook> Books);
public sealed record BibleChapterText(int SchemaVersion, string EditionId, string Book, int Chapter, List<ScriptureVerse> Verses);

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
            && book.Chapters.All(chapter => chapter is not null && chapter.Number is > 0 and <= 2000 && chapter.VerseCount is > 0 and <= 2000)
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
                return manifest is { SchemaVersion: 1 } && manifest.EditionId == id && Hash(manifest.Revision)
                    && ValidBooks(manifest.Books) ? manifest : null;
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
        if (manifest is not { SchemaVersion: 1 } || manifest.EditionId != edition.Id || manifest.Revision != edition.Revision
            || JsonSerializer.Serialize(manifest.Books, Json) != JsonSerializer.Serialize(edition.Books, Json))
            throw new InvalidDataException("The Bible manifest does not match its catalog.");
        foreach (var book in edition.Books)
            foreach (var chapter in book.Chapters)
            {
                cancellationToken.ThrowIfCancellationRequested();
                ValidateChapter(ReadEntry<BibleChapterText>(archive.GetEntry($"chapters/{book.Id}/{chapter.Number}.json")), edition, book.Id, chapter);
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
        return JsonSerializer.Deserialize<T>(bytes.ToArray(), Json) ?? throw new InvalidDataException("Invalid Bible JSON.");
    }

    private static void ValidateChapter(BibleChapterText? text, BibleEdition edition, string book, BibleChapter chapter)
    {
        if (text is not { SchemaVersion: 1 } || text.EditionId != edition.Id || text.Book != book || text.Chapter != chapter.Number
            || text.Verses is null || text.Verses.Count != chapter.VerseCount
            || text.Verses.Any(verse => verse is null || verse.Chapter != chapter.Number || verse.Verse <= 0 || verse.EndVerse < verse.Verse
                || string.IsNullOrWhiteSpace(verse.Text) || edition.Scripture.HasAramaicScripts && string.IsNullOrWhiteSpace(verse.TransliteratedText))
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

    public async Task<BibleChapterText> LoadChapterAsync(string id, string book, int chapter, CancellationToken cancellationToken = default)
    {
        var edition = Edition(id);
        await _files.WaitAsync(cancellationToken);
        try
        {
            return await Task.Run(() =>
            {
                using var archive = ZipFile.OpenRead(ArchivePath(id));
                var manifest = ReadEntry<BibleManifest>(archive.GetEntry("manifest.json"));
                if (manifest.SchemaVersion != 1 || manifest.EditionId != id || !ValidBooks(manifest.Books))
                    throw new InvalidDataException("Invalid installed Bible manifest.");
                var metadata = manifest.Books.FirstOrDefault(item => item.Id == book)?.Chapters.FirstOrDefault(item => item.Number == chapter)
                    ?? throw new InvalidDataException("The selected chapter is not available.");
                var result = ReadEntry<BibleChapterText>(archive.GetEntry($"chapters/{book}/{chapter}.json"));
                ValidateChapter(result, edition, book, metadata);
                return result;
            }, cancellationToken);
        }
        finally { _files.Release(); }
    }

    public async Task RemoveAsync(string id, CancellationToken cancellationToken = default)
    {
        await _files.WaitAsync(cancellationToken);
        try { File.Delete(ArchivePath(id)); }
        finally { _files.Release(); }
        Changed?.Invoke(id);
    }
}
