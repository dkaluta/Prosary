namespace Prosary.Localization;

/// <summary>
/// Normalizes display-only Hebrew headings. Canonical prayer and Scripture text remains
/// pointed; titles are easier to scan without niqqud or cantillation and match the rest of the
/// app's Hebrew chrome. Hebrew punctuation such as maqaf and sof pasuq is deliberately kept.
/// </summary>
public static class HebrewDisplayText
{
    public static string WithoutMarks(string text) =>
        text.Any(IsHebrewMark) ? string.Concat(text.Where(character => !IsHebrewMark(character))) : text;

    public static string? WithoutMarksOrNull(string? text) => text is null ? null : WithoutMarks(text);

    private static bool IsHebrewMark(char character) => character is
        >= '\u0591' and <= '\u05BD' or
        '\u05BF' or
        >= '\u05C1' and <= '\u05C2' or
        >= '\u05C4' and <= '\u05C5' or
        '\u05C7' or
        '\uFB1E';
}
