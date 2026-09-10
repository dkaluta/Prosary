using Prosary.Localization;
using Prosary.Models;
using Prosary.Persistence;
using Prosary.Services;
using Prosary.ViewModels;
using Xunit;

namespace Prosary.Tests;

public class PrayerRemovalTests : IClassFixture<PrayerPackLoaderFixture>
{
    public PrayerRemovalTests(PrayerPackLoaderFixture _) { }

    private static Prayer Download(string id = "repo.example.prayer") => new()
    {
        Name = "Saved copy", Kind = PrayerKind.Custom, CustomDevotionId = id,
        Reminders = [new PrayerReminder { Hour = 8, Minute = 0 }],
    };

    [Fact]
    public async Task FinalSavedCopyDeletesBeforeRemindersAndDownloadCleanup()
    {
        var prayer = Download();
        var harness = new Harness(prayer);
        harness.Installed.Add(prayer.CustomDevotionId!);
        Assert.True((await harness.Service.PlanAsync(prayer.Id))!.RemovesDownload);

        await harness.Service.DeleteAsync(prayer.Id);

        Assert.Empty(harness.Store.Prayers);
        Assert.Equal(new[] { "delete", "reminders", "pack" }, harness.Events);
        Assert.Equal(new[] { prayer.Id }, harness.Reminders.Removed);
        Assert.Empty(harness.Installed);
        Assert.Equal(new[] { prayer.CustomDevotionId }, harness.Unpinned);
        Assert.Equal(new[] { DesktopPrayerIdentity.DevotionID(prayer.CustomDevotionId!, prayer.Id), prayer.CustomDevotionId }, harness.ClearedSeries);
        Assert.Equal(new[] { prayer.CustomDevotionId }, harness.Reminders.RefreshedSeries);
    }

    [Fact]
    public async Task SiblingCopyAndUnrelatedDownloadsSurviveDeletion()
    {
        var prayer = Download();
        var sibling = prayer with { Id = Guid.NewGuid(), Name = "Other copy" };
        var unrelated = Download("repo.example.other");
        var harness = new Harness(prayer, sibling, unrelated);
        harness.Installed.AddRange([prayer.CustomDevotionId!, unrelated.CustomDevotionId!]);
        Assert.False((await harness.Service.PlanAsync(prayer.Id))!.RemovesDownload);

        await harness.Service.DeleteAsync(prayer.Id);

        Assert.Equal(new[] { sibling.Id, unrelated.Id }, harness.Store.Prayers.Select(p => p.Id));
        Assert.Equal(2, harness.Installed.Count);
        Assert.Empty(harness.Unpinned);
        Assert.Equal(new[] { prayer.Id }, harness.Reminders.Removed);
        Assert.Equal(new[] { DesktopPrayerIdentity.DevotionID(prayer.CustomDevotionId!, prayer.Id) }, harness.ClearedSeries);
        Assert.Empty(harness.Reminders.RefreshedSeries);
        Assert.Equal(new[] { DesktopPrayerIdentity.DevotionID(prayer.CustomDevotionId!, prayer.Id) }, harness.Reminders.RefreshedCopySeries);
    }

    [Fact]
    public async Task CopyCreatedAfterConfirmationKeepsItsDownload()
    {
        var prayer = Download();
        var harness = new Harness(prayer);
        harness.Installed.Add(prayer.CustomDevotionId!);
        Assert.True((await harness.Service.PlanAsync(prayer.Id))!.RemovesDownload);
        harness.Store.AfterDelete = () => harness.Store.Prayers.Add(prayer with { Id = Guid.NewGuid() });

        await harness.Service.DeleteAsync(prayer.Id);

        Assert.Single(harness.Store.Prayers);
        Assert.Single(harness.Installed);
        Assert.Empty(harness.Unpinned);
    }

