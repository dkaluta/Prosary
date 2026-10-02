using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;

namespace Prosary.Services;

[JsonConverter(typeof(BibleAddressConverter))]
public sealed record BibleAddress(int Chapter, int Verse, int? EndVerse = null, string? Part = null);
[JsonConverter(typeof(BibleAddressRouteConverter))]
public sealed record BibleAddressRoute(int Chapter, int Verse, int DisplayChapter, string BlockId);
[JsonConverter(typeof(BibleContentBlockConverter))]
public sealed record BibleContentBlock(string Id, string Kind, int? Chapter = null, int? Verse = null,
    string? Text = null, string? PrintedLabel = null, List<BibleAddress>? Addresses = null,
    List<ScriptureSourceNote>? SourceNotes = null);
public sealed record BibleDisplayUnit(string Id, string Kind, ScriptureVerse? Primary = null,
    string? Text = null, string? PrintedLabel = null, IReadOnlyList<BibleAddress>? Addresses = null,
    IReadOnlyList<ScriptureSourceNote>? SourceNotes = null);
public sealed record BibleDisplayChapter(BibleChapterText Chapter, IReadOnlyList<BibleDisplayUnit> Units);
public sealed record BibleAddressTarget(int DisplayChapter, string BlockId);

internal static class BibleStructureJson
{
    public static void Fields(JsonElement item, string[] required, params string[] optional)
    {
        if (item.ValueKind != JsonValueKind.Object) throw new JsonException("Expected a source structure object.");
        var fields = item.EnumerateObject().Select(property => property.Name).ToList();
        if (fields.Distinct(StringComparer.Ordinal).Count() != fields.Count || required.Any(key => !fields.Contains(key))
            || fields.Any(key => !required.Contains(key) && !optional.Contains(key))
            || item.EnumerateObject().Any(property => property.Value.ValueKind == JsonValueKind.Null))
            throw new JsonException("Invalid source structure fields.");
    }
    public static int Number(JsonElement item, string key) => item.GetProperty(key).ValueKind == JsonValueKind.Number && item.GetProperty(key).TryGetInt32(out var value)
        && value is > 0 and <= 1000 ? value : throw new JsonException("Invalid source address.");
    public static string Text(JsonElement item, string key) => item.GetProperty(key).ValueKind == JsonValueKind.String
        && item.GetProperty(key).GetString() is { } value && !string.IsNullOrWhiteSpace(value)
            ? value : throw new JsonException("Empty source structure text.");
}

