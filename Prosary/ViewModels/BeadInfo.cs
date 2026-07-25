using Microsoft.UI;
using Prosary.Models;
using Windows.UI;

namespace Prosary.ViewModels;

public enum BeadKind { Cross, Decade, Antiphon }

public enum BeadState { Completed, Current, Upcoming }

/// <summary>One dot/glyph in the Rosary progress indicator — ported to match iOS's
/// <c>BeadModels.swift</c>/Android's <c>BeadModels.kt</c> exactly (not irosary's older, simpler
/// version this file originally mirrored).</summary>
public sealed class BeadInfo
{
    private static readonly Color CurrentColor = ColorFromHex("#7A1F3D");
    private static readonly Color CompletedColor = ColorFromHex("#6E6E6E");
    private static readonly Color UpcomingColor = ColorFromHex("#ACACAC");

    public required BeadKind Kind { get; init; }
    public required BeadState State { get; init; }

    /// <summary>True for the first bead of each group-of-5, so the UI can add extra spacing there
    /// — only ever set on the bottom/minor (current-decade) beads, and only actually used by the
    /// narrow layout's single-row rendering (see RosaryPrayerPage.xaml's GroupStartLeadingMargin
    /// converter usage) — the wide layout's minor-bead column(s) don't add this extra gap.</summary>
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

    private static Color ColorFromHex(string hex)
    {
        var value = Convert.ToUInt32(hex.TrimStart('#'), 16);
        return Color.FromArgb(0xFF, (byte)(value >> 16), (byte)(value >> 8), (byte)value);
    }
}

/// <summary>One mystery group's column of decade beads, for the wide layout's grid (one column
/// per group in the session, e.g. 3 columns for a 15-mystery session, so a long session grows
/// wider rather than awkwardly taller).</summary>
public sealed class BeadColumn
{
    public required MysteryGroup Group { get; init; }
    public required IReadOnlyList<BeadInfo> Beads { get; init; }
}
