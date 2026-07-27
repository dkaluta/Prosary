using Microsoft.UI;
using Windows.UI;

namespace Prosary.Models;

/// <summary>Discriminant for the type of a saved prayer session. Add new cases here (and a
/// matching options type on <see cref="Prayer"/>) to expand into new devotions.</summary>
public enum PrayerKind
{
    Rosary,
    Angelus,
    JesusPrayer,
    StationsOfTheCross,
    FranciscanCrown,
    SevenSorrows,
    DivineMercyChaplet
}

public static class PrayerKindExtensions
{
    public static string DisplayName(this PrayerKind kind) => kind switch
    {
        PrayerKind.Rosary => "Rosary",
        PrayerKind.Angelus => "Angelus",
        PrayerKind.JesusPrayer => "Jesus Prayer",
        PrayerKind.StationsOfTheCross => "Stations of the Cross",
        PrayerKind.FranciscanCrown => "Franciscan Crown",
        PrayerKind.SevenSorrows => "Seven Sorrows",
        PrayerKind.DivineMercyChaplet => "Divine Mercy Chaplet",
        _ => throw new ArgumentOutOfRangeException(nameof(kind))
    };

    /// <summary>Default name suggested when the user creates a new favorite of this kind.</summary>
    public static string DefaultName(this PrayerKind kind) => kind switch
    {
        PrayerKind.Rosary => "My Rosary",
        PrayerKind.Angelus => "Angelus",
        PrayerKind.JesusPrayer => "Jesus Prayer",
        PrayerKind.StationsOfTheCross => "Stations of the Cross",
        PrayerKind.FranciscanCrown => "Franciscan Crown",
        PrayerKind.SevenSorrows => "Seven Sorrows",
        PrayerKind.DivineMercyChaplet => "Divine Mercy Chaplet",
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
        PrayerKind.StationsOfTheCross => "", // Walk
        PrayerKind.FranciscanCrown => "", // Crown
        PrayerKind.SevenSorrows => "", // HeartBroken
        PrayerKind.DivineMercyChaplet => "", // Sunny
        _ => throw new ArgumentOutOfRangeException(nameof(kind))
    };

    /// <summary>Accent color for this kind's cards/buttons across Home and Favorites — matches
    /// Android's <c>accentFor(kind)</c> in <c>FavoritesListScreen.kt</c> (and, for Rosary, the
    /// bead-progress color in <c>BeadInfo</c>).</summary>
    public static Color AccentColor(this PrayerKind kind) => kind switch
    {
        PrayerKind.Rosary => Color.FromArgb(0xFF, 0x7A, 0x1F, 0x3D),
        PrayerKind.Angelus => Color.FromArgb(0xFF, 0x8B, 0x69, 0x14),
        PrayerKind.JesusPrayer => Color.FromArgb(0xFF, 0x8B, 0x1A, 0x1A),
        PrayerKind.StationsOfTheCross => Color.FromArgb(0xFF, 0x5C, 0x2D, 0x91),
        PrayerKind.FranciscanCrown => Color.FromArgb(0xFF, 0x6B, 0x42, 0x26),
        PrayerKind.SevenSorrows => Color.FromArgb(0xFF, 0x6B, 0x0F, 0x1A),
        PrayerKind.DivineMercyChaplet => Color.FromArgb(0xFF, 0xC4, 0x1E, 0x3A),
        _ => throw new ArgumentOutOfRangeException(nameof(kind))
    };
}
