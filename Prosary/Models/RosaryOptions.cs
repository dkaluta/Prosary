namespace Prosary.Models;

/// <summary>Configuration options specific to the Rosary. Lives inside a <see cref="Prayer"/>
/// when <c>Kind == PrayerKind.Rosary</c>.</summary>
public sealed record RosaryOptions
{
    public MysterySelectionMode MysterySelectionMode { get; init; } = MysterySelectionMode.TodaysMysteries;

    /// <summary>Used only when <see cref="MysterySelectionMode"/> is <see cref="Models.MysterySelectionMode.Specific"/>.</summary>
    public MysteryGroup SpecificMysteryGroup { get; init; } = MysteryGroup.Joyful;

    public bool IncludeApostlesCreed { get; init; } = true;

    /// <summary>The opening Our Father + 3 Hail Marys (for faith, hope, and charity) + Glory Be.</summary>
    public bool IncludeOpeningPrayers { get; init; } = true;

    /// <summary>The Fatima Prayer ("O my Jesus...") recited after the Glory Be of each decade.</summary>
    public bool IncludeFatimaPrayer { get; init; } = true;

    public EternalRestPlacement EternalRestForDeceased { get; init; } = EternalRestPlacement.None;

    public MarianAntiphonOption MarianAntiphon { get; init; } = MarianAntiphonOption.Seasonal;

    public bool IncludeStMichaelPrayer { get; init; } = false;

    public bool IncludeFinalSignOfCross { get; init; } = true;

    public string MysterySelectionSummary => MysterySelectionMode switch
    {
        MysterySelectionMode.Specific => $"Always {SpecificMysteryGroup}",
        MysterySelectionMode.FifteenMystery => "The 15 Mysteries",
        MysterySelectionMode.TwentyMystery => "The 20 Mysteries",
        MysterySelectionMode.TodaysMysteries => "Today's Mysteries",
        _ => throw new ArgumentOutOfRangeException(nameof(MysterySelectionMode))
    };
}
