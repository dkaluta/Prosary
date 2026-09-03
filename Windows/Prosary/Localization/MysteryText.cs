namespace Prosary.Localization;

/// <summary>The resolved localized text for one mystery. A bundle may additionally provide the
/// same Scripture description in another script for the prayer flow's transliteration toggle.</summary>
public sealed record MysteryText(
    string Title,
    string Fruit,
    string Description,
    string? TransliteratedDescription = null);

/// <summary>A bundle-layer mystery contribution. Fields are independently optional so a source
/// can provide its native Scripture and transliteration without inventing a title or spiritual
/// fruit; those missing fields continue through the ordinary language fallback chain.</summary>
public sealed record MysteryTextOverride(
    string? Title = null,
    string? Fruit = null,
    string? Description = null,
    string? TransliteratedDescription = null);
