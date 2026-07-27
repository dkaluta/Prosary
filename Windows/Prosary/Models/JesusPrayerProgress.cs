namespace Prosary.Models;

/// <summary>Pure UI-computed presentation state for the Jesus Prayer's repetition counter —
/// mirrors how BeadLayout is a pure type derived from the backend's steps rather than something
/// the backend itself provides. There's no engine/backend for the Jesus Prayer: every repetition
/// prays the same fixed line, so there's nothing for a backend to build beyond this counter.
///
/// Immutable (record, <c>with</c>-based updates) rather than iOS's mutable struct, matching the
/// Android port's equivalent choice.</summary>
/// <param name="Target"></param>
/// <param name="CurrentIndex">0-based, same convention as RosaryViewModel's current step index.</param>
public sealed record JesusPrayerProgress(JesusPrayerTarget Target, int CurrentIndex = 0)
{
    /// <summary>Total repetitions for a bounded target; null for <see cref="JesusPrayerTarget.Unbounded"/>.</summary>
    public int? TargetCount => Target is JesusPrayerTarget.Count(var count) ? count : null;

    public bool CanGoBack => CurrentIndex > 0;

    /// <summary>False for <see cref="JesusPrayerTarget.Unbounded"/> — an unbounded session never
    /// auto-completes; the user ends it explicitly via the Finish action.</summary>
    public bool IsLastRep => TargetCount is { } count && CurrentIndex >= count - 1;

    /// <summary>Null for <see cref="JesusPrayerTarget.Unbounded"/>, since there's no total to
    /// measure progress against.</summary>
    public double? ProgressFraction => TargetCount is { } count and > 0
        ? (CurrentIndex + 1) / (double)count
        : null;

    public JesusPrayerProgress GoNext() => IsLastRep ? this : this with { CurrentIndex = CurrentIndex + 1 };

    public JesusPrayerProgress GoBack() => CanGoBack ? this with { CurrentIndex = CurrentIndex - 1 } : this;
}
