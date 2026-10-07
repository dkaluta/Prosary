using System.Text.Json;
using Prosary.Models;
using Prosary.Persistence;
using Prosary.Services;
using Prosary.ViewModels;
using Xunit;

namespace Prosary.Tests;

public class RosarySessionNavigationTests : IClassFixture<PrayerPackLoaderFixture>
{
    private readonly LiturgicalCalendarService _calendar = new();
    public RosarySessionNavigationTests(PrayerPackLoaderFixture _) { }

    private RosaryViewModel Flow(IPresetStore presets, IPrayerRunStore runs) =>
        new(presets, new PrayerEngine(_calendar), _calendar, runs);

    private static int[] Orders(RosaryViewModel flow) => flow.NavigationSteps
        .Where(step => step.Mystery is not null).Select(step => step.Mystery!.Order).Distinct().ToArray();

    [Fact]
    public void NewModePreservesPersistedOrdinalsAndBuildsNoAutomaticStepsOrGroup()
    {
        Assert.Equal(new[] { 0, 1, 2, 3, 4, 5 }, Enum.GetValues<MysterySelectionMode>().Select(mode => (int)mode));
        var engine = new PrayerEngine(_calendar);
        var prayer = new Prayer { LanguageCode = "en", Rosary = new RosaryOptions
        {
            MysterySelectionMode = MysterySelectionMode.ChooseOnLaunch, SpecificMysteryCount = 4,
        } };
        Assert.Empty(engine.BuildSteps(prayer));
        Assert.Empty(engine.ResolveMysteryGroups(prayer));
        Assert.EndsWith("|launch-count:4", PrayerRunSignatures.Rosary(prayer.Rosary));
        Assert.EndsWith("|launch-count:1", PrayerRunSignatures.Rosary(prayer.Rosary with { SpecificMysteryCount = 0 }));
        Assert.EndsWith("|launch-count:5", PrayerRunSignatures.Rosary(prayer.Rosary with { SpecificMysteryCount = 99 }));
    }

    [Fact]
    public async Task FirstChoiceStartsWithConfiguredOpeningAndLaterChoicesPreserveOriginalRange()
    {
        var original = new Prayer { LanguageCode = "en", Rosary = new RosaryOptions
        {
            MysterySelectionMode = MysterySelectionMode.ChooseOnLaunch, SpecificMysteryCount = 3,
        } };
        var presets = new MemoryPresets(original);
        var runs = new MemoryRuns();
        var flow = Flow(presets, runs);
        await flow.LoadAsync(original.Id);
        Assert.True(flow.RequiresMysteryChoice);
        Assert.Empty(flow.NavigationSteps);
        Assert.False(flow.NextCommand.CanExecute(null));
        flow.NextCommand.Execute(null);
        Assert.Empty(flow.NavigationSteps);

        flow.ChooseMystery(MysteryGroup.Luminous, 3);
        Assert.False(flow.RequiresMysteryChoice);
        Assert.Equal(new[] { 3, 4, 5 }, Orders(flow));
        Assert.Equal(1d / flow.NavigationSteps.Count, flow.Progress);
        Assert.Equal(flow.NavigationSteps[0].Body, flow.SpeechBody);

        var steps = flow.NavigationSteps;
        flow.ChooseMystery(MysteryGroup.Luminous, 4);
        Assert.Same(steps, flow.NavigationSteps);
        var index = Enumerable.Range(0, steps.Count).First(i => steps[i].Mystery?.Order == 4);
        Assert.Equal((index + 1d) / steps.Count, flow.Progress);

        flow.ChooseMystery(MysteryGroup.Joyful, 4);
        Assert.Equal(new[] { 4, 5 }, Orders(flow));
        Assert.Equal("joyful", runs.State?.RosaryNavigationGroup);
        Assert.Equal(4, runs.State?.RosaryNavigationOrder);
        flow.ChooseMystery(MysteryGroup.Sorrowful, 1);
        Assert.Equal(new[] { 1, 2, 3 }, Orders(flow));
        Assert.Equal(original, presets.Saved);
    }

