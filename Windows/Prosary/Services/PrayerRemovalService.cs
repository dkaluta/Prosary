using Prosary.Localization;
using Prosary.Models;
using Prosary.Persistence;

namespace Prosary.Services;

public sealed record PrayerRemovalPlan(Prayer Prayer, bool RemovesDownload);

/// <summary>Whether deletion committed matters: a later cleanup failure must never be
/// presented as though the saved prayer still exists.</summary>
public sealed class PrayerRemovalException(string message, bool prayerWasDeleted, Exception? inner = null)
    : Exception(message, inner)
{
    public bool PrayerWasDeleted { get; } = prayerWasDeleted;
}

/// <summary>Saved-copy removal is separate from unpinning. Only a successfully deleted final
/// copy can release its installed pack; explicit Downloads actions accept unused packs only.</summary>
public sealed class PrayerRemovalService
{
    private readonly IPresetStore _presets;
    private readonly IReminderScheduler _reminders;
    private readonly IPrayerRunStore _runs;
    private readonly Func<IReadOnlyList<string>> _installedIds;
    private readonly Action<string> _removePack;
    private readonly Action<string> _unpin;
    private readonly Action<string> _clearSeries;

    public PrayerRemovalService(IPresetStore presets, IReminderScheduler reminders, IPrayerRunStore runs)
        : this(presets, reminders, runs, PrayerPackStore.InstalledBundleIds,
            PrayerPackStore.RemoveInstalledPack, FavoriteDevotions.RemoveStoredPin, MultiDayRuns.Remove) { }

    internal PrayerRemovalService(IPresetStore presets, IReminderScheduler reminders, IPrayerRunStore runs,
        Func<IReadOnlyList<string>> installedIds, Action<string> removePack, Action<string> unpin,
        Action<string>? clearSeries = null)
    {
        _presets = presets;
        _reminders = reminders;
        _runs = runs;
        _installedIds = installedIds;
        _removePack = removePack;
        _unpin = unpin;
        _clearSeries = clearSeries ?? (_ => { });
    }

    private bool IsDownloaded(string id) => !PrayerPackStore.IsBuiltInBundle(id) && _installedIds().Contains(id);
    private static bool UsesBundle(Prayer prayer, string id) => prayer.CustomDevotionId == id;

    public async Task<PrayerRemovalPlan?> PlanAsync(Guid prayerId)
    {
        var prayer = await _presets.GetAsync(prayerId);
        if (prayer is null) return null;
        var removesDownload = prayer.Kind == PrayerKind.Custom && prayer.CustomDevotionId is { } id
            && IsDownloaded(id)
            && !(await _presets.GetAllAsync()).Any(other => other.Id != prayer.Id && UsesBundle(other, id));
        return new PrayerRemovalPlan(prayer, removesDownload);
    }

    public async Task DeleteAsync(Guid prayerId)
    {
        Prayer? prayer;
        try
        {
            prayer = await _presets.GetAsync(prayerId);
            if (prayer is null) return;
            await _presets.DeleteAsync(prayer);
        }
        catch (Exception error)
        {
            throw new PrayerRemovalException(Loc.Tr("prayerRemoval_deleteFailed",
                "The prayer could not be deleted. Please try again."), false, error);
        }

        try { _reminders.RemoveAll(prayer); }
        catch (Exception error)
        {
            throw new PrayerRemovalException(Loc.Tr("prayerRemoval_remindersFailed",
                "The prayer was deleted, but its reminders could not be canceled."), true, error);
        }

        try
        {
            if (prayer.Kind == PrayerKind.Rosary) _runs.Remove(PrayerRunKeys.Rosary(prayer.Id));
            if (prayer.Kind == PrayerKind.JesusPrayer) _runs.Remove(PrayerRunKeys.Jesus(prayer.Id, prayer.JesusPrayer.Target));
            if (prayer.Kind == PrayerKind.Custom && prayer.CustomDevotionId is { } customId)
            {
                var copyId = DesktopPrayerIdentity.DevotionID(customId, prayer.Id);
                _clearSeries(copyId);
                _reminders.RefreshSeries(customId, copyId);
                _runs.RemovePrefix($"custom:{copyId}:");
            }
            if (prayer.Kind == PrayerKind.Custom && prayer.CustomDevotionId is { } id && IsDownloaded(id))
            {
                // Re-read after the store commit. A sibling added since confirmation keeps
                // the archive, and a store failure never reaches this point.
                if (!(await _presets.GetAllAsync()).Any(other => UsesBundle(other, id)))
                {
                    RemoveUnusedPack(id);
                }
            }
        }
        catch (Exception error)
        {
            throw new PrayerRemovalException(Loc.Tr("prayerRemoval_cleanupFailed",
                "The prayer was deleted, but its download could not be removed. Try again in Downloads."), true, error);
        }
    }

    public async Task<bool> HasSavedCopiesAsync(string bundleId) =>
        (await _presets.GetAllAsync()).Any(prayer => UsesBundle(prayer, bundleId));

    public async Task<IReadOnlyList<string>> UnusedDownloadIdsAsync()
    {
        var prayers = await _presets.GetAllAsync();
        return _installedIds().Where(id => !PrayerPackStore.IsBuiltInBundle(id)
            && !prayers.Any(prayer => UsesBundle(prayer, id))).ToList();
    }

    public async Task RemoveDownloadAsync(string bundleId)
    {
        if (!IsDownloaded(bundleId)) return;
        if (await HasSavedCopiesAsync(bundleId))
            throw new PrayerRemovalException(Loc.Tr("prayerRemoval_downloadInUse",
                "Delete the saved copies of this prayer before removing its download."), false);
        RemoveUnusedPack(bundleId);
    }

    private void RemoveUnusedPack(string bundleId)
    {
        // Clearing the shared series run first makes RefreshSeries cancel scheduled daily
        // prompts instead of rescheduling them. Sibling copies never enter this path.
        _clearSeries(bundleId);
        _reminders.RefreshSeries(bundleId);
        _removePack(bundleId);
        _unpin(bundleId);
    }

    public async Task RemoveUnusedDownloadsAsync()
    {
        var failures = new List<Exception>();
        foreach (var id in await UnusedDownloadIdsAsync())
        {
            // Each call rechecks usage; a newly saved copy must survive a bulk cleanup too.
            try { await RemoveDownloadAsync(id); }
            catch (Exception error) { failures.Add(error); }
        }
        if (failures.Count > 0) throw new AggregateException(failures);
    }

    public static string ErrorMessage(Exception error) => error is PrayerRemovalException removal
        ? removal.Message
        : Loc.Tr("prayerRemoval_failedMessage", "Some items could not be removed. Please try again.");
}
