namespace Prosary.Services;

/// <summary>Direction changes presentation only; command meanings remain stable.</summary>
public static class PrayerNavigation
{
    // Segoe Fluent/MDL2 Previous and Next, rendered by FontIcon rather than an emoji font.
    public static string PreviousGlyph(bool isRightToLeft) => isRightToLeft ? "\uE893" : "\uE892";
    public static string NextGlyph(bool isRightToLeft) => isRightToLeft ? "\uE892" : "\uE893";
}