    [Fact]
    public async Task EntireSetStartsAllFiveFromOpeningAndResumesWithGroupOnlyMetadata()
    {
        var original = new Prayer { LanguageCode = "en", Rosary = new RosaryOptions
        {
            MysterySelectionMode = MysterySelectionMode.ChooseOnLaunch, SpecificMysteryCount = 2,
        } };
        var options = original.Rosary.NavigationOptions(MysteryGroup.Luminous, null);
        Assert.Equal(MysterySelectionMode.Specific, options.MysterySelectionMode);
        Assert.Equal(1, options.SpecificMysteryOrder);
        Assert.Equal(2, options.SpecificMysteryCount);
        var presets = new MemoryPresets(original);
        var runs = new MemoryRuns();
        var flow = Flow(presets, runs);
        await flow.LoadAsync(original.Id);
        flow.ChooseMystery(MysteryGroup.Luminous, null);
        Assert.False(flow.RequiresMysteryChoice);
        Assert.Equal(new[] { 1, 2, 3, 4, 5 }, Orders(flow));
        Assert.Equal(1d / flow.NavigationSteps.Count, flow.Progress);
        flow.NextCommand.Execute(null);
        var progress = flow.Progress;
        Assert.Equal("luminous", runs.State!.RosaryNavigationGroup);
        Assert.Null(runs.State.RosaryNavigationOrder);
        Assert.EndsWith("|navigation-group:luminous", runs.State.ConfigurationSignature);
        Assert.DoesNotContain("navigation-order:", runs.State.ConfigurationSignature);
        var reopened = Flow(presets, runs);
        await reopened.LoadAsync(original.Id);
        Assert.True(reopened.HasSavedContinuation);
        reopened.ContinueSavedRun();
        Assert.Equal(new[] { 1, 2, 3, 4, 5 }, Orders(reopened));
        Assert.Equal(progress, reopened.Progress);
        Assert.Equal(original, presets.Saved);
        // A later individual choice still uses the original requested count, not the whole-set run.
        reopened.ChooseMystery(MysteryGroup.Joyful, 4);
        Assert.Equal(new[] { 4, 5 }, Orders(reopened));
        reopened.RestartRun();
        Assert.True(reopened.RequiresMysteryChoice);
        Assert.Empty(reopened.NavigationSteps);
    }

    [Fact]
    public async Task WholeSetChoiceOverridesSingleModeWithoutChangingItsSavedStartOrCount()
    {
        var original = new Prayer { LanguageCode = "en", Rosary = new RosaryOptions
        {
            MysterySelectionMode = MysterySelectionMode.SingleMystery, SpecificMysteryGroup = MysteryGroup.Sorrowful,
            SpecificMysteryOrder = 3, SpecificMysteryCount = 2,
        } };
        var presets = new MemoryPresets(original);
        var runs = new MemoryRuns();
        var flow = Flow(presets, runs);
        await flow.LoadAsync(original.Id);
        flow.ChooseMystery(MysteryGroup.Sorrowful, null);
        Assert.Equal(new[] { 1, 2, 3, 4, 5 }, Orders(flow));
        var first = Enumerable.Range(0, flow.NavigationSteps.Count).First(index => flow.NavigationSteps[index].Mystery?.Order == 1);
        Assert.Equal((first + 1d) / flow.NavigationSteps.Count, flow.Progress);
        Assert.Equal(original, presets.Saved);
        Assert.True(RosarySessionNavigation.TryRestore(original.Rosary, runs.State!, out var restored, out var group, out var order));
        Assert.Equal(MysterySelectionMode.Specific, restored.MysterySelectionMode);
        Assert.Equal(MysteryGroup.Sorrowful, group);
        Assert.Null(order);
    }

    [Fact]
    public async Task ResumeReconstructsSessionRangeBeforeCheckingPositionAndRestartAsksAgain()
    {
        var original = new Prayer { LanguageCode = "en", Rosary = new RosaryOptions
        {
            MysterySelectionMode = MysterySelectionMode.ChooseOnLaunch, SpecificMysteryCount = 3,
        } };
        var presets = new MemoryPresets(original);
        var runs = new MemoryRuns();
        var flow = Flow(presets, runs);
        await flow.LoadAsync(original.Id);
        flow.ChooseMystery(MysteryGroup.Glorious, 4);
        for (var i = 0; i < 10; i++) flow.NextCommand.Execute(null);
        var progress = flow.Progress;
        Assert.EndsWith("|navigation-group:glorious|navigation-order:4", runs.State!.ConfigurationSignature);
        var reopened = Flow(presets, runs);
        await reopened.LoadAsync(original.Id);
        Assert.True(reopened.HasSavedContinuation);
        reopened.ContinueSavedRun();
        Assert.Equal(progress, reopened.Progress);
        Assert.Equal(new[] { 4, 5 }, Orders(reopened));
        Assert.Equal(original, presets.Saved);
        reopened.RestartRun();
        Assert.True(reopened.RequiresMysteryChoice);
        Assert.Empty(reopened.NavigationSteps);
        Assert.Null(runs.State);
    }

