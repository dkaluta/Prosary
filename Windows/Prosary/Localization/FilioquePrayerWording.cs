namespace Prosary.Localization;

/// <summary>Render only exact recognized source clauses, using the winning content's policy.</summary>
internal static class FilioquePrayerWording
{
    private sealed record Clause(string Included, string Omitted, string Bracketed, string? Parenthesized = null);
    private static readonly Clause[] Clauses =
    [
        new("הַנּוֹבֵעַ מֵהָאָב וּמֵהַבֵּן", "הַנּוֹבֵעַ מֵהָאָב", "הַנּוֹבֵעַ מֵהָאָב [וּמֵהַבֵּן]"),
        new("הַנּוֹבֵעַ מֵהָאָב וּמֵהַבֵּן", "הַנּוֹבֵעַ מֵהָאָב", "הַנּוֹבֵעַ מֵהָאָב [וּמֵהַבֵּן]"),
        new("הנובע מהאב ומהבן", "הנובע מהאב", "הנובע מהאב [ומהבן]"),
        new("אֲשֶׁר נֶאֱצַל מִן הָאָב וּמִן הַבֵּן", "אֲשֶׁר נֶאֱצַל מִן הָאָב", "אֲשֶׁר נֶאֱצַל מִן הָאָב [וּמִן הַבֵּן]", "אֲשֶׁר נֶאֱצַל מִן הָאָב (וּמִן הַבֵּן)"),
        new("הַו דּמֶן אַבָא ובא ננפֶק", "הַו דּמֶן אַבָא ננפֶק", "הַו דּמֶן אַבָא [ובא] ננפֶק"),
        new("ܗܰܘ ܕ݁ܡܶܢ ܐܰܒܳܐ ܘܒܐ ܢܢܦܶܩ", "ܗܰܘ ܕ݁ܡܶܢ ܐܰܒܳܐ ܢܢܦܶܩ", "ܗܰܘ ܕ݁ܡܶܢ ܐܰܒܳܐ [ܘܒܐ] ܢܢܦܶܩ"),
        new("qui ex Patre Filioque procedit", "qui ex Patre procedit", "qui ex Patre [Filioque] procedit"),
        new("що від Отця і Сина ісходить", "що від Отця ісходить", "що від Отця [і Сина] ісходить"),
    ];

    internal static bool IsCreedKey(string key) => key.Equals("symbolumNicaenum", StringComparison.OrdinalIgnoreCase)
        || key.Equals("symbolumApostolorum", StringComparison.OrdinalIgnoreCase);

    internal static (string Text, string? ReadingAid) Apply(string key, string text, string? readingAid, CreedPolicy? policy = null)
    {
        if (!IsCreedKey(key) || policy?.Filioque is not ("absent" or "bracketed" or "unbracketed")) return (text, readingAid);
        string Render(string value)
        {
            foreach (var clause in Clauses)
            {
                var desired = policy.Filioque switch { "absent" => clause.Omitted, "bracketed" => clause.Bracketed, _ => clause.Included };
                foreach (var authored in new[] { clause.Parenthesized, clause.Bracketed, clause.Included })
                    if (authored is not null && value.Contains(authored, StringComparison.Ordinal))
                        return value.Replace(authored, desired, StringComparison.Ordinal);
                // A source that omitted the phrase is never supplemented with invented words.
            }
            return value;
        }
        return (Render(text), readingAid is null ? null : Render(readingAid));
    }
}
