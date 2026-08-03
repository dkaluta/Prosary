using Prosary.Localization;

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
    TwentyMystery,

    /// <summary>Pray exactly one specific mystery (one decade) — see
    /// <see cref="RosaryOptions.SpecificMysteryOrder"/>. Added last, not grouped with
    /// <see cref="Specific"/> above: this enum is persisted by sqlite-net as its raw integer
    /// ordinal (not name), so inserting a case earlier would silently reassign the stored values
    /// of every case after it for existing saved favorites — the same precaution already taken
    /// for <c>MarianAntiphonOption.SubTuumPraesidium</c>.</summary>
    SingleMystery
}

public static class MysterySelectionModeExtensions
{
    public static string DisplayName(this MysterySelectionMode mode) => mode switch
    {
        MysterySelectionMode.TodaysMysteries => Loc.Tr("mode_todays_mysteries", "Today's Mysteries"),
        MysterySelectionMode.Specific => Loc.Tr("mode_specific", "Always a Specific Set"),
        MysterySelectionMode.FifteenMystery => Loc.Tr("mode_fifteen", "The 15 Mysteries (Joyful, Sorrowful, Glorious)"),
        MysterySelectionMode.TwentyMystery => Loc.Tr("mode_twenty", "The 20 Mysteries (All Four Sets)"),
        MysterySelectionMode.SingleMystery => Loc.Tr("mode_single", "One Mystery Only"),
        _ => throw new ArgumentOutOfRangeException(nameof(mode))
    };
}
