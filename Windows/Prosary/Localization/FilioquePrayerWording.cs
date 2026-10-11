using Prosary.Models;

namespace Prosary.Localization;

/// <summary>Switch only the sourced procession clauses of known Nicene Creed keys. The
/// body and reading aid have already been resolved from one winning source.</summary>
internal static class FilioquePrayerWording
{
    private sealed record Clause(string Included, string Omitted, string? Optional = null);

    private static readonly Clause[] Clauses =
    [
        new("הַנּוֹבֵעַ מֵהָאָב וּמֵהַבֵּן", "הַנּוֹבֵעַ מֵהָאָב"),
        new("הַנּוֹבֵעַ מֵהָאָב וּמֵהַבֵּן", "הַנּוֹבֵעַ מֵהָאָב"),
        new("הנובע מהאב ומהבן", "הנובע מהאב", "הנובע מהאב [ומהבן]"),
        new("אֲשֶׁר נֶאֱצַל מִן הָאָב וּמִן הַבֵּן", "אֲשֶׁר נֶאֱצַל מִן הָאָב",
            "אֲשֶׁר נֶאֱצַל מִן הָאָב (וּמִן הַבֵּן)"),
        new("הַו דּמֶן אַבָא ובא ננפֶק", "הַו דּמֶן אַבָא ננפֶק"),
        new("ܗܰܘ ܕ݁ܡܶܢ ܐܰܒܳܐ ܘܒܐ ܢܢܦܶܩ", "ܗܰܘ ܕ݁ܡܶܢ ܐܰܒܳܐ ܢܢܦܶܩ"),
        new("qui ex Patre Filioque procedit", "qui ex Patre procedit"),
    ];

    internal static bool IsCreedKey(string key) =>
        key.Equals("symbolumNicaenum", StringComparison.OrdinalIgnoreCase)
        || key.Equals("symbolumApostolorum", StringComparison.OrdinalIgnoreCase);

    internal static bool? DefaultForLanguage(string? code)
    {
        if (string.IsNullOrEmpty(code)) return null;
        if (code is "iw" or LanguageCatalog.VicariateContentCode) code = "he";
        if (code == "fil") code = "tl";
        var language = LanguageCatalog.BaseLanguage(code) ?? code;
        return LanguageCatalog.All.Any(option => option.Code == language) ? language != "el" : null;
    }

    internal static bool? SourceStatus(string key, string text)
    {
        if (!IsCreedKey(key)) return null;
        // Pointed variants share their omitted prefix; test every included form before
        // treating that prefix as an actually omitted clause.
        if (Clauses.Any(clause => text.Contains(clause.Included, StringComparison.Ordinal)
            || (clause.Optional is { } optional && text.Contains(optional, StringComparison.Ordinal)))) return true;
        if (Clauses.Any(clause => text.Contains(clause.Omitted, StringComparison.Ordinal))) return false;
        return text.Contains("τὸ ἐκ τοῦ Πατρὸς ἐκπορευόμενον", StringComparison.Ordinal) ? false : null;
    }

    internal static (string Text, string? ReadingAid) Apply(
        string key, string text, string? readingAid, bool includeFilioque)
    {
        if (!IsCreedKey(key)) return (text, readingAid);
        string Render(string value)
        {
            foreach (var clause in Clauses)
            {
                var desired = includeFilioque ? clause.Included : clause.Omitted;
                if (clause.Optional is { } optional && value.Contains(optional, StringComparison.Ordinal))
                    return value.Replace(optional, desired, StringComparison.Ordinal);
                if (value.Contains(clause.Included, StringComparison.Ordinal))
                    return value.Replace(clause.Included, desired, StringComparison.Ordinal);
            }
            // Enabling renders the included source again. No clause is inserted into a
            // source which omitted it; Greek and unrecognized wording remain as authored.
            return value;
        }
        return (Render(text), readingAid is null ? null : Render(readingAid));
    }

    internal static (string Text, string? ReadingAid) Apply(string key, string text, string? readingAid)
    {
        var status = SourceStatus(key, text);
        if (status is { } sourcedStatus)
            AppSettings.InitializeFilioqueFromSource(sourcedStatus);
        return Apply(key, text, readingAid, AppSettings.IncludeFilioquePreference ?? status ?? AppSettings.IncludeFilioque);
    }
}