    [Fact]
    public async Task ChangedSavedConfigurationOrInvalidPositionCannotReuseChosenMysteries()
    {
        var original = new Prayer { LanguageCode = "en", Rosary = new RosaryOptions
        {
            MysterySelectionMode = MysterySelectionMode.ChooseOnLaunch, SpecificMysteryCount = 3,
        } };
        var presets = new MemoryPresets(original);
        var runs = new MemoryRuns();
        var flow = Flow(presets, runs);
        await flow.LoadAsync(original.Id);
        flow.ChooseMystery(MysteryGroup.Joyful, 2);
        flow.NextCommand.Execute(null);
        var saved = runs.State!;
        presets.Saved = original with { Rosary = original.Rosary with { SpecificMysteryCount = 4 } };
        var changed = Flow(presets, runs);
        await changed.LoadAsync(original.Id);
        Assert.False(changed.HasSavedContinuation);
        Assert.True(changed.RequiresMysteryChoice);
        Assert.Empty(changed.NavigationSteps);
        Assert.Null(runs.State);
        presets.Saved = original;
        runs.State = saved with { Position = int.MaxValue };
        var outOfBounds = Flow(presets, runs);
        await outOfBounds.LoadAsync(original.Id);
        Assert.True(outOfBounds.RequiresMysteryChoice);
        Assert.False(outOfBounds.HasSavedContinuation);
        Assert.Empty(outOfBounds.NavigationSteps);
    }

    [Fact]
    public async Task LanguageChangeUpdatesOnlyCurrentSavedLanguageAndLeavesTemporarySelectionInSession()
    {
        var original = new Prayer { LanguageCode = "en", Rosary = new RosaryOptions
        {
            MysterySelectionMode = MysterySelectionMode.ChooseOnLaunch, SpecificMysteryCount = 2,
        } };
        var presets = new MemoryPresets(original);
        var flow = Flow(presets, new MemoryRuns());
        await flow.LoadAsync(original.Id);
        flow.ChooseMystery(MysteryGroup.Luminous, 4);
        var newestOptions = new RosaryOptions { MysterySelectionMode = MysterySelectionMode.Specific,
            SpecificMysteryGroup = MysteryGroup.Sorrowful, IncludeFatimaPrayer = false };
        presets.Saved = original with { Name = "Edited while praying", Rosary = newestOptions };
        await flow.SelectLanguageAsync("he");
        Assert.Equal("he", presets.Saved.LanguageCode);
        Assert.Equal("Edited while praying", presets.Saved.Name);
        Assert.Equal(newestOptions, presets.Saved.Rosary);
        Assert.Equal(new[] { 4, 5 }, Orders(flow));
        Assert.All(flow.NavigationSteps.Where(step => step.Mystery is not null),
            step => Assert.Equal(MysteryGroup.Luminous, step.Mystery!.Group));
    }

    [Fact]
    public async Task OtherSavedModesNavigateToAFullGroupWithoutChangingTheirSavedSet()
    {
        var original = new Prayer { LanguageCode = "en", Rosary = new RosaryOptions
        {
            MysterySelectionMode = MysterySelectionMode.Specific, SpecificMysteryGroup = MysteryGroup.Joyful,
        } };
        var presets = new MemoryPresets(original);
        var flow = Flow(presets, new MemoryRuns());
        await flow.LoadAsync(original.Id);
        flow.ChooseMystery(MysteryGroup.Glorious, 3);
        Assert.Equal(new[] { 1, 2, 3, 4, 5 }, Orders(flow));
        Assert.All(flow.NavigationSteps.Where(step => step.Mystery is not null),
            step => Assert.Equal(MysteryGroup.Glorious, step.Mystery!.Group));
        Assert.Equal(original, presets.Saved);
    }

