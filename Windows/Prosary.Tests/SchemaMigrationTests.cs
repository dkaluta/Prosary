using Prosary.Models;
using Prosary.Persistence;
using SQLite;
using Xunit;

namespace Prosary.Tests;

/// <summary>
/// A database written by an older build lacks the columns added since. sqlite-net's
/// auto-migration adds a missing column with a bare <c>ALTER TABLE … ADD COLUMN</c>, which
/// SQLite refuses outright when the column is NOT NULL — "Cannot add a NOT NULL column with
/// default value NULL", thrown before the app can read a single favorite. These tests stand the
/// old schemas back up and demand the store still opens.
/// </summary>
public sealed class SchemaMigrationTests : IDisposable
{
    private readonly string _dbPath =
        Path.Combine(Path.GetTempPath(), $"prosary_schema_test_{Guid.NewGuid():N}.db3");

    public void Dispose()
    {
        if (File.Exists(_dbPath))
        {
            File.Delete(_dbPath);
        }
    }

    /// <summary>The v0.6-era table: no CustomOptionsJson (v0.7's options.json work), no
    /// VariantId, no DayIndex. Written as raw SQL rather than through the current entity, which
    /// would create today's columns and prove nothing.</summary>
    private async Task CreateLegacyTableAsync()
    {
        var connection = new SQLiteAsyncConnection(_dbPath);
        await connection.ExecuteAsync(
            """
            CREATE TABLE "PresetEntry" (
              "Id" varchar PRIMARY KEY NOT NULL,
              "Name" varchar(80) NOT NULL,
              "IsDefault" integer NOT NULL,
              "LanguageCode" varchar NOT NULL,
              "Kind" integer NOT NULL,
              "CustomDevotionId" varchar,
              "MysterySelectionMode" integer NOT NULL,
              "SpecificMysteryGroup" integer NOT NULL,
              "SpecificMysteryOrder" integer NOT NULL,
              "IncludeApostlesCreed" integer NOT NULL,
              "IncludeOpeningPrayers" integer NOT NULL,
              "IncludeFatimaPrayer" integer NOT NULL,
              "EternalRest" integer NOT NULL,
              "MarianAntiphon" integer NOT NULL,
              "IncludeStMichaelPrayer" integer NOT NULL,
              "IncludeFinalSignOfCross" integer NOT NULL,
              "PresenterMode" integer NOT NULL,
              "JesusPrayerIsUnbounded" integer NOT NULL,
              "JesusPrayerCount" integer NOT NULL,
              "RemindersJson" varchar NOT NULL
            )
            """);
        await connection.ExecuteAsync(
            """
            INSERT INTO "PresetEntry" ("Id", "Name", "IsDefault", "LanguageCode", "Kind",
              "MysterySelectionMode", "SpecificMysteryGroup", "SpecificMysteryOrder",
              "IncludeApostlesCreed", "IncludeOpeningPrayers", "IncludeFatimaPrayer",
              "EternalRest", "MarianAntiphon", "IncludeStMichaelPrayer", "IncludeFinalSignOfCross",
              "PresenterMode", "JesusPrayerIsUnbounded", "JesusPrayerCount", "RemindersJson")
            VALUES (?, 'Evening Rosary', 1, 'he', 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 1, 0, 0, 33, '[]')
            """,
            Guid.NewGuid().ToString());
        await connection.CloseAsync();
    }

    [Fact]
    public async Task ADatabaseFromBeforeTheOptionsColumnStillOpens()
    {
        await CreateLegacyTableAsync();

        var store = new SqlitePresetStore(_dbPath);
        var prayers = await store.GetAllAsync();

        var prayer = Assert.Single(prayers);
        Assert.Equal("Evening Rosary", prayer.Name);
        Assert.Equal("he", prayer.LanguageCode);
        // The column the old database lacked reads as its default rather than as null.
        Assert.Empty(prayer.CustomOptions);
    }

    [Fact]
    public async Task TheSameDatabaseOpensTwiceWithoutReAddingColumns()
    {
        await CreateLegacyTableAsync();

        _ = await new SqlitePresetStore(_dbPath).GetAllAsync();
        var prayers = await new SqlitePresetStore(_dbPath).GetAllAsync();

        Assert.Single(prayers);
    }

    [Fact]
    public async Task AFreshDatabaseSeedsItsDefaultPrayer()
    {
        var store = new SqlitePresetStore(_dbPath);

        var prayers = await store.GetAllAsync();

        Assert.Single(prayers);
        Assert.Equal(PrayerKind.Rosary, prayers[0].Kind);
    }
}
