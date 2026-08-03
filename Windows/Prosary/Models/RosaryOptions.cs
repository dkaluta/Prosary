using System.Linq;
using Prosary.Localization;

namespace Prosary.Models;

/// <summary>Configuration options specific to the Rosary. Lives inside a <see cref="Prayer"/>
/// when <c>Kind == PrayerKind.Rosary</c>.</summary>
public sealed record RosaryOptions
{
    public MysterySelectionMode MysterySelectionMode { get; init; } = MysterySelectionMode.TodaysMysteries;

    /// <summary>Used when <see cref="MysterySelectionMode"/> is <see cref="Models.MysterySelectionMode.Specific"/>
    /// or <see cref="Models.MysterySelectionMode.SingleMystery"/>.</summary>
    public MysteryGroup SpecificMysteryGroup { get; init; } = MysteryGroup.Joyful;

    /// <summary>1-based index into <c>MysteryCatalog.ForGroup(SpecificMysteryGroup)</c>. Used
    /// only when <see cref="MysterySelectionMode"/> is <see cref="Models.MysterySelectionMode.SingleMystery"/>.</summary>
    public int SpecificMysteryOrder { get; init; } = 1;

    public bool IncludeApostlesCreed { get; init; } = true;

    /// <summary>The opening Our Father + 3 Hail Marys (for faith, hope, and charity) + Glory Be.</summary>
    public bool IncludeOpeningPrayers { get; init; } = true;

    /// <summary>The Fatima Prayer ("O my Jesus...") recited after the Glory Be of each decade.</summary>
    public bool IncludeFatimaPrayer { get; init; } = true;

    public EternalRestPlacement EternalRestForDeceased { get; init; } = EternalRestPlacement.None;

    public MarianAntiphonOption MarianAntiphon { get; init; } = MarianAntiphonOption.Seasonal;

    public bool IncludeStMichaelPrayer { get; init; } = false;

    public bool IncludeFinalSignOfCross { get; init; } = true;

    /// <summary>Collapses each decade's 10 Hail Marys and Glory Be onto one combined screen —
    /// for someone leading a group aloud from memory who doesn't need to tap through 10
    /// visually-identical screens. See <c>PrayerEngine.BuildRosarySteps</c>.</summary>
    public bool PresenterMode { get; init; } = false;

    public string MysterySelectionSummary => MysterySelectionMode switch
    {
        MysterySelectionMode.Specific => string.Format(Loc.Tr("summary_always", "Always {0}"), SpecificMysteryGroup.UiName()),
        MysterySelectionMode.SingleMystery => string.Format(Loc.Tr("summary_only", "Only {0}"), SingleMysteryTitle()),
        MysterySelectionMode.FifteenMystery => Loc.Tr("summary_fifteen", "The 15 Mysteries"),
        MysterySelectionMode.TwentyMystery => Loc.Tr("summary_twenty", "The 20 Mysteries"),
        MysterySelectionMode.TodaysMysteries => Loc.Tr("mode_todays_mysteries", "Today's Mysteries"),
        _ => throw new ArgumentOutOfRangeException(nameof(MysterySelectionMode))
    };

    private string SingleMysteryTitle()
    {
        var chosen = MysteryCatalog.ForGroup(SpecificMysteryGroup).FirstOrDefault(m => m.Order == SpecificMysteryOrder);
        return chosen is null ? SpecificMysteryGroup.ToString() : MysteryTranslations.Get("en", chosen.ImageKey).Title;
    }
}
