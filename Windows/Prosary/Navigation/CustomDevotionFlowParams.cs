namespace Prosary.Navigation;

/// <summary>Navigation parameter for <see cref="Prosary.Views.CustomDevotionFlowPage"/> — unlike
/// the 5 hardcoded simplified devotions (which need no navigation parameter beyond an optional
/// favorite id, since their kind is implicit), a generic devotion also needs to know *which*
/// bundle to load, so <see cref="BundleId"/> travels alongside <see cref="PrayerId"/> even when a
/// favorite already exists (Home/Favorites both already know the bundle id at the call site, so
/// there's no need for the page to re-derive it from the loaded <see cref="Prosary.Models.Prayer"/>).</summary>
public sealed record CustomDevotionFlowParams(Guid? PrayerId, string BundleId);
