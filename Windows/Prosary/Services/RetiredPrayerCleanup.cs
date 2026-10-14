using Prosary.Models;
using Prosary.Persistence;

namespace Prosary.Services;

/// <summary>Launch cleanup for exact withdrawn identities, before ordinary reminder rescheduling.</summary>
public static class RetiredPrayerCleanup
{
    public static void RemoveSavedState(Prayer prayer, IReminderScheduler reminders, IPrayerRunStore runs,
        Action<string>? clearSeries = null)
    {
        if (!RetiredPrayerBundles.Contains(prayer.Kind, prayer.CustomDevotionId)) return;
        var bundleId = prayer.CustomDevotionId!;
        reminders.RemoveAll(prayer);
        reminders.RemoveRetiredHistory(prayer);
        var copyId = DesktopPrayerIdentity.DevotionID(bundleId, prayer.Id);
        (clearSeries ?? MultiDayRuns.Remove)(copyId);
        reminders.RefreshSeries(bundleId, copyId);
        reminders.RemoveRetiredSeriesHistory(copyId);
        runs.RemovePrefix($"custom:{copyId}:");
    }

    public static void RemoveBundleState(string bundleId, IReminderScheduler reminders, IPrayerRunStore runs,
        Action<string>? clearSeries = null, Action<string>? unpin = null)
    {
        if (!RetiredPrayerBundles.Contains(bundleId)) return;
        (clearSeries ?? MultiDayRuns.Remove)(bundleId);
        reminders.RefreshSeries(bundleId);
        reminders.RemoveRetiredSeriesHistory(bundleId);
        runs.RemovePrefix($"custom:{bundleId}:");
        (unpin ?? FavoriteDevotions.RemoveStoredPin)(bundleId);
    }
}
