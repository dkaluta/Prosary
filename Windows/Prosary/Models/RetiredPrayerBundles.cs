namespace Prosary.Models;

/// <summary>Exact identities withdrawn from distribution; built-in and other authors' prayers remain available.</summary>
public static class RetiredPrayerBundles
{
    public const string GamlielLoreto = "repo.stgamliel-il.litanyOfMaryTheBlessedEverVirgin";

    public static IReadOnlyList<string> Ids { get; } = [GamlielLoreto];

    public static bool Contains(string? id) => id is not null && Ids.Contains(id, StringComparer.Ordinal);

    public static bool Contains(PrayerKind kind, string? id) => kind == PrayerKind.Custom && Contains(id);
}
