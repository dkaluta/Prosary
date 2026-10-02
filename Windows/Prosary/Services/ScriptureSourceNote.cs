using System.Globalization;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;

namespace Prosary.Services;

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed record ScriptureSourceNote(
    [property: JsonRequired] string Id,
    [property: JsonRequired] string Kind,
    [property: JsonRequired] string Anchor,
    [property: JsonRequired] int Occurrence,
    [property: JsonRequired] int LetterIndex,
    [property: JsonRequired] string Mark,
    [property: JsonRequired] List<int> SourcePages,
    [property: JsonRequired] string SourceURL,
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] List<string>? RetainedVowels = null)
{
    public string Letter() => Anchor.Where(IsHebrewLetter).Skip(LetterIndex - 1).Take(1).FirstOrDefault().ToString();
    private static bool IsHebrewLetter(char value) => value is >= '\u05d0' and <= '\u05ea';
    private static bool IsCombining(char value) => CharUnicodeInfo.GetUnicodeCategory(value) is
        UnicodeCategory.NonSpacingMark or UnicodeCategory.SpacingCombiningMark or UnicodeCategory.EnclosingMark;
    private static bool IsVowel(char value) => value is >= '\u05b0' and <= '\u05bb' or '\u05c7';

    /// <summary>Validate exact primary-text anchors, including marks just outside a shortened quote.</summary>
    public static bool ValidForVerse(ScriptureVerse verse, bool paired, HashSet<string>? bookIds = null)
    {
        if (verse.SourceNotes is null) return true;
        if (paired || verse.TransliteratedText is not null || verse.SourceNotes.Count == 0 || string.IsNullOrWhiteSpace(verse.Text)) return false;
        var ids = bookIds ?? new HashSet<string>(StringComparer.Ordinal);
        var positions = new HashSet<(int, string)>();
        foreach (var note in verse.SourceNotes)
        {
            if (note is null || note.Id is null || !Regex.IsMatch(note.Id, "^[a-z0-9][a-z0-9-]*$", RegexOptions.CultureInvariant)
                || !ids.Add(note.Id)
                || !(note.Kind == "unreadablePoint" && note.Mark is ("vowel" or "dagesh" or "shuruq")
                    || note.Kind == "restoredLetter" && note.Mark == "consonant")
                || string.IsNullOrWhiteSpace(note.Anchor) || note.Occurrence <= 0 || note.LetterIndex <= 0
                || note.SourcePages is not { Count: > 0 } || note.SourcePages.Any(page => page <= 0)
                || note.SourcePages.Zip(note.SourcePages.Skip(1)).Any(pair => pair.First >= pair.Second)
                || string.IsNullOrWhiteSpace(note.SourceURL) || note.SourceURL.Any(char.IsWhiteSpace)
                || !Uri.TryCreate(note.SourceURL, UriKind.Absolute, out var source) || source.Scheme != Uri.UriSchemeHttps
                || source.UserInfo.Length > 0 || source.Host.Length == 0) return false;
            if (note.RetainedVowels is not null && (note.Mark != "vowel" || note.RetainedVowels.Count != 1
                || note.RetainedVowels[0] is not { Length: 1 } retained || !IsVowel(retained[0]))) return false;
            var offset = 0;
            var found = -1;
            // Ordinal, nonoverlapping matches; never normalize the quoted source wording.
            for (var occurrence = 0; occurrence < note.Occurrence; occurrence++)
            {
                found = verse.Text.IndexOf(note.Anchor, offset, StringComparison.Ordinal);
                if (found < 0) return false;
                offset = found + note.Anchor.Length;
            }
            var letters = Enumerable.Range(0, note.Anchor.Length).Where(index => IsHebrewLetter(note.Anchor[index])).ToList();
            if (note.LetterIndex > letters.Count) return false;
            var position = found + letters[note.LetterIndex - 1];
            if (!positions.Add((position, note.Mark == "shuruq" ? "dagesh" : note.Mark))) return false;
            if (note.Mark == "shuruq" && verse.Text[position] != 'ו') return false;
            var vowels = new List<char>();
            for (var index = position + 1; index < verse.Text.Length && IsCombining(verse.Text[index]); index++)
            {
                if (note.Mark is ("dagesh" or "shuruq") && verse.Text[index] == '\u05bc') return false;
                if (IsVowel(verse.Text[index])) vowels.Add(verse.Text[index]);
            }
            if (note.Mark == "vowel" && !vowels.SequenceEqual((note.RetainedVowels ?? []).Select(value => value[0]))) return false;
        }
        return true;
    }
}

