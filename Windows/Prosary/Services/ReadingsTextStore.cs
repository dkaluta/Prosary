using System.Text.Json;

namespace Prosary.Services;

public sealed record ScriptureEdition(string Id, string LanguageCode, string Name, string Attribution, string SourceURL,
    string? TextScript = null, string? TransliteratedTextScript = null)
{
    public bool HasAramaicScripts => LanguageCode == "arc" && TextScript == "Hebr" && TransliteratedTextScript == "Syrc";
    public Uri? SourceUri => Uri.TryCreate(SourceURL, UriKind.Absolute, out var uri)
        && (uri.Scheme == Uri.UriSchemeHttps || uri.Scheme == Uri.UriSchemeHttp) ? uri : null;
}

public sealed record ScriptureVerse(int Chapter, int Verse, string Text, string? TransliteratedText = null)
{
    public string DisplayedText(ScriptureEdition? edition, string script) =>
        edition?.HasAramaicScripts == true && script == edition.TransliteratedTextScript
            ? TransliteratedText ?? "" : Text;
}
public sealed record ScripturePassage(IReadOnlyList<ScriptureVerse> Verses, bool IncludesWholeVerses = false);

/// <summary>Reads pre-resolved, credited passages. Runtime code never guesses Bible references.</summary>
public sealed class ReadingsTextStore
{
    public static ReadingsTextStore Default { get; } = new(() =>
        File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "Data", "readings-texts.json")),
        () => File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "Data", "readings-editions.json")));

    private sealed record Corpus(int SchemaVersion, List<ScriptureEdition>? Editions,
        Dictionary<string, Dictionary<string, List<ScriptureVerse>>>? Passages,
        HashSet<string>? WholeVersePassages);

    private static readonly JsonSerializerOptions Options = new(JsonSerializerDefaults.Web);
    private readonly Lazy<Corpus> _corpus;
    private readonly Lazy<IReadOnlyList<ScriptureEdition>> _editions;
    private static Corpus Empty => new(1, [], [], []);

    public ReadingsTextStore(Func<string> readJson, Func<string>? readEditionsJson = null)
    {
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
        var requiresBothScripts = Editions.First(edition => edition.Id == editionId).HasAramaicScripts;
        return verses.All(verse => verse is not null && verse.Chapter > 0 && verse.Verse > 0 && !string.IsNullOrWhiteSpace(verse.Text)
            && (!requiresBothScripts || !string.IsNullOrWhiteSpace(verse.TransliteratedText)))
            ? new ScripturePassage(verses, _corpus.Value.WholeVersePassages?.Contains($"{scope}|{rawCitation}") == true)
            : null;
    }

    public static string NormalizeLanguage(string value) => value.ToLowerInvariant().Split('-', '_')[0] switch
    {
        "iw" => "he",
        "fil" => "tl",
        var language => language,
    };
}
