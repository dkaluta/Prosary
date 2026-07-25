namespace Prosary.Models;

/// <summary>How many times the Jesus Prayer is prayed in a session. "Custom" is a setup-screen-
/// only concept (see JesusPrayerSetupPage) — by the time a session starts it has already
/// collapsed into a plain <see cref="Count"/>, so this type only ever distinguishes a fixed
/// target from no target at all.</summary>
public abstract record JesusPrayerTarget
{
    public sealed record Count(int Value) : JesusPrayerTarget;
    public sealed record Unbounded : JesusPrayerTarget;

    private JesusPrayerTarget() { }
}
