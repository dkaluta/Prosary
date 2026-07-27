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
        if (File.Exists(_dbPath))
        {
            File.Delete(_dbPath);
        }
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
        Assert.Equal(EternalRestPlacement.AfterEachDecade, loaded.Rosary.EternalRestForDeceased);
        Assert.Equal(MarianAntiphonOption.ReginaCaeli, loaded.Rosary.MarianAntiphon);
        Assert.Equal(2, loaded.Reminders.Count);
        Assert.Contains(loaded.Reminders, r => r is { Hour: 7, Minute: 30, IsEnabled: true });
        Assert.Contains(loaded.Reminders, r => r is { Hour: 20, Minute: 0, IsEnabled: false });
    }
}
