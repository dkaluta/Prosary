namespace Prosary.Services;

/// <summary>Direction changes presentation only; command meanings remain stable.</summary>
public static class PrayerNavigation
{
    public static string PreviousGlyph(bool isRightToLeft) => isRightToLeft ? "⏭" : "⏮";
    public static string NextGlyph(bool isRightToLeft) => isRightToLeft ? "⏮" : "⏭";
}
