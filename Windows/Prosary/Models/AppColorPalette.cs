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

    internal static Color Parse(string hex)
    {
        var value = Convert.ToUInt32(hex, 16);
        return Color.FromArgb(255, (byte)(value >> 16), (byte)(value >> 8), (byte)value);
    }
}
