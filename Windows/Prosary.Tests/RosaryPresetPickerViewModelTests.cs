using Prosary.Localization;
using Prosary.Models;
using Prosary.Persistence;
using Prosary.Services;
using Prosary.ViewModels;
using Xunit;

namespace Prosary.Tests;

public class RosaryPresetPickerViewModelTests : IClassFixture<PrayerPackLoaderFixture>
{
    [Theory]
    [InlineData("he", "he-x-gamliel")]
    [InlineData("he-x-gamliel", "he")]
    public async Task HebrewOptionCaptionsRefreshWhenTheEditorChangesTradition(string first, string second)
    {
        var oldUi = UiLanguageCatalog.Current;
        try
        {
            UiLanguageCatalog.UseLanguageForCurrentSession("he");
            var original = new Prayer { Kind = PrayerKind.Rosary, LanguageCode = first, IsDefault = true };
            var store = new MemoryPresetStore(original);
            var picker = new RosaryPresetPickerViewModel(store);
            await picker.LoadAsync();
            var editor = new FavoriteEditorViewModel(store, new SilentReminders());
            await editor.LoadAsync(original.Id, PrayerKind.Rosary);
            Assert.Equal(RosaryOptionLabels.OpeningPrayers(first), editor.OpeningPrayersLabel);
            Assert.Equal(editor.OpeningPrayersLabel, picker.OpeningPrayersLabel);
            Assert.Equal(editor.OpeningFatimaLabel, picker.OpeningFatimaLabel);
            Assert.Equal(editor.CreedLabel, picker.CreedLabel);

            var changed = new List<string?>();
            editor.PropertyChanged += (_, args) => changed.Add(args.PropertyName);
            editor.LanguageCode = second;
            Assert.Contains(nameof(editor.OpeningPrayersLabel), changed);
            Assert.Contains(nameof(editor.OpeningFatimaLabel), changed);
            Assert.Contains(nameof(editor.PresenterHint), changed);
            Assert.Contains(nameof(editor.CreedLabel), changed);
            Assert.Equal(RosaryOptionLabels.OpeningPrayers(second), editor.OpeningPrayersLabel);
            Assert.Equal(RosaryOptionLabels.OpeningFatima(second), editor.OpeningFatimaLabel);
            Assert.Equal(RosaryOptionLabels.PresenterHint(second), editor.PresenterHint);

            var generic = original with { Kind = PrayerKind.Custom, CustomDevotionId = "rosary" };
            var genericEditor = new RemindersOnlyEditorViewModel(new MemoryPresetStore(generic), new SilentReminders());
            await genericEditor.LoadAsync(generic.Id);
            Assert.Equal(picker.OpeningPrayersLabel, genericEditor.OptionRows.Single(row => row.Key == "openingPrayers").Label);
            Assert.Equal(picker.OpeningFatimaLabel, genericEditor.OptionRows.Single(row => row.Key == "openingFatimaPrayer").Label);
            var antiphon = genericEditor.OptionRows.Single(row => row.Key == "antiphon");
            Assert.Equal(PrayerPackStore.ResolveDisplayText("rosary", first, "subTuumPraesidiumTitle"),
                antiphon.Cases.Single(choice => choice.Id == "subTuumPraesidium").LocalizedName);
        }
        finally { UiLanguageCatalog.UseLanguageForCurrentSession(oldUi); }
    }

    [Fact]
    public async Task AdHocPrayerForNavigation_ReusesInstanceUntilPickerReloads()
    {
        var viewModel = new RosaryPresetPickerViewModel(new MemoryPresetStore());
        await viewModel.LoadAsync();

        var firstActivation = viewModel.AdHocPrayerForNavigation();
        var pairedActivation = viewModel.AdHocPrayerForNavigation();

        Assert.Same(firstActivation, pairedActivation);

        await viewModel.LoadAsync();
        var laterVisit = viewModel.AdHocPrayerForNavigation();

        Assert.NotSame(firstActivation, laterVisit);
        Assert.NotEqual(firstActivation.Id, laterVisit.Id);
    }

