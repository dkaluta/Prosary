using Microsoft.UI;
using Windows.UI;

using Prosary.Localization;

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
    JesusPrayer = 2,

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
    /// <summary>Interface chrome stays in the interface language. Card names use PrayerCardName.</summary>
    public static string DisplayName(this PrayerKind kind)
    {
        return kind switch
        {
            PrayerKind.Rosary => Loc.Tr("kind_rosary", "Rosary"),
            PrayerKind.JesusPrayer => Loc.Tr("kind_jesus_prayer", "Jesus Prayer"),
            PrayerKind.Custom => Loc.Tr("kind_devotion", "Devotion"),
            _ => throw new ArgumentOutOfRangeException(nameof(kind))
        };
    }

    /// <summary>Default name suggested when the user creates a new favorite of this kind.</summary>
    public static string DefaultName(this PrayerKind kind) => kind switch
    {
        PrayerKind.Rosary => Loc.Tr("kind_default_name_rosary", "My Rosary"),
        PrayerKind.JesusPrayer => Loc.Tr("kind_jesus_prayer", "Jesus Prayer"),
        PrayerKind.Custom => Loc.Tr("kind_devotion", "Devotion"),
        _ => throw new ArgumentOutOfRangeException(nameof(kind))
    };

    /// <summary>Segoe Fluent Icons glyph approximating iOS's SF Symbol per kind
    /// (circle.grid.cross / heart). Codepoints verified against Microsoft's Segoe Fluent Icons
    /// documentation.</summary>
    public static string IconGlyph(this PrayerKind kind) => kind switch
    {
        PrayerKind.Rosary => "\uEA3A",      // CircleRing
        PrayerKind.JesusPrayer => "\uEB51", // Heart
        // Unreachable in practice -- .Custom rows read the bundle's own IconSystemName instead
        // (mapped via a small fixed table, e.g. GlyphForSystemName), not this per-kind glyph.
        // Still needed for exhaustiveness.
        PrayerKind.Custom => "\uE734", // FavoriteStar
        _ => throw new ArgumentOutOfRangeException(nameof(kind))
    };

    /// <summary>Accent color for this kind's cards/buttons across Pray and configuration
    /// surfaces (and, for Rosary, the bead-progress color in <c>BeadInfo</c>).</summary>
    public static Color AccentColor(this PrayerKind kind) => kind switch
    {
        PrayerKind.Rosary => Color.FromArgb(0xFF, 0x7A, 0x1F, 0x3D),
        PrayerKind.JesusPrayer => Color.FromArgb(0xFF, 0x8B, 0x1A, 0x1A),
        // Unreachable in practice — .Custom rows read the bundle's own AccentColorHex instead.
        // Still needed for exhaustiveness.
        PrayerKind.Custom => Color.FromArgb(0xFF, 0x7A, 0x1F, 0x3D),
        _ => throw new ArgumentOutOfRangeException(nameof(kind))
    };
}
