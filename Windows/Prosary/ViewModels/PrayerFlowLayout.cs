namespace Prosary.ViewModels;

/// <summary>Matches the actual image, bead cells, divider, gaps and text column in both flow
/// pages. Width and height belong to their content row, after page padding and chrome.</summary>
public readonly record struct PrayerFlowLayout(bool IsWide, double ImageSide, bool HasRoomForSingleMinorColumn)
{
    public static double BeadWidth(int groupCount, bool showsBeads, bool hasMinorBeads, bool singleMinorColumn)
    {
        if (!showsBeads) return 0;
        var majorWidth = Math.Max(1, groupCount) * 20 + Math.Max(0, groupCount - 1) * 6;
        // Two 6px gaps surround the 1px divider with 4px margins on each side.
        return majorWidth + (hasMinorBeads ? 21 + (singleMinorColumn ? 20 : 46) : 0);
    }

    public static PrayerFlowLayout Resolve(double width, double height, int groupCount,
        bool showsBeads, bool hasMinorBeads)
    {
        var imageSide = Math.Clamp(height, 0, 320);
        var singleMinorColumn = height >= 300;
        var neededWidth = imageSide + 48 + 300
            + BeadWidth(groupCount, showsBeads, hasMinorBeads, singleMinorColumn);
        // Preserve the comfortable desktop breakpoint (860 minus the page's 40px padding),
        // raising it whenever the session needs more room. Reserve minor beads for the session
        // so moving from an announcement to a Hail Mary does not rearrange the reading surface.
        return new(width >= Math.Max(820, neededWidth) && height > 0, imageSide, singleMinorColumn);
    }
}
