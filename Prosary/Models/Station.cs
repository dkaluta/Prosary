namespace Prosary.Models;

/// <summary>
/// One of the fourteen Stations of the Cross. Carries no display text of its own — title and
/// meditation are looked up by <see cref="ImageKey"/> via
/// <see cref="Prosary.Localization.StationsTranslations"/> in the currently chosen prayer
/// language. Structurally the Stations equivalent of <see cref="Mystery"/>, but with no
/// <see cref="MysteryGroup"/> — there's only one fixed sequence, no user-chosen variant.
/// </summary>
/// <param name="ImageKey">File stem (no extension) under Assets/Images, and the lookup key into
/// <see cref="Prosary.Localization.StationsTranslations"/>.</param>
public sealed record Station(int Order, string ImageKey);
