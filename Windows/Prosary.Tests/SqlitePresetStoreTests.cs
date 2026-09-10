using Prosary.Models;
using Prosary.Persistence;
using Xunit;

namespace Prosary.Tests;

/// <summary>
/// Covers the one genuine behavioral correction this store makes over irosary's
/// <c>PresetRepository</c> (which predates Angelus/Jesus Prayer, so its default-clear/promote
/// logic was never scoped to a single kind): saving or deleting a default favorite of one kind
/// must never touch another kind's default. Each test gets its own temp SQLite file so they don't
/// interfere with each other or leave files behind.
/// </summary>
public sealed class SqlitePresetStoreTests : IDisposable
{
    private readonly string _dbPath;
    private readonly SqlitePresetStore _store;

    public SqlitePresetStoreTests()
    {
        _dbPath = Path.Combine(Path.GetTempPath(), $"prosary_test_{Guid.NewGuid():N}.db3");
        _store = new SqlitePresetStore(_dbPath);
    }

    public void Dispose()
    {
        // Windows can't delete an open file — release the connection first.
        _store.CloseAsync().GetAwaiter().GetResult();
        if (File.Exists(_dbPath))
        {
            File.Delete(_dbPath);
        }
    }

    [Fact]
    public async Task OldCombinedClosingChoicePreservesNullableCompatibilityFields()
    {
        var oldPath = Path.Combine(Path.GetTempPath(), $"prosary_legacy_{Guid.NewGuid():N}.db3");
        var id = Guid.NewGuid();
        using (var legacy = new SQLite.SQLiteConnection(oldPath))
        {
            legacy.Execute("CREATE TABLE PresetEntry (Id varchar PRIMARY KEY, Name varchar NOT NULL, IncludeClosingIntentions integer)");
            legacy.Execute("INSERT INTO PresetEntry (Id, Name, IncludeClosingIntentions) VALUES (?, ?, ?)", id, "Legacy Rosary", 1);
        }
        var migrated = new SqlitePresetStore(oldPath);
        try
        {
            var loaded = (await migrated.GetAsync(id))!;
            Assert.NotNull(loaded);
            Assert.True(loaded.Rosary.IncludeClosingIntentions);
            Assert.Null(loaded.Rosary.IncludeClosingPopeIntention);
            Assert.Null(loaded.Rosary.IncludeClosingBishopIntention);
            Assert.Null(loaded.Rosary.IncludeClosingDepartedIntention);
            Assert.True(loaded.Rosary.EffectiveClosingPopeIntention);
            Assert.True(loaded.Rosary.EffectiveClosingBishopIntention);
            Assert.True(loaded.Rosary.EffectiveClosingDepartedIntention);
            await migrated.SaveAsync(loaded with { Rosary = loaded.Rosary with
            {
                IncludeClosingPopeIntention = false,
                IncludeClosingDepartedIntention = true,
            }});
            var saved = (await migrated.GetAsync(id))!.Rosary;
            Assert.False(saved.IncludeClosingPopeIntention);
            Assert.Null(saved.IncludeClosingBishopIntention);
            Assert.True(saved.IncludeClosingDepartedIntention);
            Assert.True(saved.EffectiveClosingIntentions);
            Assert.True(saved.EffectiveClosingPopeIntention);
            Assert.True(saved.EffectiveClosingBishopIntention);
            Assert.True(saved.EffectiveClosingDepartedIntention);
        }
        finally
        {
            await migrated.CloseAsync();
            File.Delete(oldPath);
        }
    }

    /// <summary>The generic-devotion fields must survive a real save/load through the SQLite
    /// row's JSON columns (the domain dictionary has no column of its own).</summary>
    [Fact]
    public async Task SaveAsync_RoundTripsVariantAndCustomOptions()
    {
        var prayer = new Prayer
        {
            Name = "Crown, short form",
            Kind = PrayerKind.Custom,
            CustomDevotionId = "franciscanCrown",
            VariantId = "scriptural",
            CustomOptions = new Dictionary<string, string> { ["seventyTwoHailMarys"] = "false" },
        };
        await _store.SaveAsync(prayer);

        var loaded = await _store.GetAsync(prayer.Id);
        Assert.NotNull(loaded);
        Assert.Equal("franciscanCrown", loaded!.CustomDevotionId);
        Assert.Equal("scriptural", loaded.VariantId);
        Assert.Equal("false", loaded.CustomOptions["seventyTwoHailMarys"]);
    }

