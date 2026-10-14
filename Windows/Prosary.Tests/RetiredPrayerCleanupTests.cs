using Prosary.Models;
using Prosary.Persistence;
using Prosary.Services;
using Xunit;

namespace Prosary.Tests;

public sealed class RetiredPrayerCleanupTests
{
    [Fact]
    public void SavedAndLegacyStateAreCanceledOnlyForTheWithdrawnIdentity()
    {
        var retired = new Prayer { Kind = PrayerKind.Custom, CustomDevotionId = RetiredPrayerBundles.GamlielLoreto };
        var copyId = DesktopPrayerIdentity.DevotionID(retired.CustomDevotionId, retired.Id);
        var other = retired with { Id = Guid.NewGuid(), CustomDevotionId = "litanyOfLoreto" };
        var scheduler = new RecordingReminders();
        string? persisted = null;
        var runs = new LocalPrayerRunStore(() => persisted, value => persisted = value);
        var checkpoint = new PrayerRunState("fixture", 2, "en", "2026-10-14");
        var copyKey = PrayerRunKeys.Custom(copyId, null, 0);
        var legacyKey = PrayerRunKeys.Custom(retired.CustomDevotionId, null, 0);
        var otherKey = PrayerRunKeys.Custom("litanyOfLoreto", null, 0);
        runs.Save(copyKey, checkpoint);
        runs.Save(legacyKey, checkpoint);
        runs.Save(otherKey, checkpoint);
        var cleared = new List<string>();
        var unpinned = new List<string>();

        RetiredPrayerCleanup.RemoveSavedState(other, scheduler, runs, cleared.Add);
        RetiredPrayerCleanup.RemoveSavedState(retired with { Kind = PrayerKind.Rosary }, scheduler, runs, cleared.Add);
        RetiredPrayerCleanup.RemoveBundleState("litanyOfLoreto", scheduler, runs, cleared.Add, unpinned.Add);
        RetiredPrayerCleanup.RemoveSavedState(retired, scheduler, runs, cleared.Add);
        RetiredPrayerCleanup.RemoveBundleState(retired.CustomDevotionId, scheduler, runs, cleared.Add, unpinned.Add);

        Assert.Equal([retired.Id], scheduler.Removed);
        Assert.Equal([retired.Id], scheduler.RemovedHistory);
        Assert.Equal([copyId, retired.CustomDevotionId], scheduler.RemovedSeriesHistory);
        Assert.Equal([copyId, retired.CustomDevotionId], cleared);
        Assert.Equal([retired.CustomDevotionId], unpinned);
        Assert.Equal([(retired.CustomDevotionId, copyId), (retired.CustomDevotionId, retired.CustomDevotionId)], scheduler.Refreshed);
        Assert.Null(runs.Get(copyKey));
        Assert.Null(runs.Get(legacyKey));
        Assert.Equal(checkpoint, runs.Get(otherKey));
    }

    private sealed class RecordingReminders : IReminderScheduler
    {
        public List<Guid> Removed { get; } = [];
        public List<Guid> RemovedHistory { get; } = [];
        public List<string> RemovedSeriesHistory { get; } = [];
        public List<(string Bundle, string Run)> Refreshed { get; } = [];
        public Task<bool> RequestPermissionAsync() => Task.FromResult(true);
        public void Schedule(Prayer prayer) => throw new InvalidOperationException("Retirement must not schedule reminders.");
        public void RemoveAll(Prayer prayer) => Removed.Add(prayer.Id);
        public void RemoveRetiredHistory(Prayer prayer) => RemovedHistory.Add(prayer.Id);
        public void RemoveRetiredSeriesHistory(string runId) => RemovedSeriesHistory.Add(runId);
        public void RescheduleAll(IEnumerable<Prayer> prayers) => throw new InvalidOperationException("Retirement must not reschedule reminders.");
        public void RefreshSeries(string devotionId) => Refreshed.Add((devotionId, devotionId));
        public void RefreshSeries(string devotionId, string runId) => Refreshed.Add((devotionId, runId));
    }
}
