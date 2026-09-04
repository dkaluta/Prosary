using Prosary.Models;
using Prosary.Persistence;
using Prosary.ViewModels;
using Xunit;

namespace Prosary.Tests;

public class RosaryPresetPickerViewModelTests
{
    [Fact]
    public async Task AdHocPrayerForNavigation_ReusesInstanceUntilPickerReloads()
    {
        var viewModel = new RosaryPresetPickerViewModel(new EmptyPresetStore());
        await viewModel.LoadAsync();

        var firstActivation = viewModel.AdHocPrayerForNavigation();
        var pairedActivation = viewModel.AdHocPrayerForNavigation();

        Assert.Same(firstActivation, pairedActivation);

        await viewModel.LoadAsync();
        var laterVisit = viewModel.AdHocPrayerForNavigation();

        Assert.NotSame(firstActivation, laterVisit);
        Assert.NotEqual(firstActivation.Id, laterVisit.Id);
    }

    private sealed class EmptyPresetStore : IPresetStore
    {
        public Task<List<Prayer>> GetAllAsync() => Task.FromResult(new List<Prayer>());

        public Task<Prayer?> GetDefaultAsync(PrayerKind kind) => Task.FromResult<Prayer?>(null);

        public Task<Prayer?> GetAsync(Guid id) => Task.FromResult<Prayer?>(null);

        public Task SaveAsync(Prayer prayer) => Task.CompletedTask;

        public Task DeleteAsync(Prayer prayer) => Task.CompletedTask;
    }
}
