using Prosary.Localization;

namespace Prosary.Models;

/// <summary>Configuration options specific to the Jesus Prayer. Lives inside a <see cref="Prayer"/>
/// when <c>Kind == PrayerKind.JesusPrayer</c>.</summary>
public sealed record JesusPrayerOptions
{
    public JesusPrayerTarget Target { get; init; } = new JesusPrayerTarget.Count(33);

    public string TargetDisplayName => Target switch
    {
        JesusPrayerTarget.Count(var n) => string.Format(Loc.Tr("jp_count_times", "{0}×"), n),
        JesusPrayerTarget.Unbounded => Loc.Tr("jp_unbounded", "Unbounded"),
        _ => throw new ArgumentOutOfRangeException(nameof(Target))
    };
}
