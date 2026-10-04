using System.Text.Json;
using System.Text.Json.Serialization;

namespace Prosary.Services;

public sealed record ScriptureEdition(string Id, string LanguageCode, string Name, string Attribution, string SourceURL,
    string? TextScript = null, string? TransliteratedTextScript = null)
{
    public bool HasAramaicScripts => LanguageCode == "arc" && TextScript == "Hebr" && TransliteratedTextScript == "Syrc";
    public Uri? SourceUri => Uri.TryCreate(SourceURL, UriKind.Absolute, out var uri)
        && (uri.Scheme == Uri.UriSchemeHttps || uri.Scheme == Uri.UriSchemeHttp) ? uri : null;
}

[JsonConverter(typeof(ScriptureVerseConverter))]
public sealed record ScriptureVerse(int Chapter, int Verse, string Text, string? TransliteratedText = null, int? EndVerse = null,
    [property: JsonConverter(typeof(ScriptureSourceNotesConverter))]
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] List<ScriptureSourceNote>? SourceNotes = null)
{
    public string VerseLabel => EndVerse is { } end && end > Verse ? $"{Verse}–{end}" : Verse.ToString(System.Globalization.CultureInfo.InvariantCulture);
    public string DisplayedText(ScriptureEdition? edition, string script) =>
        edition?.HasAramaicScripts == true && script == edition.TransliteratedTextScript
            ? TransliteratedText ?? "" : Text;
}
public sealed record ScripturePassage(IReadOnlyList<ScriptureVerse> Verses, bool IncludesWholeVerses = false,
    ScripturePassageSource? Source = null)
{
    public IReadOnlyList<BibleDisplayChapter>? SourceDisplays(ScriptureEdition edition)
    {
        if (Source?.ContentBlocks is not { } blocks || Verses.Count == 0) return null;
        var chapters = Verses.GroupBy(row => row.Chapter).ToDictionary(group => group.Key,
            group => new BibleChapterText(3, edition.Id, Source.Book, group.Key, group.ToList()));
        var container = new BibleChapterText(3, edition.Id, Source.Book, Verses[0].Chapter, Verses.ToList()) { ContentBlocks = blocks };
        var resolved = BibleSourceStructure.Resolve(container, chapters);
        var runs = new List<(int Number, List<BibleDisplayUnit> Units)>();
        foreach (var unit in resolved)
        {
            var number = unit.Primary?.Chapter ?? (runs.Count > 0 ? runs[^1].Number : Verses[0].Chapter);
            if (runs.Count == 0 || runs[^1].Number != number) runs.Add((number, []));
            runs[^1].Units.Add(unit);
        }
        return runs.Select(run => new BibleDisplayChapter(
            new BibleChapterText(3, edition.Id, Source.Book, run.Number,
                run.Units.Where(unit => unit.Primary is not null).Select(unit => unit.Primary!).ToList()), run.Units)).ToList();
    }
}