public sealed class BibleAddressConverter : JsonConverter<BibleAddress>
{
    public override BibleAddress Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
        using var document = JsonDocument.ParseValue(ref reader); var item = document.RootElement;
        BibleStructureJson.Fields(item, ["chapter", "verse"], "endVerse", "part");
        var value = new BibleAddress(BibleStructureJson.Number(item, "chapter"), BibleStructureJson.Number(item, "verse"),
            item.TryGetProperty("endVerse", out _) ? BibleStructureJson.Number(item, "endVerse") : null,
            item.TryGetProperty("part", out _) ? BibleStructureJson.Text(item, "part") : null);
        if (value.EndVerse < value.Verse) throw new JsonException("Reversed source range.");
        return value;
    }
    public override void Write(Utf8JsonWriter writer, BibleAddress value, JsonSerializerOptions options)
    {
        writer.WriteStartObject(); writer.WriteNumber("chapter", value.Chapter); writer.WriteNumber("verse", value.Verse);
        if (value.EndVerse is { } end) writer.WriteNumber("endVerse", end);
        if (value.Part is { } part) writer.WriteString("part", part);
        writer.WriteEndObject();
    }
}
public sealed class BibleAddressRouteConverter : JsonConverter<BibleAddressRoute>
{
    public override BibleAddressRoute Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
        using var document = JsonDocument.ParseValue(ref reader); var item = document.RootElement;
        BibleStructureJson.Fields(item, ["chapter", "verse", "displayChapter", "blockId"]);
        return new(BibleStructureJson.Number(item, "chapter"), BibleStructureJson.Number(item, "verse"),
            BibleStructureJson.Number(item, "displayChapter"), BibleStructureJson.Text(item, "blockId"));
    }
    public override void Write(Utf8JsonWriter writer, BibleAddressRoute value, JsonSerializerOptions options)
    {
        writer.WriteStartObject(); writer.WriteNumber("chapter", value.Chapter); writer.WriteNumber("verse", value.Verse);
        writer.WriteNumber("displayChapter", value.DisplayChapter); writer.WriteString("blockId", value.BlockId); writer.WriteEndObject();
    }
}
public sealed class BibleContentBlockConverter : JsonConverter<BibleContentBlock>
{
    public override BibleContentBlock Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
        using var document = JsonDocument.ParseValue(ref reader); var item = document.RootElement;
        if (item.ValueKind != JsonValueKind.Object || !item.TryGetProperty("kind", out _)) throw new JsonException("Invalid source block.");
        var kind = BibleStructureJson.Text(item, "kind");
        switch (kind)
        {
            case "verse": BibleStructureJson.Fields(item, ["id", "kind", "chapter", "verse"], "printedLabel"); break;
            case "witness": BibleStructureJson.Fields(item, ["id", "kind", "text", "printedLabel", "addresses"], "sourceNotes"); break;
            case "passage": case "colophon": BibleStructureJson.Fields(item, ["id", "kind", "text"], "sourceNotes"); break;
            case "heading": BibleStructureJson.Fields(item, ["id", "kind", "text"]); break;
            default: throw new JsonException("Unsupported source block.");
        }
        List<ScriptureSourceNote>? notes = null;
        if (item.TryGetProperty("sourceNotes", out var rawNotes))
        {
            var noteOptions = new JsonSerializerOptions(options); noteOptions.Converters.Add(new ScriptureSourceNotesConverter());
            notes = rawNotes.Deserialize<List<ScriptureSourceNote>>(noteOptions);
        }
        return new(BibleStructureJson.Text(item, "id"), kind,
            kind == "verse" ? BibleStructureJson.Number(item, "chapter") : null,
            kind == "verse" ? BibleStructureJson.Number(item, "verse") : null,
            kind != "verse" ? BibleStructureJson.Text(item, "text") : null,
            item.TryGetProperty("printedLabel", out _) ? BibleStructureJson.Text(item, "printedLabel") : null,
            item.TryGetProperty("addresses", out var addresses) ? addresses.Deserialize<List<BibleAddress>>(options) : null, notes);
    }
    public override void Write(Utf8JsonWriter writer, BibleContentBlock value, JsonSerializerOptions options)
    {
        writer.WriteStartObject(); writer.WriteString("id", value.Id); writer.WriteString("kind", value.Kind);
        if (value.Chapter is { } chapter) writer.WriteNumber("chapter", chapter);
        if (value.Verse is { } verse) writer.WriteNumber("verse", verse);
        if (value.Text is { } text) writer.WriteString("text", text);
        if (value.PrintedLabel is { } label) writer.WriteString("printedLabel", label);
        if (value.Addresses is { } addresses) { writer.WritePropertyName("addresses"); JsonSerializer.Serialize(writer, addresses, options); }
        if (value.SourceNotes is { } notes) { writer.WritePropertyName("sourceNotes"); JsonSerializer.Serialize(writer, notes, options); }
        writer.WriteEndObject();
    }
}

public static class BibleSourceStructure
{
    public static string PrimaryId(int chapter, int verse) => $"primary-{chapter}-{verse}";
    private static bool Id(string? id) => id is not null && Regex.IsMatch(id, "^[a-z0-9][a-z0-9-]*$", RegexOptions.CultureInvariant);
    public static bool ValidRoutes(BibleBook book, int version) => !book.HasAddressRoutes || version == 3
        && book.AddressRoutes is { Count: > 0 } routes
        && routes.All(route => route is not null && route.Chapter is > 0 and <= 1000 && route.Verse is > 0 and <= 1000
            && route.DisplayChapter is > 0 and <= 1000 && route.Chapter != route.DisplayChapter && Id(route.BlockId)
            && book.Chapters.Any(chapter => chapter.Number == route.Chapter) && book.Chapters.Any(chapter => chapter.Number == route.DisplayChapter))
        && routes.Select(route => (route.Chapter, route.Verse)).Distinct().Count() == routes.Count;

