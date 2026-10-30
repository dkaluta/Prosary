using Prosary.Localization;
using Windows.UI;

namespace Prosary.Models;

public sealed record AppColorOption(string Id, string EnglishName, string LightHex, string DarkHex)
{
    public string Label => Loc.Tr($"app_color_{Id}", EnglishName);
    public Color Accent(bool dark) => AppColorPalette.Parse(dark ? DarkHex : LightHex);
    // The icon is deliberately identical in light and dark appearances.
    public string IconFileName => $"prosary-{Id}.ico";
}

/// <summary>Shared appColor identifiers and accessible light/dark accent pairs.</summary>
public static class AppColorPalette
{
    public static IReadOnlyList<string> PaletteColors(string id) => id switch {
        "stainedGlass" => ["blue", "green", "gold", "rose"],
        "garden" => ["green", "rose", "blue", "gold"],
        _ => [] };
    public const string Default = "blue";
    public static IReadOnlyList<AppColorOption> All { get; } =
    [
        new("blue", "Blue (Mary)", "1768AC", "8DC8FF"),
        new("green", "Green", "287D49", "8AD4A1"),
        new("red", "Red", "B52E3E", "FFB1B5"),
        new("purple", "Purple", "7545A0", "D7B4F4"),
        new("rose", "Rose", "AD3F70", "F3B0CB"),
        new("white", "White", "8B681B", "F0D389"),
        new("gold", "Gold", "886419", "F0D389"),
    ];

    public static AppColorOption Resolve(string? id) => All.FirstOrDefault(option => option.Id == id) ?? All[0];

    public static string NormalizeCustom(string? hex)
    {
        var value = (hex ?? "").Trim();
        if (value.StartsWith('#')) value = value[1..];
        return value.Length == 6 && value.All(Uri.IsHexDigit) ? "#" + value.ToUpperInvariant() : "";
    }

    public static Color Accent(string? paletteId, string? customHex, bool dark) =>
        NormalizeCustom(customHex) is { Length: > 0 } normalized
            ? AccessibleAccent(Parse(normalized[1..]), dark) : Resolve(paletteId).Accent(dark);

    /// <summary>Resolve the translucent native card surface before tinting it. Its RGB is
    /// white in both themes, so treating that RGB as opaque would erase dark-mode contrast.</summary>
    public static Color TintedCardBackground(Color tint, Color surface, Color page, double surfaceOpacity = 1, double strength = 0.24)
    {
        var alpha = Math.Clamp(surface.A / 255.0 * surfaceOpacity, 0, 1);
        byte channel(byte accent, byte foreground, byte underlying) =>
            (byte)Math.Round(accent * strength + (foreground * alpha + underlying * (1 - alpha)) * (1 - strength));
        return Color.FromArgb(255, channel(tint.R, surface.R, page.R),
            channel(tint.G, surface.G, page.G), channel(tint.B, surface.B, page.B));
    }

    internal static Color AccessibleAccent(Color color, bool dark)
    {
        var background = dark ? Parse("2B2B2B") : Parse("FFFFFF");
        var target = dark ? 255 : 0;
        for (var step = 0; step <= 100; step++)
        {
            var amount = step / 100.0;
            var adjusted = Color.FromArgb(255,
                (byte)Math.Round(color.R + (target - color.R) * amount),
                (byte)Math.Round(color.G + (target - color.G) * amount),
                (byte)Math.Round(color.B + (target - color.B) * amount));
            if (Contrast(adjusted, background) >= 4.5) return adjusted;
        }
        return Color.FromArgb(255, (byte)target, (byte)target, (byte)target);
    }

    internal static double Contrast(Color first, Color second)
    {
        static double Luminance(Color value)
        {
            static double Linear(byte channel)
            {
                var value = channel / 255.0;
                return value <= 0.04045 ? value / 12.92 : Math.Pow((value + 0.055) / 1.055, 2.4);
            }
            return 0.2126 * Linear(value.R) + 0.7152 * Linear(value.G) + 0.0722 * Linear(value.B);
        }
        var a = Luminance(first); var b = Luminance(second);
        return (Math.Max(a, b) + 0.05) / (Math.Min(a, b) + 0.05);
    }

    internal static Color Parse(string hex)
    {
        var value = Convert.ToUInt32(hex, 16);
        return Color.FromArgb(255, (byte)(value >> 16), (byte)(value >> 8), (byte)value);
    }
}
