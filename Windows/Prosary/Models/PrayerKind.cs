using Microsoft.UI;
using Windows.UI;

namespace Prosary.Models;

/// <summary>Discriminant for the type of a saved prayer session. Values are explicit and
/// permanent — <c>SqlitePresetStore</c> persists this enum as its int value, and
/// <c>SqlitePresetStore.InitializeAsync</c>'s legacy-kind migration maps the retired
/// per-devotion ordinals (1, 3–6: Angelus, Stations of the Cross, Franciscan Crown, Seven
/// Sorrows, Divine Mercy Chaplet) to <see cref="Custom"/> by number. Never renumber or reuse a
/// retired value.</summary>
public enum PrayerKind
{
    Rosary = 0,
    Angelus = 1,
    JesusPrayer = 2,
    StationsOfTheCross = 3,
    FranciscanCrown = 4,
    SevenSorrows = 5,
    DivineMercyChaplet = 6,

    /// <summary>Any devotion whose entire step sequence comes from a bundle's <c>devotion.json</c>
    /// instead of a hardcoded engine builder — see <c>PrayerEngine.BuildCustomDevotionSteps</c>
    /// and <see cref="Prayer.CustomDevotionId"/>. One case covers every such devotion; adding
    /// another doesn't need a new <see cref="PrayerKind"/> case, only a new bundle. The extension
    /// methods below return a generic fallback for this case — real call sites (Home, Favorites)
    /// read the actual devotion's name/icon from <c>PrayerPackStore.Info</c> instead, since a
    /// single <see cref="PrayerKind"/> value can't carry per-bundle data.</summary>
    Custom = 7
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
        PrayerKind.Custom => "Devotion",
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
        PrayerKind.Custom => "Devotion",
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
        // Unreachable in practice -- .Custom rows read the bundle's own IconSystemName instead
        // (mapped via a small fixed table, e.g. GlyphForSystemName), not this per-kind glyph.
        // Still needed for exhaustiveness.
        PrayerKind.Custom => "", // FavoriteStar
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
        // Unreachable in practice — .Custom rows read the bundle's own AccentColorHex instead.
        // Still needed for exhaustiveness.
        PrayerKind.Custom => Color.FromArgb(0xFF, 0x7A, 0x1F, 0x3D),
        _ => throw new ArgumentOutOfRangeException(nameof(kind))
    };
}