    public static void ValidateBlocks(BibleChapterText chapter, BibleEdition edition, BibleBook book, HashSet<string> noteIds)
    {
        if (!chapter.HasContentBlocks) return;
        if (edition.ArchiveSchemaVersion != 3 || edition.TextScript is not null || edition.TransliteratedTextScript is not null
            || chapter.ContentBlocks is not { Count: > 0 } || chapter.Verses.Any(verse => verse.TransliteratedText is not null)) throw new InvalidDataException("Unsupported source blocks.");
        foreach (var block in chapter.ContentBlocks)
        {
            if (block is null || !Id(block.Id)) throw new InvalidDataException("Invalid source block ID.");
            if (block.Kind == "verse") continue; // Exact field shape is checked by the decoder; references resolve book-wide.
            if (block.Kind == "witness" && (block.Addresses is not { Count: > 0 }
                || block.Addresses.Any(address => address is null || !book.Chapters.Any(item => item.Number == address.Chapter))
                || block.Addresses.Select(address => (address.Chapter, address.Verse, End: address.EndVerse ?? address.Verse, address.Part)).Distinct().Count() != block.Addresses.Count)) throw new InvalidDataException("Invalid witness addresses.");
            if (!ScriptureSourceNote.ValidForVerse(new(chapter.Chapter, 1, block.Text!, SourceNotes: block.SourceNotes), false, noteIds))
                throw new InvalidDataException("Invalid source block notes.");
        }
    }

    public static void ValidateBook(BibleBook book, IReadOnlyDictionary<int, BibleChapterText> chapters)
    {
        var primary = chapters.Values.SelectMany(chapter => chapter.Verses).ToDictionary(verse => (verse.Chapter, verse.Verse));
        var presented = new HashSet<(int, int)>();
        var ids = new HashSet<string>(StringComparer.Ordinal);
        var actualRoutes = new HashSet<BibleAddressRoute>();
        foreach (var chapter in chapters.Values)
        {
            if (chapter.ContentBlocks is null)
            {
                foreach (var verse in chapter.Verses)
                    if (!presented.Add((verse.Chapter, verse.Verse))) throw new InvalidDataException("Duplicate primary presentation.");
                continue;
            }
            foreach (var block in chapter.ContentBlocks)
            {
                if (!ids.Add(block.Id)) throw new InvalidDataException("Duplicate source block ID.");
                if (block.Kind != "verse") continue;
                var address = (block.Chapter!.Value, block.Verse!.Value);
                if (!primary.ContainsKey(address) || !presented.Add(address)) throw new InvalidDataException("Missing or duplicate primary reference.");
                if (address.Item1 != chapter.Chapter) actualRoutes.Add(new(address.Item1, address.Item2, chapter.Chapter, block.Id));
            }
        }
        if (presented.Count != primary.Count || !actualRoutes.SetEquals(book.AddressRoutes ?? []))
            throw new InvalidDataException("The source presentation and address routes do not match.");
    }

    public static IReadOnlyList<BibleDisplayUnit> Resolve(BibleChapterText chapter, IReadOnlyDictionary<int, BibleChapterText> primaryChapters)
    {
        if (chapter.ContentBlocks is null) return chapter.Verses.Select(verse => new BibleDisplayUnit(PrimaryId(verse.Chapter, verse.Verse), "verse", verse)).ToList();
        return chapter.ContentBlocks.Select(block => block.Kind == "verse"
            ? new BibleDisplayUnit(block.Id, block.Kind,
                primaryChapters.GetValueOrDefault(block.Chapter!.Value)?.Verses.SingleOrDefault(verse => verse.Verse == block.Verse)
                    ?? throw new InvalidDataException("Unresolved primary source unit."), PrintedLabel: block.PrintedLabel)
            : new BibleDisplayUnit(block.Id, block.Kind, Text: block.Text, PrintedLabel: block.PrintedLabel, Addresses: block.Addresses, SourceNotes: block.SourceNotes)).ToList();
    }
}
