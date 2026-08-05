using System.Text.Json;
using Windows.Storage;

namespace Prosary.Models;

/// <summary>
/// One run through a multi-day devotion — a novena's nine days, a triduum's three, a 33-day
/// consecration. The day count always comes from the bundle's own days array; nothing here
/// assumes nine. Port of iOS's MultiDayRun.swift.
///
/// Records *which* days were prayed rather than only how far you got, because "the day you
/// missed" and "the day today's date calls for" are different answers and the app offers both.
/// </summary>
public sealed record MultiDayRun(
    string DevotionId,
    DateTimeOffset StartedOn,
    List<int> PrayedDays,
    DateTimeOffset? LastPrayedOn = null)
{
    private static int ElapsedDays(DateTimeOffset from, DateTimeOffset to) =>
        (to.Date - from.Date).Days;

    /// <summary>The day the calendar calls for today, clamped to the devotion's length.</summary>
    public int DueDay(int dayCount, DateTimeOffset? now = null) =>
        Math.Clamp(ElapsedDays(StartedOn, now ?? DateTimeOffset.Now), 0, Math.Max(dayCount - 1, 0));

    /// <summary>The earliest day still unprayed, or null when the run is finished.</summary>
    public int? NextUnprayedDay(int dayCount)
    {
        for (var day = 0; day < dayCount; day++)
        {
            if (!PrayedDays.Contains(day)) return day;
        }
        return null;
    }

    /// <summary>A day that should have been prayed but was not.</summary>
    public int? MissedDay(int dayCount, DateTimeOffset? now = null)
    {
        if (NextUnprayedDay(dayCount) is not { } next) return null;
        return next < DueDay(dayCount, now) ? next : null;
    }

    public bool IsComplete(int dayCount) => NextUnprayedDay(dayCount) is null;

    /// <summary>Reopening the devotion the same day shows that day again rather than advancing.</summary>
    public bool HasPrayedToday(DateTimeOffset? now = null) =>
        LastPrayedOn is { } last && last.Date == (now ?? DateTimeOffset.Now).Date;

    public MultiDayRun RecordingPrayed(int day, DateTimeOffset? now = null)
    {
        var when = now ?? DateTimeOffset.Now;
        var days = PrayedDays.Contains(day) ? PrayedDays : [.. PrayedDays, day];
        return this with { PrayedDays = days, LastPrayedOn = when };
    }

    /// <summary>What opening the devotion should offer.</summary>
    public abstract record Resumption
    {
        public sealed record Start : Resumption;
        public sealed record Resume(int Day) : Resumption;
        public sealed record Choose(int Missed, int Next) : Resumption;
        public sealed record Complete : Resumption;
    }

    public Resumption GetResumption(int dayCount, DateTimeOffset? now = null)
    {
        if (dayCount <= 1) return new Resumption.Start();
        if (NextUnprayedDay(dayCount) is not { } next) return new Resumption.Complete();
        if (MissedDay(dayCount, now) is { } missed)
        {
            var due = DueDay(dayCount, now);
            return missed == due ? new Resumption.Resume(missed) : new Resumption.Choose(missed, due);
        }
        return new Resumption.Resume(next);
    }
}

/// <summary>
/// Where runs live: one per devotion, keyed by bundle id, in LocalSettings. Small transient
/// state rather than records — the same call iOS makes by keeping them out of SwiftData.
/// </summary>
public static class MultiDayRuns
{
    private const string Key = "multiDayRuns";

    private static Dictionary<string, MultiDayRun> All()
    {
        if (ApplicationData.Current.LocalSettings.Values[Key] is not string raw) return [];
        try
        {
            return JsonSerializer.Deserialize<Dictionary<string, MultiDayRun>>(raw) ?? [];
        }
        catch (JsonException)
        {
            return [];
        }
    }

    private static void Save(Dictionary<string, MultiDayRun> runs) =>
        ApplicationData.Current.LocalSettings.Values[Key] = JsonSerializer.Serialize(runs);

    public static MultiDayRun? Run(string devotionId) => All().GetValueOrDefault(devotionId);

    public static MultiDayRun StartFresh(string devotionId, DateTimeOffset? now = null)
    {
        var run = new MultiDayRun(devotionId, now ?? DateTimeOffset.Now, []);
        var all = All();
        all[devotionId] = run;
        Save(all);
        return run;
    }

    public static void RecordPrayed(string devotionId, int day, DateTimeOffset? now = null)
    {
        var when = now ?? DateTimeOffset.Now;
        var all = All();
        var existing = all.GetValueOrDefault(devotionId) ?? new MultiDayRun(devotionId, when, []);
        all[devotionId] = existing.RecordingPrayed(day, when);
        Save(all);
    }

    public static void Reset() => ApplicationData.Current.LocalSettings.Values.Remove(Key);
}
