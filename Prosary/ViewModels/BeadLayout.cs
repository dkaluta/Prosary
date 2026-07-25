using Prosary.Models;

namespace Prosary.ViewModels;

/// <summary>
/// The full computed bead layout for the current step of a Rosary session — pure UI-computed
/// presentation state derived from the backend's <see cref="RosaryStep"/> list plus the current
/// index, not something the backend provides. Ported to match iOS's <c>BeadModels.swift</c>/
/// Android's <c>BeadModels.kt</c> exactly, replacing this project's earlier ad-hoc
/// rows-of-4-vertical-track version (which had no real precedent on either other platform).
/// </summary>
public sealed class BeadLayout
{
    /// <summary>Decade beads grouped into rows of 5 — like the physical layout of a rosary's
    /// Our-Father beads — for the narrow layout's wrapped horizontal grid.</summary>
    public IReadOnlyList<IReadOnlyList<BeadInfo>> TopRows { get; init; } = [];

    /// <summary>Opening cross, for the wide layout.</summary>
    public BeadInfo? OpeningCross { get; init; }

    /// <summary>One column per mystery group in the session, each holding that group's decade
    /// beads in order, for the wide layout's grid.</summary>
    public IReadOnlyList<BeadColumn> GroupColumns { get; init; } = [];

    /// <summary>Marian antiphon "M" bead, for the wide layout.</summary>
    public BeadInfo? Antiphon { get; init; }

    /// <summary>Closing cross, for the wide layout.</summary>
    public BeadInfo? ClosingCross { get; init; }

    /// <summary>Progress through the current decade's 10 Hail Marys.</summary>
    public IReadOnlyList<BeadInfo> BottomBeads { get; init; } = [];

    public bool ShowBottomBeads { get; init; }

    public static readonly BeadLayout Empty = new();