    /// <summary>"One default per kind" is scoped per (Kind, CustomDevotionId) — two different
    /// generic devotions must not steal each other's default slot.</summary>
    [Fact]
    public async Task SaveAsync_NewDefaultOfOneCustomDevotion_DoesNotClearAnotherCustomDevotionsDefault()
    {
        var angelus = new Prayer { Name = "A", Kind = PrayerKind.Custom, CustomDevotionId = "angelus", IsDefault = true };
        await _store.SaveAsync(angelus);

        var trisagion = new Prayer { Name = "T", Kind = PrayerKind.Custom, CustomDevotionId = "trisagion", IsDefault = true };
        await _store.SaveAsync(trisagion);

        var all = await _store.GetAllAsync();
        Assert.True(all.Single(p => p.Id == angelus.Id).IsDefault);
        Assert.True(all.Single(p => p.Id == trisagion.Id).IsDefault);
    }

    [Fact]
    public async Task InitializeAsync_EmptyStore_SeedsOneDefaultRosaryFavorite()
    {
        var all = await _store.GetAllAsync();
        var rosaryDefaults = all.Where(p => p.Kind == PrayerKind.Rosary && p.IsDefault).ToList();
        Assert.Single(rosaryDefaults);
        Assert.Equal("Classic Rosary", rosaryDefaults[0].Name);
    }

    [Fact]
    public async Task DeletingTheFinalSavedPrayerStaysEmptyAfterReopening()
    {
        var seeded = Assert.Single(await _store.GetAllAsync());
        await _store.DeleteAsync(seeded);
        await _store.CloseAsync();
        var reopened = new SqlitePresetStore(_dbPath);
        try { Assert.Empty(await reopened.GetAllAsync()); }
        finally { await reopened.CloseAsync(); }
    }

    [Fact]
    public async Task ExistingEmptyLegacyTableDoesNotGainAnUnrequestedSeed()
    {
        var oldPath = Path.Combine(Path.GetTempPath(), $"prosary_empty_legacy_{Guid.NewGuid():N}.db3");
        using (var legacy = new SQLite.SQLiteConnection(oldPath))
            legacy.Execute("CREATE TABLE PresetEntry (Id varchar PRIMARY KEY, Name varchar NOT NULL)");
        var migrated = new SqlitePresetStore(oldPath);
        try { Assert.Empty(await migrated.GetAllAsync()); }
        finally
        {
            await migrated.CloseAsync();
            File.Delete(oldPath);
        }
    }

    [Fact]
    public async Task SaveAsync_NewDefaultOfOneKind_DoesNotClearAnotherKindsDefault()
    {
        var angelus = new Prayer { Name = "My Angelus", Kind = PrayerKind.Custom, CustomDevotionId = "angelus", IsDefault = true };
        await _store.SaveAsync(angelus);

        // Saving a new default Rosary favorite clears the seeded "Classic Rosary"'s default —
        // it must NOT touch the Angelus favorite's default just saved above.
        var rosary = new Prayer { Name = "My Rosary", Kind = PrayerKind.Rosary, IsDefault = true };
        await _store.SaveAsync(rosary);

        var defaultAngelus = await _store.GetDefaultAsync(PrayerKind.Custom);
        var defaultRosary = await _store.GetDefaultAsync(PrayerKind.Rosary);

        Assert.NotNull(defaultAngelus);
        Assert.Equal(angelus.Id, defaultAngelus!.Id);
        Assert.NotNull(defaultRosary);
        Assert.Equal(rosary.Id, defaultRosary!.Id);
    }

    [Fact]
    public async Task SaveAsync_NewDefault_ClearsOnlyOtherFavoritesOfSameKind()
    {
        var rosary1 = new Prayer { Name = "Rosary One", Kind = PrayerKind.Rosary, IsDefault = true };
        await _store.SaveAsync(rosary1);
        var rosary2 = new Prayer { Name = "Rosary Two", Kind = PrayerKind.Rosary, IsDefault = true };
        await _store.SaveAsync(rosary2);

        var all = await _store.GetAllAsync();
        var rosaryFavorites = all.Where(p => p.Kind == PrayerKind.Rosary).ToList();

        // The seeded favorite and rosary1 should have been cleared; only rosary2 remains default.
        Assert.Single(rosaryFavorites.Where(p => p.IsDefault));
        Assert.True(rosaryFavorites.Single(p => p.Id == rosary2.Id).IsDefault);
        Assert.False(rosaryFavorites.Single(p => p.Id == rosary1.Id).IsDefault);
    }

