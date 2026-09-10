using Prosary.Models;

namespace Prosary.Persistence;

/// <summary>All windows observe committed library changes; failed writes publish nothing.</summary>
public static class DesktopLibraryChanges
{
    public static event Action? Changed;
    public static event Action<Guid>? Deleted;

    public static void Publish() => Changed?.Invoke();
    internal static void PublishDeleted(Guid id)
    {
        Deleted?.Invoke(id);
        Publish();
    }
}

/// <summary>The same SQLite library is shared by the library and independent prayer windows.</summary>
public sealed class DesktopPresetStore : IPresetStore
{
    private readonly IPresetStore inner;
    public DesktopPresetStore(SqlitePresetStore store) : this((IPresetStore)store) { }
    internal DesktopPresetStore(IPresetStore store) { inner = store; }
    public Task<List<Prayer>> GetAllAsync() => inner.GetAllAsync();
    public Task<Prayer?> GetDefaultAsync(PrayerKind kind) => inner.GetDefaultAsync(kind);
    public Task<Prayer?> GetAsync(Guid id) => inner.GetAsync(id);

    public async Task SaveAsync(Prayer prayer)
    {
        await inner.SaveAsync(prayer);
        DesktopLibraryChanges.Publish();
    }

    public async Task<bool> UpdateIfPresentAsync(Prayer prayer)
    {
        var updated = await inner.UpdateIfPresentAsync(prayer);
        if (updated) DesktopLibraryChanges.Publish();
        return updated;
    }

    public async Task DeleteAsync(Prayer prayer)
    {
        await inner.DeleteAsync(prayer);
        DesktopLibraryChanges.PublishDeleted(prayer.Id);
    }
}
