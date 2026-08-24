namespace Prosary.Navigation;

/// <summary>Navigation parameter for <see cref="Prosary.Views.CustomDevotionFlowPage"/>. Every
/// generic devotion shares one PrayerKind, so the page must know which bundle to load;
/// <see cref="BundleId"/> travels alongside the optional <see cref="PrayerId"/>. Pray,
/// Categories, and Search already know that id at the call site, so the page need not re-derive
/// it from a loaded <see cref="Prosary.Models.Prayer"/>.</summary>
public sealed record CustomDevotionFlowParams(Guid? PrayerId, string BundleId);
