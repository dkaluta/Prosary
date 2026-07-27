using Prosary.Models;

namespace Prosary.Navigation;

/// <summary>Navigation parameter for <c>JesusPrayerFlowPage</c> — the only flow page needing more
/// than a single <c>Guid?</c>, since it can be reached either from a saved favorite
/// (<paramref name="PrayerId"/> set, its own target wins) or fresh from
/// <c>JesusPrayerSetupPage</c> (<paramref name="Target"/> set, no favorite yet).</summary>
public sealed record JesusPrayerFlowParams(Guid? PrayerId, JesusPrayerTarget? Target);
