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
    /// <summary>Decade beads wrapped into one row per mystery group — like the physical
    /// five-decade loops of a rosary — for the narrow layout's horizontal grid. Ungrouped
    /// custom-rosary sessions (Franciscan Crown, Seven Sorrows, Divine Mercy Chaplet) collapse
    /// to a single row.</summary>
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

        // Which mystery group each decade belongs to — null for decades with no mystery at all
        // (Franciscan Crown, Seven Sorrows, Divine Mercy Chaplet — none of which are "mysteries"
        // in the Rosary sense). Feeds both the narrow layout's row wrapping and the wide
        // layout's group columns below. Unlike Swift's dictionary subscript setter, C#'s
        // Dictionary indexer always stores the assigned value (including null) rather than
        // removing the entry, so this doesn't need Swift's updateValue(_:forKey:)-style
        // workaround.
        var decadeGroupOf = new Dictionary<int, MysteryGroup?>();
        foreach (var s in steps)
        {
            if (s.DecadeIndex is { } d && !decadeGroupOf.ContainsKey(d))
            {
                decadeGroupOf[d] = s.Mystery?.Group;
            }
        }

        // Wrapped per mystery group — like the physical five-decade loops of a rosary — so a
        // 15/20-mystery session breaks into one row per group, while an ungrouped custom-rosary
        // session (the Franciscan Crown's 7 Joys, the Seven Sorrows) keeps all its decade beads
        // on a single row instead of an arbitrary 5+2 split. The opening cross rides along with
        // the first row, and the antiphon/closing-cross beads (if any) tag onto the last row.
        var rows = new List<List<BeadInfo>> { new() { crossBead } };
        for (var d = 0; d < totalDecades; d++)
        {
            if (d > 0 && decadeGroupOf.GetValueOrDefault(d) != decadeGroupOf.GetValueOrDefault(d - 1))
            {
                rows.Add([]);
            }

            rows[^1].Add(decadeBeads[d]);
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
        // tall strip. Single-group sessions naturally collapse to one column, and mystery-less
        // decades collapse into one shared ungrouped (null-group) column instead of being
        // dropped entirely.
        var orderedGroups = new List<MysteryGroup?>();
        for (var d = 0; d < totalDecades; d++)
        {
            if (decadeGroupOf.TryGetValue(d, out var group) && !orderedGroups.Contains(group))
            {
                orderedGroups.Add(group);
            }
        }

        // Indexed by position in orderedGroups rather than a Dictionary<MysteryGroup?, ...> —
        // MysteryGroup? as a dictionary key trips Dictionary<TKey,TValue>'s `TKey : notnull`
        // constraint (Nullable<T> doesn't satisfy notnull, even though it works at runtime).
        var groupColumnBeads = orderedGroups.Select(_ => new List<BeadInfo>()).ToList();
        for (var d = 0; d < totalDecades; d++)
        {
            if (decadeGroupOf.TryGetValue(d, out var group))
            {
                var columnIndex = orderedGroups.IndexOf(group);
                if (columnIndex >= 0)
                {
                    groupColumnBeads[columnIndex].Add(decadeBeads[d]);
                }
            }
        }

        var groupColumns = orderedGroups
            .Select((g, i) => new BeadColumn { Group = g, Beads = groupColumnBeads[i] })
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

        // Hail-Marys-per-decade isn't always 10 (Seven Sorrows uses 7) — derive it from the
        // session's own step data instead of hardcoding, so this stays correct for every devotion.
        var hailMarysPerDecade = steps.Where(s => s.HailMaryIndexInDecade.HasValue)
            .Select(s => s.HailMaryIndexInDecade!.Value)
            .DefaultIfEmpty(10)
            .Max();

        var bottom = new List<BeadInfo>();
        for (var h = 1; h <= hailMarysPerDecade; h++)
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
