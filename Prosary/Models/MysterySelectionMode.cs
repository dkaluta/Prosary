namespace Prosary.Models;

public enum MysterySelectionMode
{
    /// <summary>Follow the traditional weekday assignment (with liturgical-season overrides on Sundays).</summary>
    TodaysMysteries,

    /// <summary>Always pray a specific, user-chosen set regardless of the day.</summary>
    Specific,

    /// <summary>The traditional 15 mysteries: Joyful, Sorrowful, and Glorious (no Luminous), prayed in one session.</summary>
    FifteenMystery,

    /// <summary>All 20 mysteries in one session, in the chronological order of Christ's life: Joyful, Luminous, Sorrowful, Glorious.</summary>
    TwentyMystery
}

public static class MysterySelectionModeExtensions
{
    public static string DisplayName(this MysterySelectionMode mode) => mode switch
    {
        MysterySelectionMode.TodaysMysteries => "Today's Mysteries",
        MysterySelectionMode.Specific => "Always a Specific Set",
        MysterySelectionMode.FifteenMystery => "The 15 Mysteries (Joyful, Sorrowful, Glorious)",
        MysterySelectionMode.TwentyMystery => "The 20 Mysteries (All Four Sets)",
        _ => throw new ArgumentOutOfRangeException(nameof(mode))
    };
}