/// <summary>Absent notes are allowed; an explicitly null/empty optional array is malformed.</summary>
public sealed class ScriptureSourceNotesConverter : JsonConverter<List<ScriptureSourceNote>>
{
    private static readonly HashSet<string> Fields = ["id", "kind", "anchor", "occurrence", "letterIndex", "mark", "sourcePages", "sourceURL"];
    public override bool HandleNull => true;
    public override List<ScriptureSourceNote> Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
        using var document = JsonDocument.ParseValue(ref reader);
        if (document.RootElement.ValueKind != JsonValueKind.Array || document.RootElement.GetArrayLength() == 0)
            throw new JsonException("Source notes must be nonempty.");
        var notes = new List<ScriptureSourceNote>();
        foreach (var item in document.RootElement.EnumerateArray())
        {
            if (item.ValueKind != JsonValueKind.Object) throw new JsonException("Invalid source note.");
            var fields = item.EnumerateObject().Select(property => property.Name).ToList();
            var retained = fields.Contains("retainedVowels");
            if (fields.Count != Fields.Count + (retained ? 1 : 0) || !Fields.IsSubsetOf(fields)
                || fields.Any(field => !Fields.Contains(field) && field != "retainedVowels")) throw new JsonException("Invalid source-note fields.");
            if (retained && item.GetProperty("retainedVowels").ValueKind != JsonValueKind.Array)
                throw new JsonException("Invalid retained vowels.");
            if (retained && item.GetProperty("mark") is { ValueKind: JsonValueKind.String } mark
                && mark.GetString() != "vowel")
                throw new JsonException("Only vowel omissions may declare retained vowels.");
            notes.Add(item.Deserialize<ScriptureSourceNote>(options) ?? throw new JsonException("Invalid source note."));
        }
        return notes;
    }
    public override void Write(Utf8JsonWriter writer, List<ScriptureSourceNote> value, JsonSerializerOptions options) =>
        JsonSerializer.Serialize(writer, value, options);
}

/// <summary>Keep field presence: even an explicitly null alternate cannot carry a primary-only note.</summary>
public sealed class ScriptureVerseConverter : JsonConverter<ScriptureVerse>
{
    private sealed record Row(int Chapter, int Verse, string Text,
        [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] string? TransliteratedText = null,
        int? EndVerse = null,
        [property: JsonConverter(typeof(ScriptureSourceNotesConverter))]
        [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] List<ScriptureSourceNote>? SourceNotes = null);

    public override ScriptureVerse Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
        using var document = JsonDocument.ParseValue(ref reader);
        if (document.RootElement.ValueKind != JsonValueKind.Object) throw new JsonException("Invalid Scripture verse.");
        var fields = document.RootElement.EnumerateObject().Select(property => property.Name).ToHashSet(StringComparer.OrdinalIgnoreCase);
        if (fields.Contains("sourceNotes") && fields.Contains("transliteratedText"))
            throw new JsonException("Paired source-note anchors are unsupported.");
        var row = document.RootElement.Deserialize<Row>(options) ?? throw new JsonException("Invalid Scripture verse.");
        return new(row.Chapter, row.Verse, row.Text, row.TransliteratedText, row.EndVerse, row.SourceNotes);
    }
    public override void Write(Utf8JsonWriter writer, ScriptureVerse value, JsonSerializerOptions options) =>
        JsonSerializer.Serialize(writer, new Row(value.Chapter, value.Verse, value.Text, value.TransliteratedText, value.EndVerse, value.SourceNotes), options);
}
