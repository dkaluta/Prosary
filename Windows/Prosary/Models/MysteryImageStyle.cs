using Prosary.Localization;

namespace Prosary.Models;

/// <summary>Which artwork set illustrates the mysteries. Persisted as a raw integer ordinal —
/// cases are append-only.</summary>
public enum MysteryImageStyle
{
    /// <summary>The classical paintings the app has always shipped.</summary>
    Classic,

    /// <summary>The Eastern icons ("eastern_"-prefixed image keys in the rosary pack).</summary>
    Eastern
}

public static class MysteryImageStyleExtensions
{
    public static string DisplayName(this MysteryImageStyle style) => style switch
    {
        MysteryImageStyle.Classic => Loc.Tr("imageStyle_classic", "Classical paintings"),
        MysteryImageStyle.Eastern => Loc.Tr("imageStyle_eastern", "Eastern icons"),
        _ => throw new ArgumentOutOfRangeException(nameof(style))
    };
}