    public static BeadLayout Build(IReadOnlyList<RosaryStep> steps, int currentIndex, bool hasClosingCross, bool isDarkTheme)
    {
        if (currentIndex < 0 || currentIndex >= steps.Count)
        {
            return Empty;
        }

        var step = steps[currentIndex];

        var totalDecades = steps.Any(s => s.DecadeIndex.HasValue)
            ? steps.Where(s => s.DecadeIndex.HasValue).Max(s => s.DecadeIndex!.Value) + 1
            : 0;
        var firstDecadeStepIndex = steps.Select((s, i) => (s, i)).Where(t => t.s.DecadeIndex.HasValue)
            .Select(t => (int?)t.i).FirstOrDefault() ?? -1;
        var antiphonStepIndex = steps.Select((s, i) => (s, i)).Where(t => t.s.IsAntiphon)
            .Select(t => (int?)t.i).FirstOrDefault() ?? -1;

        var crossBead = new BeadInfo
        {
            Kind = BeadKind.Cross,
            State = currentIndex == 0 ? BeadState.Current : BeadState.Completed,
            IsDarkTheme = isDarkTheme
        };

        var decadeBeads = new List<BeadInfo>();
        for (var d = 0; d < totalDecades; d++)
        {
            var state = step.DecadeIndex switch
            {
                null when firstDecadeStepIndex < 0 || currentIndex < firstDecadeStepIndex => BeadState.Upcoming,
                null => BeadState.Completed, // past all decades (antiphon/closing phase)
                var current when d < current => BeadState.Completed,
                var current when d == current => BeadState.Current,
                _ => BeadState.Upcoming
            };
            decadeBeads.Add(new BeadInfo { Kind = BeadKind.Decade, State = state, IsDarkTheme = isDarkTheme });
        }

        BeadInfo? antiphonBead = null;
        if (antiphonStepIndex >= 0)
        {
            var state = currentIndex < antiphonStepIndex ? BeadState.Upcoming
                : currentIndex == antiphonStepIndex ? BeadState.Current
                : BeadState.Completed;
            antiphonBead = new BeadInfo { Kind = BeadKind.Antiphon, State = state, IsDarkTheme = isDarkTheme };
        }

        BeadInfo? closingCrossBead = null;
        if (hasClosingCross)
        {
            var closingCrossIndex = steps.Count - 1;
            closingCrossBead = new BeadInfo
            {
                Kind = BeadKind.Cross,
                State = currentIndex < closingCrossIndex ? BeadState.Upcoming : BeadState.Current,
                IsDarkTheme = isDarkTheme
            };
        }

        // Grouped into rows of 5 decade beads, mirroring the physical layout of a rosary's
        // Our-Father beads — the opening cross rides along with the first row, and the antiphon/
        // closing-cross beads (if any) tag onto whatever's left of the last row.
        var rows = new List<List<BeadInfo>> { new() { crossBead } };
        foreach (var (decadeBead, index) in decadeBeads.Select((b, i) => (b, i)))
        {
            rows[^1].Add(decadeBead);
            var decadeCountInRow = rows[^1].Count(b => b.Kind == BeadKind.Decade);
            if (decadeCountInRow % 5 == 0 && index != decadeBeads.Count - 1)
            {
                rows.Add([]);
            }
        }

        if (antiphonBead is { } antiphon)
        {
            rows[^1].Add(antiphon);
        }

        if (closingCrossBead is { } closing)
        {
            rows[^1].Add(closing);
        }

        // One column per mystery group (in session order), each holding that group's decade
        // beads — a 15/20-mystery session grows into more columns instead of one long, awkwardly-
        // tall strip. Single-group sessions naturally collapse to one column.
        var decadeGroupOf = new Dictionary<int, MysteryGroup>();
        foreach (var s in steps)
        {
            if (s.DecadeIndex is { } d && s.Mystery is { } mystery && !decadeGroupOf.ContainsKey(d))
            {
                decadeGroupOf[d] = mystery.Group;
            }
        }

        var orderedGroups = new List<MysteryGroup>();
        for (var d = 0; d < totalDecades; d++)
        {
            if (decadeGroupOf.TryGetValue(d, out var group) && !orderedGroups.Contains(group))
            {
                orderedGroups.Add(group);
            }
        }

        var groupColumnBeads = orderedGroups.ToDictionary(g => g, _ => new List<BeadInfo>());
        for (var d = 0; d < totalDecades; d++)
        {
            if (decadeGroupOf.TryGetValue(d, out var group))
            {
                groupColumnBeads[group].Add(decadeBeads[d]);
            }
        }

        var groupColumns = orderedGroups
            .Select(g => new BeadColumn { Group = g, Beads = groupColumnBeads[g] })
            .ToList();

        if (step.DecadeIndex is not { } decadeIndex)
        {
            return new BeadLayout
            {
                TopRows = rows,
                OpeningCross = crossBead,
                GroupColumns = groupColumns,
                Antiphon = antiphonBead,
                ClosingCross = closingCrossBead,
                BottomBeads = [],
                ShowBottomBeads = false
            };
        }

        var decadeStepIndices = steps
            .Select((s, i) => (s, i))
            .Where(t => t.s.DecadeIndex == decadeIndex && t.s.HailMaryIndexInDecade.HasValue)
            .Select(t => t.i)
            .ToList();
        if (decadeStepIndices.Count == 0)
        {
            return new BeadLayout
            {
                TopRows = rows,
                OpeningCross = crossBead,
                GroupColumns = groupColumns,
                Antiphon = antiphonBead,
                ClosingCross = closingCrossBead,
                BottomBeads = [],
                ShowBottomBeads = false
            };
        }

        var firstHailMaryIndex = decadeStepIndices.Min();
        var lastHailMaryIndex = decadeStepIndices.Max();

        var bottom = new List<BeadInfo>();
        for (var h = 1; h <= 10; h++)
        {
            BeadState state;
            if (currentIndex < firstHailMaryIndex)
            {
                state = BeadState.Upcoming;
            }
            else if (currentIndex > lastHailMaryIndex)
            {
                state = BeadState.Completed;
            }
            else
            {
                var current = step.HailMaryIndexInDecade!.Value;
                state = h < current ? BeadState.Completed : h == current ? BeadState.Current : BeadState.Upcoming;
            }

            bottom.Add(new BeadInfo
            {
                Kind = BeadKind.Decade,
                State = state,
                IsGroupStart = h > 1 && (h - 1) % 5 == 0,
                IsDarkTheme = isDarkTheme
            });
        }

        return new BeadLayout
        {
            TopRows = rows,
            OpeningCross = crossBead,
            GroupColumns = groupColumns,
            Antiphon = antiphonBead,
            ClosingCross = closingCrossBead,
            BottomBeads = bottom,
            ShowBottomBeads = true
        };
    }
}
