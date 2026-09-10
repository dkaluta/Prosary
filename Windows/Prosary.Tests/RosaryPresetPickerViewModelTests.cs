using Prosary.Models;
using Prosary.Persistence;
using Prosary.Services;
using Prosary.ViewModels;
using Xunit;

namespace Prosary.Tests;

public class RosaryPresetPickerViewModelTests : IClassFixture<PrayerPackLoaderFixture>
{
    [Fact]
    public async Task AdHocPrayerForNavigation_ReusesInstanceUntilPickerReloads()
    {
        var viewModel = new RosaryPresetPickerViewModel(new MemoryPresetStore());
        await viewModel.LoadAsync();

        var firstActivation = viewModel.AdHocPrayerForNavigation();
        var pairedActivation = viewModel.AdHocPrayerForNavigation();

        Assert.Same(firstActivation, pairedActivation);

        await viewModel.LoadAsync();
        var laterVisit = viewModel.AdHocPrayerForNavigation();

        Assert.NotSame(firstActivation, laterVisit);
        Assert.NotEqual(firstActivation.Id, laterVisit.Id);
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task CombinedClosingControlLoadsOldSelectionsAndClearsOverridesWhenSaved(bool enabled)
    {
        var original = new Prayer
        {
            Kind = PrayerKind.Rosary,
            Name = "Legacy partial intentions",
            IsDefault = true,
            Rosary = new RosaryOptions { IncludeClosingBishopIntention = true },
        };
        var store = new MemoryPresetStore(original);
        var picker = new RosaryPresetPickerViewModel(store);
        await picker.LoadAsync();
        Assert.True(picker.IncludeClosingIntentions);
        picker.IncludeClosingIntentions = enabled;
        AssertCombinedChoice(picker.AdHocPrayer().Rosary, enabled);
        Assert.Equal(original, store.Saved);

        var editor = new FavoriteEditorViewModel(store, new SilentReminders());
        await editor.LoadAsync(original.Id, PrayerKind.Rosary);
        Assert.True(editor.IncludeClosingIntentions);
        editor.IncludeClosingIntentions = enabled;
        await editor.SaveCommand.ExecuteAsync(null);
        AssertCombinedChoice(store.Saved!.Rosary, enabled);
    }

    private static void AssertCombinedChoice(RosaryOptions options, bool enabled)
    {
        Assert.Equal(enabled, options.IncludeClosingIntentions);
        Assert.Equal(enabled, options.EffectiveClosingIntentions);
        Assert.Null(options.IncludeClosingPopeIntention);
        Assert.Null(options.IncludeClosingBishopIntention);
        Assert.Null(options.IncludeClosingDepartedIntention);
    }

    private sealed class MemoryPresetStore(Prayer? initial = null) : IPresetStore
    {
        public Prayer? Saved { get; private set; } = initial;
        public Task<List<Prayer>> GetAllAsync() => Task.FromResult(Saved is { } prayer ? new List<Prayer> { prayer } : []);
        public Task<Prayer?> GetDefaultAsync(PrayerKind kind) => Task.FromResult(Saved?.Kind == kind ? Saved : null);
        public Task<Prayer?> GetAsync(Guid id) => Task.FromResult(Saved?.Id == id ? Saved : null);
        public Task SaveAsync(Prayer prayer) { Saved = prayer; return Task.CompletedTask; }
        public Task<bool> UpdateIfPresentAsync(Prayer prayer)
        {
            if (Saved?.Id != prayer.Id) return Task.FromResult(false);
            Saved = prayer;
            return Task.FromResult(true);
        }
        public Task DeleteAsync(Prayer prayer) { Saved = null; return Task.CompletedTask; }
    }

    private sealed class SilentReminders : IReminderScheduler
    {
        public Task<bool> RequestPermissionAsync() => Task.FromResult(true);
        public void Schedule(Prayer prayer) { }
        public void RemoveAll(Prayer prayer) { }
        public void RescheduleAll(IEnumerable<Prayer> prayers) { }
        public void RefreshSeries(string devotionId) { }
    }
}