    [Fact]
    public async Task DeleteAsync_DefaultFavorite_PromotesAnotherOfSameKind_LeavesOtherKindsAlone()
    {
        var angelus = new Prayer { Name = "My Angelus", Kind = PrayerKind.Custom, CustomDevotionId = "angelus", IsDefault = true };
        await _store.SaveAsync(angelus);

        var rosary1 = new Prayer { Name = "Rosary One", Kind = PrayerKind.Rosary, IsDefault = true };
        await _store.SaveAsync(rosary1);
        var rosary2 = new Prayer { Name = "Rosary Two", Kind = PrayerKind.Rosary, IsDefault = false };
        await _store.SaveAsync(rosary2);

        await _store.DeleteAsync(rosary1);

        var defaultRosary = await _store.GetDefaultAsync(PrayerKind.Rosary);
        Assert.NotNull(defaultRosary);
        Assert.NotEqual(rosary1.Id, defaultRosary!.Id);
        Assert.Equal(PrayerKind.Rosary, defaultRosary.Kind);

        // The Angelus favorite's default must be completely unaffected by a Rosary-kind deletion.
        var defaultAngelus = await _store.GetDefaultAsync(PrayerKind.Custom);
        Assert.NotNull(defaultAngelus);
        Assert.Equal(angelus.Id, defaultAngelus!.Id);
    }

    [Fact]
    public async Task GetDefaultAsync_NoFavoritesOfKind_ReturnsNull()
    {
        var defaultJesusPrayer = await _store.GetDefaultAsync(PrayerKind.JesusPrayer);
        Assert.Null(defaultJesusPrayer);
    }

    [Fact]
    public async Task UpdateIfPresentAsync_DeletedDefaultCannotReturnOrDemoteItsReplacement()
    {
        var deleted = new Prayer { Name = "Deleted", Kind = PrayerKind.Custom, CustomDevotionId = "angelus", IsDefault = true };
        var survivor = deleted with { Id = Guid.NewGuid(), Name = "Survivor", IsDefault = false };
        var unrelated = deleted with { Id = Guid.NewGuid(), CustomDevotionId = "trisagion" };
        await _store.SaveAsync(deleted);
        await _store.SaveAsync(survivor);
        await _store.SaveAsync(unrelated);
        await _store.DeleteAsync(deleted);

        Assert.False(await _store.UpdateIfPresentAsync(deleted with { Name = "Stale edit" }));

        Assert.Null(await _store.GetAsync(deleted.Id));
        Assert.True((await _store.GetAsync(survivor.Id))!.IsDefault);
        Assert.True((await _store.GetAsync(unrelated.Id))!.IsDefault);
    }

    [Fact]
    public async Task UpdateIfPresentAsync_ExistingDefaultChangesOnlyItsOwnDevotion()
    {
        var oldDefault = new Prayer { Name = "Old", Kind = PrayerKind.Custom, CustomDevotionId = "angelus", IsDefault = true };
        var target = oldDefault with { Id = Guid.NewGuid(), Name = "Target", IsDefault = false };
        var unrelated = oldDefault with { Id = Guid.NewGuid(), CustomDevotionId = "trisagion" };
        await _store.SaveAsync(oldDefault);
        await _store.SaveAsync(target);
        await _store.SaveAsync(unrelated);

        Assert.True(await _store.UpdateIfPresentAsync(target with { IsDefault = true, LanguageCode = "he" }));

        Assert.False((await _store.GetAsync(oldDefault.Id))!.IsDefault);
        Assert.True((await _store.GetAsync(target.Id))!.IsDefault);
        Assert.Equal("he", (await _store.GetAsync(target.Id))!.LanguageCode);
        Assert.True((await _store.GetAsync(unrelated.Id))!.IsDefault);
    }

