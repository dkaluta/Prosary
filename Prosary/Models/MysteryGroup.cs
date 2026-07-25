using Windows.UI;

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

    /// <summary>Accent color for the Home screen's Rosary card — distinct per mystery group, not
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
