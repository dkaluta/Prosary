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

    /// <summary>Columns declared <c>[NotNull]</c> on <see cref="PresetEntry"/> that were added
    /// after this table first shipped, with the default the entity itself uses. sqlite-net's
    /// auto-migration adds a missing column with a bare <c>ALTER TABLE … ADD COLUMN</c>, and
    /// SQLite refuses that outright for a NOT NULL column ("Cannot add a NOT NULL column with
    /// default value NULL") — a NOT NULL column can only be added *with* a default. So they are
    /// added here first; <c>CreateTableAsync</c> then finds them present and leaves them alone.
    /// A column added to the entity in future belongs in this list the same day, unless it is
    /// nullable.</summary>
    private static readonly (string Name, string Declaration)[] NotNullColumnsAddedLater =
    [
        ("LanguageCode", "varchar NOT NULL DEFAULT ''"),
        ("CustomOptionsJson", "varchar NOT NULL DEFAULT '{}'"),
        ("RemindersJson", "varchar NOT NULL DEFAULT '[]'"),
    ];

    private async Task InitializeAsync()
    {
        await AddMissingNotNullColumnsAsync();
        await _connection.CreateTableAsync<PresetEntry>();

        // Rows written before the generic-devotion migration store the retired per-devotion
        // ordinals (see PrayerKind's explicit values). One guarded pass maps them to Custom +
        // the matching bundle id; must run after CreateTableAsync (which auto-adds the
        // CustomDevotionId column to old databases) and before seeding.
        var schemaVersion = await _connection.ExecuteScalarAsync<int>("PRAGMA user_version");
        if (schemaVersion < 1)
        {
            await _connection.ExecuteAsync(
                @"UPDATE PresetEntry SET CustomDevotionId = CASE Kind
                    WHEN 1 THEN 'angelus' WHEN 3 THEN 'stationsOfTheCross' WHEN 4 THEN 'franciscanCrown'
                    WHEN 5 THEN 'sevenSorrows' WHEN 6 THEN 'divineMercyChaplet' ELSE CustomDevotionId END,
                  Kind = 7 WHERE Kind IN (1, 3, 4, 5, 6)");
            await _connection.ExecuteAsync("PRAGMA user_version = 1");
        }

        if (await _connection.Table<PresetEntry>().CountAsync() == 0)
        {
            await _connection.InsertAsync(new PresetEntry { Name = "Classic Rosary", IsDefault = true, Kind = PrayerKind.Rosary });
        }
    }

    /// <summary>Adds any <see cref="NotNullColumnsAddedLater"/> the database is missing, with
    /// their defaults. No-op on a fresh install, where <c>CreateTableAsync</c> builds the whole
    /// table in one statement and no ALTER is involved.</summary>
    private async Task AddMissingNotNullColumnsAsync()
    {
        var tableExists = await _connection.ExecuteScalarAsync<int>(
            "SELECT count(*) FROM sqlite_master WHERE type = 'table' AND name = 'PresetEntry'");
        if (tableExists == 0)
        {
            return;
        }

        foreach (var (name, declaration) in NotNullColumnsAddedLater)
        {
            var present = await _connection.ExecuteScalarAsync<int>(
                "SELECT count(*) FROM pragma_table_info('PresetEntry') WHERE name = ?", name);
            if (present > 0)
            {
                continue;
            }

            await _connection.ExecuteAsync($"ALTER TABLE PresetEntry ADD COLUMN \"{name}\" {declaration}");
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
            // "One default per kind" is scoped per devotion: (Kind, CustomDevotionId) — two
            // different generic devotions must not steal each other's default slot.
            await _connection.ExecuteAsync(
                "UPDATE PresetEntry SET IsDefault = 0 WHERE Kind = ? AND IFNULL(CustomDevotionId, '') = IFNULL(?, '') AND Id <> ?",
                (int)prayer.Kind, prayer.CustomDevotionId, prayer.Id);
        }

        await _connection.InsertOrReplaceAsync(PresetEntry.FromPrayer(prayer));
    }

    public async Task DeleteAsync(Prayer prayer)
    {
        await _initialization;
        await _connection.DeleteAsync<PresetEntry>(prayer.Id);

        var remaining = (await _connection.Table<PresetEntry>().Where(r => r.Kind == prayer.Kind).ToListAsync())
            .Where(r => (r.CustomDevotionId ?? string.Empty) == (prayer.CustomDevotionId ?? string.Empty))
            .ToList();
        if (remaining.Count > 0 && !remaining.Any(r => r.IsDefault))
        {
            var newDefault = remaining[0];
            newDefault.IsDefault = true;
            await _connection.UpdateAsync(newDefault);
        }
    }
    /// <summary>Closes the underlying connection — needed by tests that delete their temp
    /// database file afterwards (Windows can't delete a file that is still open).</summary>
    public Task CloseAsync() => _connection.CloseAsync();

}
