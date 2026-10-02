using System.Text.Json;
using System.Text.RegularExpressions;

namespace Prosary.Services;

/// <summary>Exact reviewed source credit and presentation for a daily supplement.</summary>
public sealed record ScripturePassageSource(string Book, string Name, string Attribution, string SourceURL,
    bool IsComplete, List<BibleContentBlock>? ContentBlocks = null)
{
    public Uri? SourceUri => Uri.TryCreate(SourceURL, UriKind.Absolute, out var uri)
        && uri.Scheme == Uri.UriSchemeHttps && !string.IsNullOrEmpty(uri.Host) && string.IsNullOrEmpty(uri.UserInfo) ? uri : null;

    internal static ScripturePassageSource Read(JsonElement value, JsonSerializerOptions options)
    {
        BibleStructureJson.Fields(value, ["book", "name", "attribution", "sourceURL", "isComplete"], "contentBlocks");
        if (value.GetProperty("isComplete").ValueKind is not (JsonValueKind.True or JsonValueKind.False))
            throw new JsonException("Invalid source completeness.");
        var source = new ScripturePassageSource(BibleStructureJson.Text(value, "book"),
            BibleStructureJson.Text(value, "name"), BibleStructureJson.Text(value, "attribution"),
            BibleStructureJson.Text(value, "sourceURL"), value.GetProperty("isComplete").GetBoolean(),
            value.TryGetProperty("contentBlocks", out var blocks) ? blocks.Deserialize<List<BibleContentBlock>>(options) : null);
        if (!Regex.IsMatch(source.Book, "^[A-Z0-9]{3}$", RegexOptions.CultureInvariant)
            || source.SourceUri is null || source.ContentBlocks is { Count: 0 })
            throw new JsonException("Invalid passage source.");
        return source;
    }

    internal bool ValidFor(IReadOnlyList<ScriptureVerse> verses, ScriptureEdition edition, HashSet<string> noteIds)
    {
        if (edition.TransliteratedTextScript is not null || verses.Any(verse => verse.TransliteratedText is not null)) return false;
        for (var index = 0; index < verses.Count; index++)
        {
            var row = verses[index];
            if (verses.Take(index).Any(prior => prior.Chapter == row.Chapter
                && prior.Verse <= (row.EndVerse ?? row.Verse) && row.Verse <= (prior.EndVerse ?? prior.Verse))) return false;
        }
        if (ContentBlocks is null) return true;
        var blockIds = new HashSet<string>(StringComparer.Ordinal);
        foreach (var block in ContentBlocks)
        {
            if (block is null || !Regex.IsMatch(block.Id, "^[a-z0-9][a-z0-9-]*$", RegexOptions.CultureInvariant)
                || !blockIds.Add(block.Id)) return false;
            if (block.Kind == "verse") continue;
            if (block.Kind == "witness" && (block.Addresses is not { Count: > 0 }
                || block.Addresses.Any(address => address is null)
                || block.Addresses.Select(address => (address.Chapter, address.Verse,
                    End: address.EndVerse ?? address.Verse, address.Part)).Distinct().Count() != block.Addresses.Count)) return false;
            if (!ScriptureSourceNote.ValidForVerse(new(verses[0].Chapter, 1, block.Text!, SourceNotes: block.SourceNotes), false, noteIds)) return false;
        }
        // Both flat primary rows and presentation references have the reviewed order.
        return ContentBlocks.Where(block => block.Kind == "verse").Select(block => (block.Chapter, block.Verse))
            .SequenceEqual(verses.Select(verse => ((int?)verse.Chapter, (int?)verse.Verse)));
    }
}
