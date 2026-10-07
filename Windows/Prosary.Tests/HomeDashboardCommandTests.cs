using Prosary.Models;
using Prosary.Persistence;
using Prosary.ViewModels;
using Xunit;

namespace Prosary.Tests;

public class HomeDashboardCommandTests
{
    [Fact]
    public void ConsecutiveLayoutActionsPreserveChangesBeforeThePageReloadsItsCards()
    {
        var previous = AppSettings.HomeWidgetOrder.ToArray();
        try
        {
            AppSettings.SetHomeWidgetOrder([]);
            var dashboard = new DashboardViewModel(new UnusedPresetStore());
            var photo = new HomeWidgetCard { Id = "photo", Title = "Photo", Glyph = "" };
            var reflection = new HomeWidgetCard { Id = "reflection", Title = "Reflection", Glyph = "" };
            dashboard.AddCommand.Execute(photo);
            dashboard.AddCommand.Execute(reflection);
            // The page schedules its collection refresh through DispatcherQueue; settings
            // must already include both actions even while this collection is still empty.
            Assert.Empty(dashboard.Cards);
            Assert.Equal(new[] { "photo", "reflection" }, AppSettings.HomeWidgetOrder);
            dashboard.RemoveCommand.Execute(photo);
            Assert.Equal(new[] { "reflection" }, AppSettings.HomeWidgetOrder);
            dashboard.RemoveCommand.Execute(reflection);
            Assert.Empty(AppSettings.HomeWidgetOrder);
        }
        finally { AppSettings.SetHomeWidgetOrder(previous); }
    }

    private sealed class UnusedPresetStore : IPresetStore
    {
        public Task<List<Prayer>> GetAllAsync() => throw new NotSupportedException();
        public Task<Prayer?> GetDefaultAsync(PrayerKind kind) => throw new NotSupportedException();
        public Task<Prayer?> GetAsync(Guid id) => throw new NotSupportedException();
        public Task SaveAsync(Prayer prayer) => throw new NotSupportedException();
        public Task<bool> UpdateIfPresentAsync(Prayer prayer) => throw new NotSupportedException();
        public Task DeleteAsync(Prayer prayer) => throw new NotSupportedException();
    }
}
