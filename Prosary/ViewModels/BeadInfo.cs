using Microsoft.UI.Xaml;
using Windows.UI;

namespace Prosary.ViewModels;

public enum BeadKind { Cross, Decade, Antiphon }

public enum BeadState { Completed, Current, Upcoming }

/// <summary>One dot/glyph in the Rosary progress indicator. Ported from irosary's
/// <c>BeadInfo.cs</c>, retargeted from MAUI's <c>Color</c>/<c>Thickness</c> to WinUI3's.</summary>
public sealed class BeadInfo
{
    private static readonly Color CurrentColor = ColorFromHex("#7A1F3D");
    private static readonly Color CompletedColor = ColorFromHex("#6E6E6E");
    private static readonly Color UpcomingColor = ColorFromHex("#ACACAC");

    public required BeadKind Kind { get; init; }
    public required BeadState State { get; init; }

    /// <summary>True for the first bead of each group-of-5, so the UI can add extra spacing there.</summary>
    public bool IsGroupStart { get; init; }

    public bool IsCross => Kind == BeadKind.Cross;
    public bool IsAntiphon => Kind == BeadKind.Antiphon;
    public bool IsCircle => Kind != BeadKind.Cross;

    public double CircleSize => Kind == BeadKind.Antiphon ? 20 : 14;

    public Color Color => State switch
    {
        BeadState.Current => CurrentColor,
        BeadState.Completed => CompletedColor,
        _ => UpcomingColor
    };

    // Uniform on all sides (not just the stacking axis) so the same value works whether the
    // bead sits in a horizontal StackPanel (narrow layout) or a vertical one (wide two-column
    // layout's vertical bead track) — only the axis the parent stacks along matters for spacing,
    // so the cross-axis inset is just a harmless bit of breathing room.
    public Thickness Margin => new(IsGroupStart ? 8 : 2);

    private static Color ColorFromHex(string hex)
    {
        var value = Convert.ToUInt32(hex.TrimStart('#'), 16);
        return Color.FromArgb(0xFF, (byte)(value >> 16), (byte)(value >> 8), (byte)value);
    }
}

/// <summary>One row of beads in the wide layout's vertical bead track (4 decade beads per row),
/// with an alignment so the opening cross sits at the left edge and the antiphon/closing-cross
/// beads sit at the right edge, matching where they'd hang on a physical rosary.</summary>
public sealed class BeadRow
{
    public required IReadOnlyList<BeadInfo> Beads { get; init; }
    public required HorizontalAlignment Alignment { get; init; }
}
