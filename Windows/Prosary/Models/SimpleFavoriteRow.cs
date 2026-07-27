namespace Prosary.Models;

/// <summary>One row in FavoritesListPage's "More Devotions" section — a non-configurable
/// devotion kind plus whether it's currently favorited (and by which <see cref="Prayer"/> id, so
/// the star toggle and reminders button know what to delete/edit). See
/// <see cref="Prosary.ViewModels.FavoritesViewModel"/>.
/// <para>
/// <see cref="Title"/>/<see cref="IconGlyph"/> are carried directly (rather than derived from
/// <see cref="Kind"/> at bind time, like the original 5-hardcoded-kind design) so this same row
/// shape also covers a generic (bundle-driven) devotion — for those, <see cref="Kind"/> is
/// <see cref="PrayerKind.Custom"/>, <see cref="CustomDevotionId"/> holds the bundle id, and
/// <see cref="Title"/>/<see cref="IconGlyph"/> come from that bundle's own manifest instead of a
/// hardcoded <see cref="PrayerKindExtensions"/> case.
/// </para>
/// </summary>
public sealed record SimpleFavoriteRow(
    PrayerKind Kind,
    string Title,
    string IconGlyph,
    bool IsFavorited,
    Guid? PrayerId,
    string? CustomDevotionId = null);