    [Theory]
    [InlineData("arc", true)]
    [InlineData("he-x-gamliel", true)]
    [InlineData("uk", true)]
    [InlineData("el", true)]
    [InlineData("la", false)]
    [InlineData("he", false)]
    [InlineData("en", false)]
    public async Task CreedOptionNamesItsAuthoredSourceAndKeepsTheInclusionChoice(string language, bool nicene)
    {
        var original = new Prayer
        {
            Kind = PrayerKind.Rosary, LanguageCode = language, IsDefault = true,
            Rosary = new RosaryOptions { IncludeApostlesCreed = false },
        };
        var store = new MemoryPresetStore(original);
        var picker = new RosaryPresetPickerViewModel(store);
        await picker.LoadAsync();
        Assert.Equal(nicene ? Loc.Tr("favorite_editor_nicene_creed", "Nicene Creed")
            : Loc.Tr("PickerApostlesCreed.Text", "Apostles' Creed"), picker.CreedLabel);
        Assert.False(picker.IncludeApostlesCreed);
        var editor = new FavoriteEditorViewModel(store, new SilentReminders());
        await editor.LoadAsync(original.Id, PrayerKind.Rosary);
        Assert.Equal(nicene ? Loc.Tr("favorite_editor_nicene_creed", "Nicene Creed")
            : Loc.Tr("EdApostlesCreed.Text", "Apostles' Creed"), editor.CreedLabel);
        var changed = new List<string?>();
        editor.PropertyChanged += (_, change) => changed.Add(change.PropertyName);
        editor.LanguageCode = nicene ? "la" : "arc";
        Assert.Contains(nameof(editor.CreedLabel), changed);
        Assert.False(editor.IncludeApostlesCreed);
        Assert.Equal(nicene ? Loc.Tr("EdApostlesCreed.Text", "Apostles' Creed")
            : Loc.Tr("favorite_editor_nicene_creed", "Nicene Creed"), editor.CreedLabel);

        var generic = original with { Kind = PrayerKind.Custom, CustomDevotionId = "rosary",
            CustomOptions = new Dictionary<string, string> { ["apostlesCreed"] = "false" } };
        var genericEditor = new RemindersOnlyEditorViewModel(new MemoryPresetStore(generic), new SilentReminders());
        await genericEditor.LoadAsync(generic.Id);
        var row = Assert.Single(genericEditor.OptionRows, option => option.Key == "apostlesCreed");
        Assert.Equal(nicene ? Loc.Tr("favorite_editor_nicene_creed", "Nicene Creed")
            : PrayerPackStore.Options("rosary").Single(option => option.Key == "apostlesCreed").LocalizedName, row.Label);
        Assert.Equal("false", row.Value);
    }

    [Fact]
    public async Task EnglishCreedOptionKeepsItsOwnPolicyWhenSeparateNiceneFallsBackToSyriac()
    {
        var previous = AppSettings.LanguageFallbackOrder.ToArray();
        try
        {
            AppSettings.SetLanguageFallbackOrder(["arc", "he", "la"]);
            var original = new Prayer { Kind = PrayerKind.Rosary, LanguageCode = "en", IsDefault = true };
            var picker = new RosaryPresetPickerViewModel(new MemoryPresetStore(original));
            await picker.LoadAsync();
            Assert.Contains("[ובא]", PrayerPackStore.ResolveBodyText("rosary", "en", "symbolumNicaenum"));
            Assert.Equal(Loc.Tr("PickerApostlesCreed.Text", "Apostles' Creed"), picker.CreedLabel);
        }
        finally { AppSettings.SetLanguageFallbackOrder(previous); }
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task CombinedClosingControlLoadsOldSelectionsAndClearsOverridesWhenSaved(bool enabled)
    {
        var original = new Prayer
        {
            Kind = PrayerKind.Rosary,
            Name = "Legacy partial intentions",
            IsDefault = true,
            Rosary = new RosaryOptions { IncludeClosingBishopIntention = true },
        };
        var store = new MemoryPresetStore(original);
        var picker = new RosaryPresetPickerViewModel(store);
        await picker.LoadAsync();
        Assert.True(picker.IncludeClosingIntentions);
        picker.IncludeClosingIntentions = enabled;
        AssertCombinedChoice(picker.AdHocPrayer().Rosary, enabled);
        Assert.Equal(original, store.Saved);

        var editor = new FavoriteEditorViewModel(store, new SilentReminders());
        await editor.LoadAsync(original.Id, PrayerKind.Rosary);
        Assert.True(editor.IncludeClosingIntentions);
        editor.IncludeClosingIntentions = enabled;
        await editor.SaveCommand.ExecuteAsync(null);
        AssertCombinedChoice(store.Saved!.Rosary, enabled);
    }

    private static void AssertCombinedChoice(RosaryOptions options, bool enabled)
    {
        Assert.Equal(enabled, options.IncludeClosingIntentions);
        Assert.Equal(enabled, options.EffectiveClosingIntentions);
        Assert.Null(options.IncludeClosingPopeIntention);
        Assert.Null(options.IncludeClosingBishopIntention);
        Assert.Null(options.IncludeClosingDepartedIntention);
    }

    private sealed class MemoryPresetStore(Prayer? initial = null) : IPresetStore
    {
        public Prayer? Saved { get; private set; } = initial;
        public Task<List<Prayer>> GetAllAsync() => Task.FromResult(Saved is { } prayer ? new List<Prayer> { prayer } : []);
        public Task<Prayer?> GetDefaultAsync(PrayerKind kind) => Task.FromResult(Saved?.Kind == kind ? Saved : null);
        public Task<Prayer?> GetAsync(Guid id) => Task.FromResult(Saved?.Id == id ? Saved : null);
        public Task SaveAsync(Prayer prayer) { Saved = prayer; return Task.CompletedTask; }
        public Task<bool> UpdateIfPresentAsync(Prayer prayer)
        {
            if (Saved?.Id != prayer.Id) return Task.FromResult(false);
            Saved = prayer;
            return Task.FromResult(true);
        }
        public Task DeleteAsync(Prayer prayer) { Saved = null; return Task.CompletedTask; }
    }

    private sealed class SilentReminders : IReminderScheduler
    {
        public Task<bool> RequestPermissionAsync() => Task.FromResult(true);
        public void Schedule(Prayer prayer) { }
        public void RemoveAll(Prayer prayer) { }
        public void RescheduleAll(IEnumerable<Prayer> prayers) { }
        public void RefreshSeries(string devotionId) { }
    }
}
