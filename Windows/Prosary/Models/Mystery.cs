namespace Prosary.Models;

/// <summary>
/// One of the twenty mysteries of the Rosary. Carries no display text of its own — title,
/// fruit, and description are looked up by <see cref="ImageKey"/> via
/// <see cref="Prosary.Localization.MysteryTranslations"/> in the currently chosen prayer language.
/// </summary>
/// <param name="ImageKey">
/// File stem (no extension) under a prayer pack's <c>images/</c> directory, and the lookup key
/// into <see cref="Prosary.Localization.MysteryTranslations"/>.
/// </param>
public sealed record Mystery(MysteryGroup Group, int Order, string ImageKey);
