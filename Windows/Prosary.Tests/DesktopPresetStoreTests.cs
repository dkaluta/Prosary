using Prosary.Models;
using Prosary.Persistence;
using Xunit;

namespace Prosary.Tests;

[Collection("DesktopLibraryEvents")]
public sealed class DesktopPresetStoreTests
{
    [Fact]
    public async Task OnlyCommittedWritesPublishAndDeletedCopiesCannotBeRecreated()
    {
        var inner = new MemoryStore();
        var store = new DesktopPresetStore(inner);
        var prayer = new Prayer();
        var events = new List<string>();
        void Changed() => events.Add("changed");
        void Deleted(Guid id) => events.Add("deleted:" + id);
        DesktopLibraryChanges.Changed += Changed;
        DesktopLibraryChanges.Deleted += Deleted;
        try
        {
            inner.FailWrites = true;
            await Assert.ThrowsAsync<IOException>(() => store.SaveAsync(prayer));
            Assert.Empty(events);
            inner.FailWrites = false;
            await store.SaveAsync(prayer);
            Assert.Equal(new[] { "changed" }, events);
            events.Clear();
            await store.DeleteAsync(prayer);
            Assert.Equal(new[] { "deleted:" + prayer.Id, "changed" }, events);
            events.Clear();
            Assert.False(await store.UpdateIfPresentAsync(prayer with { Name = "Stale editor" }));
            Assert.Empty(events);
            Assert.Null(await store.GetAsync(prayer.Id));
        }
        finally
        {
            DesktopLibraryChanges.Changed -= Changed;
            DesktopLibraryChanges.Deleted -= Deleted;
        }
    }

    private sealed class MemoryStore : IPresetStore
    {
        public bool FailWrites { get; set; }
        private readonly Dictionary<Guid, Prayer> _prayers = [];
        public Task<List<Prayer>> GetAllAsync() => Task.FromResult(_prayers.Values.ToList());
        public Task<Prayer?> GetDefaultAsync(PrayerKind kind) => Task.FromResult(_prayers.Values.FirstOrDefault(prayer => prayer.Kind == kind));
        public Task<Prayer?> GetAsync(Guid id) => Task.FromResult(_prayers.GetValueOrDefault(id));
        public Task SaveAsync(Prayer prayer)
        {
            if (FailWrites) throw new IOException("Test write failure");
            _prayers[prayer.Id] = prayer;
            return Task.CompletedTask;
        }
        public Task<bool> UpdateIfPresentAsync(Prayer prayer)
        {
            if (!_prayers.ContainsKey(prayer.Id)) return Task.FromResult(false);
            _prayers[prayer.Id] = prayer;
            return Task.FromResult(true);
        }
        public Task DeleteAsync(Prayer prayer) { _prayers.Remove(prayer.Id); return Task.CompletedTask; }
    }
}

[CollectionDefinition("DesktopLibraryEvents", DisableParallelization = true)]
public sealed class DesktopLibraryEventsCollection { }
