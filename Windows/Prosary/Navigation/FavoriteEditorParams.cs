using Prosary.Models;

namespace Prosary.Navigation;

/// <summary>Navigation parameter for <c>FavoriteEditorPage</c>. When <paramref name="PrayerId"/>
/// is null, a brand-new favorite is being created and <paramref name="NewFavoriteKind"/> seeds
/// its <see cref="PrayerKind"/> (which section's "Add" button was tapped on
/// <c>FavoritesListPage</c>); when set, <paramref name="NewFavoriteKind"/> is ignored and the
/// existing favorite's own kind is used instead.</summary>
public sealed record FavoriteEditorParams(Guid? PrayerId, PrayerKind NewFavoriteKind = PrayerKind.Rosary);
