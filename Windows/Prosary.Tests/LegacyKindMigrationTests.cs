using Prosary.Models;
using Prosary.Persistence;
using SQLite;
using Xunit;

namespace Prosary.Tests;

/// <summary>
/// Rows written before the generic-devotion migration store the retired per-devotion
/// <see cref="PrayerKind"/> ordinals (1, 3–6). <c>SqlitePresetStore.InitializeAsync</c>'s guarded
/// one-time pass (PRAGMA user_version) must map them to <see cref="PrayerKind.Custom"/> (7) + the
/// matching bundle id, exactly once, before seeding. Mirrors iOS's LegacyKindMigrationTests.swift
/// / Android's LegacyKindMigrationTest.kt (whose remaps are permanent read-time mappings instead —
/// cloud sync can deliver old rows there at any time; Windows has no cloud store, so a one-time
/// SQL pass suffices). The retired ordinals are written via unchecked enum casts so this test
/// keeps compiling after the cases themselves are deleted.
/// </summary>
public sealed class LegacyKindMigrationTests : IDisposable
{
    private readonly string _dbPath =
        Path.Combine(Path.GetTempPath(), $"prosary_migration_test_{Guid.NewGuid():N}.db3");

    public void Dispose()
    {
        if (File.Exists(_dbPath))
        {
            File.Delete(_dbPath);
        }
    }

    /// <summary>Writes rows into a fresh database file directly (no <see cref="SqlitePresetStore"/>,
    /// whose constructor would run the very migration under test).</summary>
    private async Task SeedRowsAsync(params PresetEntry[] rows)
    {
        var connection = new SQLiteAsyncConnection(_dbPath);
        await connection.CreateTableAsync<PresetEntry>();
        foreach (var row in rows)
        {
            await connection.InsertAsync(row);
        }
        await connection.CloseAsync();
    }

    private async Task<int> ReadUserVersionAsync()
    {
        var connection = new SQLiteAsyncConnection(_dbPath);
        var version = await connection.ExecuteScalarAsync<int>("PRAGMA user_version");
        await connection.CloseAsync();
        return version;
    }

    [Fact]
    public async Task InitializeAsync_MapsEveryLegacyOrdinalToCustomPlusItsBundleId()
    {
        var legacy = new (int Ordinal, string BundleId)[]
        {
            (1, "angelus"), (3, "stationsOfTheCross"), (4, "franciscanCrown"),
            (5, "sevenSorrows"), (6, "divineMercyChaplet"),
        };
        await SeedRowsAsync(legacy
            .Select(l => new PresetEntry { Name = l.BundleId, Kind = (PrayerKind)l.Ordinal })
            .ToArray());

        var store = new SqlitePresetStore(_dbPath);
        var all = await store.GetAllAsync();

        Assert.Equal(legacy.Length, all.Count);
        foreach (var (_, bundleId) in legacy)
        {
            var prayer = Assert.Single(all, p => p.Name == bundleId);
            Assert.Equal(PrayerKind.Custom, prayer.Kind);
            Assert.Equal(bundleId, prayer.CustomDevotionId);
        }
        Assert.Equal(1, await ReadUserVersionAsync());
    }

    [Fact]
    public async Task InitializeAsync_LeavesRosaryAndJesusPrayerRowsUntouched()
    {
        await SeedRowsAsync(
            new PresetEntry { Name = "R", Kind = PrayerKind.Rosary, IsDefault = true },
            new PresetEntry { Name = "J", Kind = PrayerKind.JesusPrayer });

        var store = new SqlitePresetStore(_dbPath);
        var all = await store.GetAllAsync();

        Assert.Equal(PrayerKind.Rosary, Assert.Single(all, p => p.Name == "R").Kind);
        Assert.Equal(PrayerKind.JesusPrayer, Assert.Single(all, p => p.Name == "J").Kind);
        Assert.All(all, p => Assert.Null(p.CustomDevotionId));
    }

    [Fact]
    public async Task InitializeAsync_LeavesExistingCustomRowsUntouched()
    {
        await SeedRowsAsync(
            new PresetEntry { Name = "T", Kind = PrayerKind.Custom, CustomDevotionId = "trisagion" });

        var store = new SqlitePresetStore(_dbPath);
        var prayer = Assert.Single(await store.GetAllAsync());

        Assert.Equal(PrayerKind.Custom, prayer.Kind);
        Assert.Equal("trisagion", prayer.CustomDevotionId);
    }

    [Fact]
    public async Task InitializeAsync_IsIdempotentAcrossReopens()
    {
        await SeedRowsAsync(new PresetEntry { Name = "A", Kind = (PrayerKind)1 });

        var first = new SqlitePresetStore(_dbPath);
        var afterFirst = Assert.Single(await first.GetAllAsync());

        // A row saved after the migration with a devotion id of its own must survive a second
        // initialization untouched (the user_version guard skips the UPDATE entirely).
        var second = new SqlitePresetStore(_dbPath);
        var afterSecond = Assert.Single(await second.GetAllAsync());

        Assert.Equal(PrayerKind.Custom, afterSecond.Kind);
        Assert.Equal("angelus", afterSecond.CustomDevotionId);
        Assert.Equal(afterFirst.Id, afterSecond.Id);
        Assert.Equal(1, await ReadUserVersionAsync());
    }

    [Fact]
    public async Task InitializeAsync_DoesNotSeedWhenMigratedRowsExist()
    {
        await SeedRowsAsync(new PresetEntry { Name = "A", Kind = (PrayerKind)1, IsDefault = true });

        var store = new SqlitePresetStore(_dbPath);
        var all = await store.GetAllAsync();

        Assert.DoesNotContain(all, p => p.Name == "Classic Rosary");
    }
}
