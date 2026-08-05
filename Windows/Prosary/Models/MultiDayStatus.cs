using Prosary.Localization;

namespace Prosary.Models;

/// <summary>
/// What a multi-day devotion should say about itself on its Pray card: how far through a run you
/// are, or — for a series that has not begun — when it traditionally starts, so a pinned novena
/// announces itself ahead of its first day rather than sitting there mute until you remember.
/// Port of iOS's MultiDayStatus.swift.
/// </summary>
public static class MultiDayStatus
{
    /// <summary>Null for anything that is not a tracked series, so single-day devotions and free
    /// day-sets keep their ordinary subtitle.</summary>
    public static string? Subtitle(string devotionId, DateTimeOffset? now = null)
    {
        var definition = PrayerPackStore.Definition(devotionId);
        var days = definition?.Days;
        if (days is null || days.Count <= 1 || (definition!.DayProgression ?? "series") != "series")
        {
            return null;
        }

        var today = now ?? DateTimeOffset.Now;
        if (MultiDayRuns.Run(devotionId) is { } run)
        {
            if (run.IsComplete(days.Count))
            {
                return Loc.Tr("multi_day_complete", "Complete");
            }

            var day = (run.NextUnprayedDay(days.Count) ?? 0) + 1;
            return string.Format(Loc.Tr("multi_day_day_of", "Day {0} of {1}"), day, days.Count);
        }

        if (StartDate(definition.SuggestedStart, today) is not { } start)
        {
            return null;
        }

        return start.Date == today.Date
            ? Loc.Tr("multi_day_starts_today", "Starts today")
            : string.Format(Loc.Tr("multi_day_starts_on", "Starts {0}"), start.ToString("M"));
    }

    /// <summary>The next occurrence of an annual "MM-DD" — this year's if it is still ahead,
    /// otherwise next year's, so a devotion whose date has passed announces the coming one.</summary>
    public static DateTimeOffset? StartDate(string? suggestedStart, DateTimeOffset? now = null)
    {
        var parts = suggestedStart?.Split('-');
        if (parts is not { Length: 2 } ||
            !int.TryParse(parts[0], out var month) ||
            !int.TryParse(parts[1], out var day))
        {
            return null;
        }

        var today = (now ?? DateTimeOffset.Now).Date;
        DateTime candidate;
        try
        {
            candidate = new DateTime(today.Year, month, day);
        }
        catch (ArgumentOutOfRangeException)
        {
            return null;
        }

        if (candidate < today)
        {
            candidate = candidate.AddYears(1);
        }

        return new DateTimeOffset(candidate);
    }

    /// <summary>The devotion to offer when a run finishes, or null. A bundle may point at
    /// something this device has never installed — a hand-written series naming its author's other
    /// work, say — so an unresolvable suggestion is simply not offered rather than shown as a
    /// dead end.</summary>
    public static (string Id, string Name)? SuggestedNext(string devotionId)
    {
        var suggestion = PrayerPackStore.Definition(devotionId)?.SuggestedNext;
        if (suggestion is null || PrayerPackStore.Info(suggestion) is not { } info)
        {
            return null;
        }

        return (suggestion, info.LocalizedDisplayName);
    }
}
