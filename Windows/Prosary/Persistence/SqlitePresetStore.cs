using Prosary.Models;
using SQLite;
using Windows.Storage;

namespace Prosary.Persistence;

/// <summary>
/// SQLite-backed (<c>sqlite-net-pcl</c>) <see cref="IPresetStore"/> — ported from irosary's
/// <c>PresetRepository</c>, corrected to real per-kind semantics: irosary's default-clear/
/// promote logic was unscoped across every row (it predates Angelus/Jesus Prayer, when "every
/// row" and "every Rosary row" were the same thing). Seeds one default Rosary favorite
/// ("Classic Rosary") if the table is empty, matching both irosary's own seed and iOS's
/// <c>SwiftDataPresetStore.seedPrayer</c>.
/// </summary>
public sealed class SqlitePresetStore : IPresetStore
{
    private readonly SQLiteAsyncConnection _connection;
    private readonly Task _initialization;

    public SqlitePresetStore() : this(Path.Combine(ApplicationData.Current.LocalFolder.Path, "prosary_presets.db3"))
    {
    }

    /// <summary>Takes an explicit db path (rather than always resolving one via
    /// <see cref="ApplicationData"/>) so tests can point at a temp file directly — the WinRT
    /// <see cref="ApplicationData"/> APIs only work inside a running packaged app, not a plain
    /// unit test host.</summary>
    public SqlitePresetStore(string dbPath)
    {
        _connection = new SQLiteAsyncConnection(dbPath);
        _initialization = InitializeAsync();
    }

    private async Task InitializeAsync()
    {
        await _connection.CreateTableAsync<PresetEntry>();

        if (await _connection.Table<PresetEntry>().CountAsync() == 0)
        {
            await _connection.InsertAsync(new PresetEntry { Name = "Classic Rosary", IsDefault = true, Kind = PrayerKind.Rosary });
        }
    }

    public async Task<List<Prayer>> GetAllAsync()
    {
        await _initialization;
        var rows = await _connection.Table<PresetEntry>().OrderBy(r => r.Name).ToListAsync();
        return rows.Select(r => r.ToPrayer()).ToList();
    }

    public async Task<Prayer?> GetDefaultAsync(PrayerKind kind)
    {
        await _initialization;
        var rows = await _connection.Table<PresetEntry>().Where(r => r.Kind == kind).ToListAsync();
        var chosen = rows.FirstOrDefault(r => r.IsDefault) ?? rows.FirstOrDefault();
        return chosen?.ToPrayer();
    }

    public async Task<Prayer?> GetAsync(Guid id)
    {
        await _initialization;
        var row = await _connection.Table<PresetEntry>().Where(r => r.Id == id).FirstOrDefaultAsync();
        return row?.ToPrayer();
    }

    public async Task SaveAsync(Prayer prayer)
    {
        await _initialization;

        if (prayer.IsDefault)
        {
            await _connection.ExecuteAsync(
                "UPDATE PresetEntry SET IsDefault = 0 WHERE Kind = ? AND Id <> ?", (int)prayer.Kind, prayer.Id);
        }

        await _connection.InsertOrReplaceAsync(PresetEntry.FromPrayer(prayer));
    }

    public async Task DeleteAsync(Prayer prayer)
    {
        await _initialization;
        await _connection.DeleteAsync<PresetEntry>(prayer.Id);

        var remaining = await _connection.Table<PresetEntry>().Where(r => r.Kind == prayer.Kind).ToListAsync();
        if (remaining.Count > 0 && !remaining.Any(r => r.IsDefault))
        {
            var newDefault = remaining[0];
            newDefault.IsDefault = true;
            await _connection.UpdateAsync(newDefault);
        }
    }
}
