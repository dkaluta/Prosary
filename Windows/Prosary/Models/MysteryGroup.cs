using Microsoft.UI;
using Windows.UI;

using Prosary.Localization;

namespace Prosary.Models;

public enum MysteryGroup
{
    Joyful,
    Sorrowful,
    Glorious,
    Luminous
}

public static class MysteryGroupExtensions
{
    /// <summary>English display name, used as a fallback when no localized name is supplied by
    /// the content layer (e.g. in favorite summaries).</summary>
    public static string DisplayName(this MysteryGroup group) => group switch
    {
        MysteryGroup.Joyful => "Joyful",
        MysteryGroup.Sorrowful => "Sorrowful",
        MysteryGroup.Glorious => "Glorious",
        MysteryGroup.Luminous => "Luminous",
        _ => throw new ArgumentOutOfRangeException(nameof(group))
    };

    /// <summary>UI-language name for chrome like Home's "Today: …" line. <see cref="DisplayName"/>
    /// stays English on purpose: the engine uses it as a *prayer-language* content fallback.</summary>
    public static string UiName(this MysteryGroup group) => group switch
    {
        MysteryGroup.Joyful => Loc.Tr("mystery_group_joyful", "Joyful"),
        MysteryGroup.Sorrowful => Loc.Tr("mystery_group_sorrowful", "Sorrowful"),
        MysteryGroup.Glorious => Loc.Tr("mystery_group_glorious", "Glorious"),
        MysteryGroup.Luminous => Loc.Tr("mystery_group_luminous", "Luminous"),
        _ => throw new ArgumentOutOfRangeException(nameof(group))
    };

    /// <summary>Accent color for the Pray tab's Rosary card — distinct per mystery group, not
    /// the liturgical season color used inside the flow screen's top banner. Matches Android's
    /// <c>MysteryGroup.color</c>.</summary>
    public static Color AccentColor(this MysteryGroup group) => group switch
    {
        MysteryGroup.Joyful => Color.FromArgb(0xFF, 0x15, 0x65, 0xC0), // blue
        MysteryGroup.Sorrowful => Color.FromArgb(0xFF, 0x6A, 0x1B, 0x9A), // purple
        MysteryGroup.Glorious => Color.FromArgb(0xFF, 0xC6, 0x28, 0x28), // red
        MysteryGroup.Luminous => Color.FromArgb(0xFF, 0x2E, 0x7D, 0x32), // green
        _ => throw new ArgumentOutOfRangeException(nameof(group))
    };
}