    [Fact]
    public async Task UpdateIfPresentAsync_FailedUpdateRollsBackSiblingDefaultChanges()
    {
        var previous = new Prayer { Kind = PrayerKind.JesusPrayer, IsDefault = true };
        var target = previous with { Id = Guid.NewGuid(), Name = "Original", IsDefault = false };
        await _store.SaveAsync(previous);
        await _store.SaveAsync(target);
        using (var connection = new SQLite.SQLiteConnection(_dbPath))
            connection.Execute("CREATE TRIGGER reject_edit BEFORE UPDATE ON PresetEntry WHEN NEW.Name = 'Rejected edit' BEGIN SELECT RAISE(ABORT, 'Synthetic write failure'); END");

        await Assert.ThrowsAsync<SQLite.SQLiteException>(() => _store.UpdateIfPresentAsync(target with { Name = "Rejected edit", IsDefault = true }));

        Assert.True((await _store.GetAsync(previous.Id))!.IsDefault);
        Assert.False((await _store.GetAsync(target.Id))!.IsDefault);
        Assert.Equal("Original", (await _store.GetAsync(target.Id))!.Name);
    }

    [Fact]
    public async Task DeleteAsync_FailedPromotionRollsBackTheDeletion()
    {
        var previous = new Prayer { Kind = PrayerKind.JesusPrayer, IsDefault = true };
        var survivor = previous with { Id = Guid.NewGuid(), IsDefault = false };
        await _store.SaveAsync(previous);
        await _store.SaveAsync(survivor);
        using (var connection = new SQLite.SQLiteConnection(_dbPath))
            connection.Execute("CREATE TRIGGER reject_promotion BEFORE UPDATE OF IsDefault ON PresetEntry WHEN OLD.IsDefault = 0 AND NEW.IsDefault = 1 BEGIN SELECT RAISE(ABORT, 'Synthetic promotion failure'); END");

        await Assert.ThrowsAsync<SQLite.SQLiteException>(() => _store.DeleteAsync(previous));

        Assert.True((await _store.GetAsync(previous.Id))!.IsDefault);
        Assert.False((await _store.GetAsync(survivor.Id))!.IsDefault);
    }

    [Fact]
    public async Task GetDefaultAsync_NoneMarkedDefault_ReturnsAFavoriteOfThatKindAnyway()
    {
        var angelus = new Prayer { Name = "My Angelus", Kind = PrayerKind.Custom, CustomDevotionId = "angelus", IsDefault = false };
        await _store.SaveAsync(angelus);

        var result = await _store.GetDefaultAsync(PrayerKind.Custom);
        Assert.NotNull(result);
        Assert.Equal(angelus.Id, result!.Id);
    }

    [Fact]
    public async Task SaveAsync_RoundTripsRosaryOptionsAndReminders()
    {
        var prayer = new Prayer
        {
            Name = "Detailed Rosary",
            Kind = PrayerKind.Rosary,
            LanguageCode = "he",
            Rosary = new RosaryOptions
            {
                MysterySelectionMode = MysterySelectionMode.Specific,
                SpecificMysteryGroup = MysteryGroup.Sorrowful,
                IncludeApostlesCreed = false,
                IncludeOpeningFatimaPrayer = true,
                EternalRestForDeceased = EternalRestPlacement.AfterEachDecade,
                MarianAntiphon = MarianAntiphonOption.ReginaCaeli,
            },
            Reminders = [new PrayerReminder(7, 30), new PrayerReminder(20, 0, isEnabled: false)],
        };

        await _store.SaveAsync(prayer);
        var loaded = await _store.GetAsync(prayer.Id);

        Assert.NotNull(loaded);
        Assert.Equal(MysterySelectionMode.Specific, loaded!.Rosary.MysterySelectionMode);
        Assert.Equal(MysteryGroup.Sorrowful, loaded.Rosary.SpecificMysteryGroup);
        Assert.False(loaded.Rosary.IncludeApostlesCreed);
        Assert.True(loaded.Rosary.IncludeOpeningFatimaPrayer);
        Assert.Equal(EternalRestPlacement.AfterEachDecade, loaded.Rosary.EternalRestForDeceased);
        Assert.Equal(MarianAntiphonOption.ReginaCaeli, loaded.Rosary.MarianAntiphon);
        Assert.Equal(2, loaded.Reminders.Count);
        Assert.Contains(loaded.Reminders, r => r is { Hour: 7, Minute: 30, IsEnabled: true });
        Assert.Contains(loaded.Reminders, r => r is { Hour: 20, Minute: 0, IsEnabled: false });
    }
}
