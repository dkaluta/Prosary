namespace Prosary.Models;

/// <summary>One row in FavoritesListPage's "More Devotions" section — a non-configurable
/// devotion kind plus whether it's currently favorited (and by which <see cref="Prayer"/> id, so
/// the star toggle and reminders button know what to delete/edit). See
/// <see cref="Prosary.ViewModels.FavoritesViewModel"/>.</summary>
public sealed record SimpleFavoriteRow(PrayerKind Kind, bool IsFavorited, Guid? PrayerId);