    [Theory]
    [InlineData("rosary")]
    [InlineData("angelus")]
    [InlineData("trisagion")]
    public async Task BuiltInPacksAreNeverRemovalCandidatesEvenWithAnIncorrectInstalledEntry(string id)
    {
        var prayer = Download(id);
        var harness = new Harness(prayer);
        harness.Installed.Add(id);
        Assert.False((await harness.Service.PlanAsync(prayer.Id))!.RemovesDownload);
        await harness.Service.DeleteAsync(prayer.Id);
        await harness.Service.RemoveDownloadAsync(id);
        Assert.Empty(await harness.Service.UnusedDownloadIdsAsync());
        Assert.Single(harness.Installed);
        Assert.DoesNotContain("pack", harness.Events);
    }

    [Fact]
    public async Task FailedStoreDeleteDoesNotCancelRemindersOrTouchThePack()
    {
        var prayer = Download();
        var harness = new Harness(prayer);
        harness.Installed.Add(prayer.CustomDevotionId!);
        harness.Store.FailDelete = true;

        var error = await Assert.ThrowsAsync<PrayerRemovalException>(() => harness.Service.DeleteAsync(prayer.Id));

        Assert.False(error.PrayerWasDeleted);
        Assert.Contains("could not be deleted", error.Message);
        Assert.Single(harness.Store.Prayers);
        Assert.Single(harness.Installed);
        Assert.Empty(harness.Reminders.Removed);
        Assert.Empty(harness.Unpinned);
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task CleanupFailureReportsThatThePrayerWasAlreadyDeleted(bool failRemainingCopyRead)
    {
        var prayer = Download();
        var harness = new Harness(prayer);
        harness.Installed.Add(prayer.CustomDevotionId!);
        if (failRemainingCopyRead) harness.Store.FailReadsAfterDelete = true;
        else harness.FailedPacks.Add(prayer.CustomDevotionId!);

        var error = await Assert.ThrowsAsync<PrayerRemovalException>(() => harness.Service.DeleteAsync(prayer.Id));

        Assert.True(error.PrayerWasDeleted);
        Assert.Contains("was deleted", error.Message);
        Assert.Empty(harness.Store.Prayers);
        Assert.Single(harness.Installed);
        Assert.Equal(new[] { prayer.Id }, harness.Reminders.Removed);
        Assert.Empty(harness.Unpinned);
    }

    [Fact]
    public async Task RemindersFailureIsNotReportedAsAStoreRollback()
    {
        var prayer = Download();
        var harness = new Harness(prayer);
        harness.Installed.Add(prayer.CustomDevotionId!);
        harness.Reminders.Fail = true;
        var error = await Assert.ThrowsAsync<PrayerRemovalException>(() => harness.Service.DeleteAsync(prayer.Id));
        Assert.True(error.PrayerWasDeleted);
        Assert.Contains("reminders could not be canceled", error.Message);
        Assert.Empty(harness.Store.Prayers);
        Assert.Single(harness.Installed);
    }

    [Fact]
    public async Task DownloadsRemovalRejectsSavedCopiesAndAcceptsANeverSavedPack()
    {
        var prayer = Download();
        var harness = new Harness(prayer);
        harness.Installed.AddRange([prayer.CustomDevotionId!, "repo.example.unused"]);
        var error = await Assert.ThrowsAsync<PrayerRemovalException>(() =>
            harness.Service.RemoveDownloadAsync(prayer.CustomDevotionId!));
        Assert.Contains("Delete the saved copies", error.Message);
        await harness.Service.RemoveDownloadAsync("repo.example.unused");
        Assert.Single(harness.Store.Prayers);
        Assert.Equal(new[] { prayer.CustomDevotionId }, harness.Installed);
        Assert.Empty(harness.Reminders.Removed);
    }

    [Fact]
    public async Task BulkRemovalPreservesUsedAndBuiltInPacksAndContinuesAfterOneFailure()
    {
        var prayer = Download();
        var harness = new Harness(prayer);
        harness.Installed.AddRange([prayer.CustomDevotionId!, "repo.example.broken", "repo.example.unused", "rosary"]);
        harness.FailedPacks.Add("repo.example.broken");
        await Assert.ThrowsAsync<AggregateException>(() => harness.Service.RemoveUnusedDownloadsAsync());
        Assert.Equal(new[] { prayer.CustomDevotionId, "repo.example.broken", "rosary" }, harness.Installed);
        Assert.Equal(new[] { "repo.example.unused" }, harness.Unpinned);
        Assert.Single(harness.Store.Prayers);
        Assert.Empty(harness.Reminders.Removed);
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task HomeExposesDeletionForSavedGenericAndJesusPrayers(bool jesusPrayer)
    {
        var prayer = jesusPrayer
            ? new Prayer { Kind = PrayerKind.JesusPrayer, Name = "Saved Jesus Prayer" }
            : Download("angelus");
        var harness = new Harness(prayer);
        // Series state belongs to package-local storage; deletion tests use their own state.
        var home = new HomeViewModel(harness.Store, new LiturgicalCalendarService(), harness.Service,
            seriesSubtitle: _ => null);
        PrayerRemovalPlan? confirmed = null;
        home.ConfirmDelete = plan => { confirmed = plan; return Task.FromResult(true); };
        await home.LoadAsync();
        var id = jesusPrayer ? "jesusPrayer" : "custom.angelus";
        var card = home.DevotionCards.Concat(home.UnpinnedCards).Single(item => item.Id == id);
        Assert.True(card.CanDeleteSavedPrayer);

        await home.DeleteSavedPrayerCommand.ExecuteAsync(card);

        Assert.Equal(prayer.Id, confirmed!.Prayer.Id);
        Assert.Empty(harness.Store.Prayers);
        Assert.False(home.DevotionCards.Concat(home.UnpinnedCards).Single(item => item.Id == id).CanDeleteSavedPrayer);
    }

    [Fact]
    public async Task RosaryPresetDeletionRequiresConfirmationAndCancelsItsReminders()
    {
        var prayer = new Prayer { Name = "My Rosary", Kind = PrayerKind.Rosary, IsDefault = true };
        var harness = new Harness(prayer);
        var picker = new RosaryPresetPickerViewModel(harness.Store, harness.Service)
        {
            ConfirmDelete = _ => Task.FromResult(false),
        };
        await picker.LoadAsync();
        await picker.DeletePresetCommand.ExecuteAsync(prayer);
        Assert.Single(harness.Store.Prayers);
        Assert.Empty(harness.Reminders.Removed);
        picker.ConfirmDelete = _ => Task.FromResult(true);
        await picker.DeletePresetCommand.ExecuteAsync(prayer);
        Assert.Empty(harness.Store.Prayers);
        Assert.Equal(new[] { prayer.Id }, harness.Reminders.Removed);
        Assert.False(picker.HasDefaultPreset);
    }

    [Fact]
    public async Task JesusFlowDeleteTargetsTheOpenedCopyAndRequiresConfirmation()
    {
        var first = new Prayer { Name = "First", Kind = PrayerKind.JesusPrayer, LanguageCode = "en" };
        var opened = first with { Id = Guid.NewGuid(), Name = "Second" };
        var harness = new Harness(first, opened);
        var flow = new JesusPrayerViewModel(harness.Store, new LiturgicalCalendarService(),
            new LocalPrayerRunStore(() => null, _ => { }), harness.Service);
        flow.ConfirmDelete = _ => Task.FromResult(false);
        await flow.LoadAsync(opened.Id, null);
        Assert.Equal(opened.Id, flow.MatchingFavoriteId);
        await flow.ToggleFavoriteCommand.ExecuteAsync(null);
        Assert.Equal(2, harness.Store.Prayers.Count);
        flow.ConfirmDelete = plan =>
        {
            Assert.Equal(opened.Id, plan.Prayer.Id);
            return Task.FromResult(true);
        };
        await flow.ToggleFavoriteCommand.ExecuteAsync(null);
        Assert.Equal(first.Id, Assert.Single(harness.Store.Prayers).Id);
        Assert.Equal(new[] { opened.Id }, harness.Reminders.Removed);
        Assert.Null(flow.MatchingFavoriteId);
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task StaleEditorsReportDeletionWithoutSavingOrScheduling(bool remindersOnly)
    {
        var prayer = new Prayer { Kind = PrayerKind.JesusPrayer, Name = "Deleted copy", Reminders = [new PrayerReminder(8, 0)] };
        var harness = new Harness(prayer);
        var errors = new List<string>();
        Task ReportError(string message) { errors.Add(message); return Task.CompletedTask; }
        if (remindersOnly)
        {
            var editor = new RemindersOnlyEditorViewModel(harness.Store, harness.Reminders) { ShowSaveError = ReportError };
            await editor.LoadAsync(prayer.Id);
            await harness.Store.DeleteAsync(prayer);
            await editor.SaveCommand.ExecuteAsync(null);
        }
        else
        {
            var editor = new FavoriteEditorViewModel(harness.Store, harness.Reminders) { ShowSaveError = ReportError };
            await editor.LoadAsync(prayer.Id, prayer.Kind);
            await harness.Store.DeleteAsync(prayer);
            await editor.SaveCommand.ExecuteAsync(null);
        }
        Assert.Empty(harness.Store.Prayers);
        Assert.Equal(Loc.Tr("prayerRemoval_prayerRemoved", "This saved prayer has been deleted."), Assert.Single(errors));
        Assert.Empty(harness.Reminders.Removed);
        Assert.Empty(harness.Reminders.Scheduled);
    }

    [Fact]
    public async Task MakeDefaultForDeletedCopyKeepsTheSurvivingDefault()
    {
        var deleted = new Prayer { Kind = PrayerKind.Rosary, Name = "Deleted" };
        var survivor = deleted with { Id = Guid.NewGuid(), Name = "Survivor", IsDefault = true };
        var harness = new Harness(deleted, survivor);
        var picker = new RosaryPresetPickerViewModel(harness.Store);
        await picker.LoadAsync();
        await harness.Store.DeleteAsync(deleted);

        await picker.MakeDefaultCommand.ExecuteAsync(deleted);

        Assert.True(Assert.Single(harness.Store.Prayers).IsDefault);
        Assert.Equal(survivor.Id, Assert.Single(harness.Store.Prayers).Id);
    }

    [Fact]
    public async Task RosaryLanguageChangeCannotRecreateADeletedSavedCopy()
    {
        var prayer = new Prayer { Kind = PrayerKind.Rosary, Name = "Deleted" };
        var harness = new Harness(prayer);
        var calendar = new LiturgicalCalendarService();
        var flow = new RosaryViewModel(harness.Store, new PrayerEngine(calendar), calendar,
            new LocalPrayerRunStore(() => null, _ => { }));
        await flow.LoadAsync(prayer.Id);
        await harness.Store.DeleteAsync(prayer);

        await flow.SelectLanguageAsync("he");

        Assert.Empty(harness.Store.Prayers);
    }

    [Theory]
    [InlineData("language")]
    [InlineData("variant")]
    [InlineData("day")]
    public async Task CustomAutosaveCannotRecreateCopyDeletedAfterItsRead(string action)
    {
        var prayer = new Prayer { Kind = PrayerKind.Custom, CustomDevotionId = "trisagion", LanguageCode = "en" };
        var harness = new Harness(prayer);
        var calendar = new LiturgicalCalendarService();
        var flow = new CustomDevotionViewModel(harness.Store, new PrayerEngine(calendar), calendar,
            harness.Reminders, new LocalPrayerRunStore(() => null, _ => { }));
        await flow.LoadAsync(prayer.Id, "trisagion");
        harness.Store.DeleteOnNextRead = true;

        switch (action)
        {
            case "language": await flow.SelectLanguageAsync("he"); break;
            case "variant": await flow.SelectVariantAsync("syriac"); break;
            case "day": await flow.SelectDayAsync(0); break;
        }

        Assert.Empty(harness.Store.Prayers);
        Assert.False(harness.Store.DeleteOnNextRead);
    }

    private sealed class Harness
    {
        internal readonly List<string> Events = [];
        internal readonly List<string> Installed = [];
        internal readonly List<string> Unpinned = [];
        internal readonly List<string> ClearedSeries = [];
        internal readonly HashSet<string> FailedPacks = [];
        internal readonly MemoryPresetStore Store;
        internal readonly ReminderRecorder Reminders;
        internal readonly PrayerRemovalService Service;

        internal Harness(params Prayer[] prayers)
        {
            Store = new MemoryPresetStore(Events, prayers);
            Reminders = new ReminderRecorder(Events);
            Service = new PrayerRemovalService(Store, Reminders, new LocalPrayerRunStore(() => null, _ => { }),
                () => Installed.ToList(), id =>
                {
                    Events.Add("pack");
                    if (FailedPacks.Contains(id)) throw new IOException("Synthetic locked pack");
                    Installed.Remove(id);
                }, id => Unpinned.Add(id), id => ClearedSeries.Add(id));
        }
    }

    private sealed class MemoryPresetStore(List<string> events, params Prayer[] prayers) : IPresetStore
    {
        internal readonly List<Prayer> Prayers = [.. prayers];
        internal bool FailDelete;
        internal bool FailReadsAfterDelete;
        internal Action? AfterDelete;
        internal bool DeleteOnNextRead;
        private bool _hasDeleted;
        public Task<List<Prayer>> GetAllAsync() => FailReadsAfterDelete && _hasDeleted
            ? Task.FromException<List<Prayer>>(new IOException("Synthetic read failure"))
            : Task.FromResult(Prayers.ToList());
        public Task<Prayer?> GetAsync(Guid id)
        {
            var result = Prayers.FirstOrDefault(p => p.Id == id);
            if (DeleteOnNextRead)
            {
                DeleteOnNextRead = false;
                Prayers.RemoveAll(prayer => prayer.Id == id);
            }
            return Task.FromResult(result);
        }
        public Task<Prayer?> GetDefaultAsync(PrayerKind kind) =>
            Task.FromResult(Prayers.FirstOrDefault(p => p.Kind == kind && p.IsDefault)
                ?? Prayers.FirstOrDefault(p => p.Kind == kind));
        public Task SaveAsync(Prayer prayer)
        {
            Prayers.RemoveAll(p => p.Id == prayer.Id);
            Prayers.Add(prayer);
            return Task.CompletedTask;
        }
        public Task DeleteAsync(Prayer prayer)
        {
            if (FailDelete) throw new IOException("Synthetic delete failure");
            events.Add("delete");
            Prayers.RemoveAll(p => p.Id == prayer.Id);
            _hasDeleted = true;
            AfterDelete?.Invoke();
            return Task.CompletedTask;
        }

        public Task<bool> UpdateIfPresentAsync(Prayer prayer)
        {
            var index = Prayers.FindIndex(existing => existing.Id == prayer.Id);
            if (index < 0) return Task.FromResult(false);
            Prayers[index] = prayer;
            return Task.FromResult(true);
        }
    }

    private sealed class ReminderRecorder(List<string> events) : IReminderScheduler
    {
        internal readonly List<Guid> Removed = [];
        internal readonly List<Guid> Scheduled = [];
        internal readonly List<string> RefreshedSeries = [];
        internal bool Fail;
        public Task<bool> RequestPermissionAsync() => Task.FromResult(true);
        public void Schedule(Prayer prayer) => Scheduled.Add(prayer.Id);
        public void RemoveAll(Prayer prayer)
        {
            if (Fail) throw new IOException("Synthetic reminder failure");
            events.Add("reminders");
            Removed.Add(prayer.Id);
        }
        public void RescheduleAll(IEnumerable<Prayer> prayers) { }
        public void RefreshSeries(string devotionId) => RefreshedSeries.Add(devotionId);
        public void RefreshSeries(string devotionId, string runId) => RefreshedCopySeries.Add(runId);
        internal readonly List<string> RefreshedCopySeries = [];
    }
}
