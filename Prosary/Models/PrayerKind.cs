namespace Prosary.Models;

/// <summary>Discriminant for the type of a saved prayer session. Add new cases here (and a
/// matching options type on <see cref="Prayer"/>) to expand into new devotions.</summary>
public enum PrayerKind
{
    Rosary,
    Angelus,
    JesusPrayer
}

public static class PrayerKindExtensions
{
    public static string DisplayName(this PrayerKind kind) => kind switch
    {
        PrayerKind.Rosary => "Rosary",
        PrayerKind.Angelus => "Angelus",
        PrayerKind.JesusPrayer => "Jesus Prayer",
        _ => throw new ArgumentOutOfRangeException(nameof(kind))
    };

    /// <summary>Default name suggested when the user creates a new favorite of this kind.</summary>
    public static string DefaultName(this PrayerKind kind) => kind switch
    {
        PrayerKind.Rosary => "My Rosary",
        PrayerKind.Angelus => "Angelus",
        PrayerKind.JesusPrayer => "Jesus Prayer",
        _ => throw new ArgumentOutOfRangeException(nameof(kind))
    };

    /// <summary>Segoe Fluent Icons glyph approximating iOS's SF Symbol per kind (circle.grid.cross
    /// / bell / heart). Codepoints chosen from memory of the Segoe MDL2/Fluent icon set, NOT
    /// verified on-screen from this (non-Windows) environment — check these render as intended on
    /// a real Windows build and swap for the correct codepoint from the Segoe Fluent Icons
    /// character map if not.</summary>
    public static string IconGlyph(this PrayerKind kind) => kind switch
    {
        PrayerKind.Rosary => "",      // CircleRing
        PrayerKind.Angelus => "",     // Ringer (bell)
        PrayerKind.JesusPrayer => "", // HeartFill
        _ => throw new ArgumentOutOfRangeException(nameof(kind))
    };
}