/// <summary>Reads pre-resolved, credited passages. Runtime code never guesses Bible references.</summary>
public sealed class ReadingsTextStore
{
    public static ReadingsTextStore Default { get; } = new(() =>
        File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "Data", "readings-texts.json")),
        () => File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "Data", "readings-editions.json")),
        BibleLibraryStore.Default);

    private sealed record Corpus(int SchemaVersion, List<ScriptureEdition>? Editions,
        Dictionary<string, Dictionary<string, List<ScriptureVerse>>>? Passages,
        HashSet<string>? WholeVersePassages, JsonElement PassageSources = default,
        Dictionary<string, Dictionary<string, string>>? PassageBooks = null);

    private static readonly JsonSerializerOptions Options = new(JsonSerializerDefaults.Web);
    private readonly Lazy<Corpus> _corpus;
    private readonly Lazy<IReadOnlyList<ScriptureEdition>> _editions;
    private readonly BibleLibraryStore? _bibleStore;
    private static Corpus Empty => new(1, [], [], []);

    public ReadingsTextStore(Func<string> readJson, Func<string>? readEditionsJson = null, BibleLibraryStore? bibleStore = null)
    {
        _bibleStore = bibleStore;
        Corpus Read(Func<string> read)
        {
            try
            {
                var corpus = JsonSerializer.Deserialize<Corpus>(read(), Options);
                if (corpus?.SchemaVersion != 1) return Empty;
                var editions = (corpus.Editions ?? []).Where(edition =>
                    edition is not null && !string.IsNullOrWhiteSpace(edition.Id) && !string.IsNullOrWhiteSpace(edition.LanguageCode)
                    && !string.IsNullOrWhiteSpace(edition.Name) && !string.IsNullOrWhiteSpace(edition.Attribution)
                    && edition.SourceUri is not null).DistinctBy(edition => edition.Id).ToList();
                if (!ValidSourceTable(corpus, editions) || !ValidBookTable(corpus)) return Empty;
                return corpus with { Editions = editions, Passages = corpus.Passages ?? [], WholeVersePassages = corpus.WholeVersePassages ?? [] };
            }
            catch (Exception error) when (error is IOException or UnauthorizedAccessException or JsonException or NotSupportedException)
            {
                return Empty;
            }
        }
        _corpus = new Lazy<Corpus>(() => Read(readJson));
        _editions = new Lazy<IReadOnlyList<ScriptureEdition>>(() =>
            readEditionsJson is null ? _corpus.Value.Editions ?? [] : Read(readEditionsJson).Editions ?? []);
    }

    public IReadOnlyList<ScriptureEdition> Editions => _editions.Value;

    public IReadOnlyList<ScriptureEdition> AvailableEditions(string scope, string rawCitation) =>
        Editions.Where(edition => LoadPassage(scope, rawCitation, edition.Id) is not null).ToList();

    public ScriptureEdition? ResolveEdition(string? selectedId, string interfaceLanguage) =>
        !string.IsNullOrEmpty(selectedId)
            ? Editions.FirstOrDefault(edition => edition.Id == selectedId)
            : Editions.FirstOrDefault(edition => NormalizeLanguage(edition.LanguageCode) == NormalizeLanguage(interfaceLanguage));

    public IReadOnlyList<ScriptureVerse> Passage(string scope, string rawCitation, string editionId) =>
        LoadPassage(scope, rawCitation, editionId)?.Verses ?? [];

    public ScripturePassage? LoadPassage(string scope, string rawCitation, string editionId)
    {
        if (scope is not ("daily" or "torah") || !Editions.Any(edition => edition.Id == editionId)
            || _corpus.Value.Passages?.TryGetValue($"{scope}|{rawCitation}", out var versions) != true
            || versions is null || !versions.TryGetValue(editionId, out var verses) || verses is null || verses.Count == 0)
            return null;
        // A damaged row must not display a silently shortened or partially missing passage.
        var edition = Editions.First(edition => edition.Id == editionId);
        var requiresBothScripts = edition.HasAramaicScripts;
        var hasScriptMetadata = edition.TextScript is not null || edition.TransliteratedTextScript is not null;
        var noteIds = new HashSet<string>(StringComparer.Ordinal);
        if (!verses.All(verse => verse is not null && verse.Chapter > 0 && verse.Verse > 0 && (verse.EndVerse is null || verse.EndVerse >= verse.Verse) && !string.IsNullOrWhiteSpace(verse.Text)
            && (!requiresBothScripts || !string.IsNullOrWhiteSpace(verse.TransliteratedText))
            && ScriptureSourceNote.ValidForVerse(verse, hasScriptMetadata, noteIds))) return null;
        ScripturePassageSource? source = null;
        var key = $"{scope}|{rawCitation}";
        if (_corpus.Value.PassageSources.ValueKind == JsonValueKind.Object
            && _corpus.Value.PassageSources.TryGetProperty(key, out var sources)
            && sources.TryGetProperty(editionId, out var rawSource))
        {
            try
            {
                source = ScripturePassageSource.Read(rawSource, Options);
                if (!source.ValidFor(verses, edition, noteIds)) return null;
            }
            catch (Exception error) when (error is JsonException or InvalidDataException or NotSupportedException)
            {
                return null;
            }
        }
        return new ScripturePassage(verses, _corpus.Value.WholeVersePassages?.Contains(key) == true, source);
    }

    public async Task<ScripturePassage?> LoadPassageAsync(string scope, string rawCitation, string editionId)
    {
        var passage = LoadPassage(scope, rawCitation, editionId);
        if (passage is null || _bibleStore is null
            || _corpus.Value.PassageBooks?.TryGetValue($"{scope}|{rawCitation}", out var books) != true
            || !books.TryGetValue(editionId, out var book)) return passage;
        try
        {
            var rows = await _bibleStore.LoadReviewedPassageAsync(editionId, book, passage.Verses);
            return passage with { Verses = rows };
        }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException or JsonException or InvalidDataException)
        {
            return passage;
        }
    }

    private static bool ValidBookTable(Corpus corpus)
    {
        if (corpus.PassageBooks is null) return true;
        return corpus.PassageBooks.All(entry => entry.Value is { Count: > 0 }
            && entry.Value.All(book => corpus.Passages?.TryGetValue(entry.Key, out var versions) == true
                && versions.ContainsKey(book.Key) && !string.IsNullOrWhiteSpace(book.Value)
                && System.Text.RegularExpressions.Regex.IsMatch(book.Value, "^[A-Z0-9]{3}$")
                && (corpus.PassageSources.ValueKind != JsonValueKind.Object
                    || !corpus.PassageSources.TryGetProperty(entry.Key, out var sources)
                    || !sources.TryGetProperty(book.Key, out var source)
                    || source.ValueKind == JsonValueKind.Object && source.TryGetProperty("book", out var actual)
                        && actual.ValueKind == JsonValueKind.String && actual.GetString() == book.Value)));
    }

    private static bool ValidSourceTable(Corpus corpus, IReadOnlyList<ScriptureEdition> editions)
    {
        var table = corpus.PassageSources;
        if (table.ValueKind == JsonValueKind.Undefined) return true;
        if (table.ValueKind != JsonValueKind.Object) return false;
        var entries = table.EnumerateObject().ToList();
        if (entries.Count == 0 || entries.Select(entry => entry.Name).Distinct().Count() != entries.Count) return false;
        foreach (var entry in entries)
        {
            if (!(entry.Name.StartsWith("daily|", StringComparison.Ordinal) || entry.Name.StartsWith("torah|", StringComparison.Ordinal))
                || string.IsNullOrWhiteSpace(entry.Name[6..])
                || entry.Value.ValueKind != JsonValueKind.Object
                || corpus.Passages?.TryGetValue(entry.Name, out var versions) != true || versions is null) return false;
            var sources = entry.Value.EnumerateObject().ToList();
            if (sources.Count == 0 || sources.Select(source => source.Name).Distinct().Count() != sources.Count
                || sources.Any(source => !versions.ContainsKey(source.Name) || !editions.Any(edition => edition.Id == source.Name))) return false;
        }
        return true;
    }

    public static string NormalizeLanguage(string value) => value.ToLowerInvariant().Split('-', '_')[0] switch
    {
        "iw" => "he",
        "fil" => "tl",
        var language => language,
    };
}