    [Theory]
    [InlineData("Joyful", 3)]
    [InlineData("unknown", 3)]
    [InlineData("0", 3)]
    [InlineData("joyful", 0)]
    [InlineData("joyful", 6)]
    [InlineData(null, 3)]
    public void InvalidRawChoiceNeverFallsBackToAnAutomaticGroup(string? group, int? order)
    {
        var original = new RosaryOptions { MysterySelectionMode = MysterySelectionMode.ChooseOnLaunch };
        var saved = new PrayerRunState(RosarySessionNavigation.Signature(original, MysteryGroup.Joyful, 3),
            1, "en", PrayerRunState.LocalDateString(DateOnly.FromDateTime(DateTime.Today)), group, order);
        Assert.False(RosarySessionNavigation.TryRestore(original, saved, out _, out _, out _));
    }

    [Fact]
    public void OlderCheckpointsDecodeWithNoChoiceFieldsAndKeepTheirOriginalSignatureGate()
    {
        var raw = """{"configurationSignature":"legacy","position":1,"languageCode":"en","savedLocalDate":"2026-10-07"}""";
        var saved = JsonSerializer.Deserialize<PrayerRunState>(raw, new JsonSerializerOptions(JsonSerializerDefaults.Web))!;
        Assert.Null(saved.RosaryNavigationGroup);
        Assert.Null(saved.RosaryNavigationOrder);
        var options = new RosaryOptions();
        Assert.True(RosarySessionNavigation.TryRestore(options, saved with
        {
            ConfigurationSignature = PrayerRunSignatures.Rosary(options),
        }, out var restored, out var group, out var order));
        Assert.Equal(options, restored);
        Assert.Null(group);
        Assert.Null(order);
    }

    [Fact]
    public async Task ChooseOnLaunchEditorsExposeFullCountWithoutSavedSetOrStartingMysteryControls()
    {
        var original = new Prayer { IsDefault = true, Rosary = new RosaryOptions
        {
            MysterySelectionMode = MysterySelectionMode.ChooseOnLaunch, SpecificMysteryOrder = 5,
            SpecificMysteryCount = 4,
        } };
        var presets = new MemoryPresets(original);
        var editor = new FavoriteEditorViewModel(presets, new SilentReminders());
        await editor.LoadAsync(original.Id, PrayerKind.Rosary);
        Assert.True(editor.ShowsMysteryCount);
        Assert.False(editor.IsSpecificMysteryGroup);
        Assert.False(editor.IsSingleMystery);
        Assert.Equal(new[] { 1, 2, 3, 4, 5 }, editor.MysteryCountOptions);
        Assert.Equal(4, editor.SpecificMysteryCount);
        var picker = new RosaryPresetPickerViewModel(presets);
        await picker.LoadAsync();
        Assert.True(picker.ShowsMysteryCount);
        Assert.False(picker.ShowsGroupPicker);
        Assert.False(picker.ShowsOrdinalPicker);
        Assert.Equal(new[] { 1, 2, 3, 4, 5 }, picker.MysteryCountOptions);
        Assert.Equal(4, picker.AdHocPrayer().Rosary.SpecificMysteryCount);
    }

    private sealed class MemoryRuns : IPrayerRunStore
    {
        public PrayerRunState? State { get; set; }
        public PrayerRunState? Get(string key) => State;
        public void Save(string key, PrayerRunState state) => State = state;
        public void Remove(string key) => State = null;
    }

    private sealed class MemoryPresets(Prayer original) : IPresetStore
    {
        public Prayer Saved { get; set; } = original;
        public Task<List<Prayer>> GetAllAsync() => Task.FromResult(new List<Prayer> { Saved });
        public Task<Prayer?> GetDefaultAsync(PrayerKind kind) => Task.FromResult<Prayer?>(Saved);
        public Task<Prayer?> GetAsync(Guid id) => Task.FromResult<Prayer?>(Saved.Id == id ? Saved : null);
        public Task SaveAsync(Prayer prayer) { Saved = prayer; return Task.CompletedTask; }
        public Task<bool> UpdateIfPresentAsync(Prayer prayer)
        {
            if (prayer.Id != Saved.Id) return Task.FromResult(false);
            Saved = prayer;
            return Task.FromResult(true);
        }
        public Task DeleteAsync(Prayer prayer) => Task.CompletedTask;
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
