using Prosary.Models;
using Prosary.Persistence;
using Prosary.Services;
using Prosary.ViewModels;
using Xunit;

namespace Prosary.Tests;

public class PrayerRunStateTests : IClassFixture<PrayerPackLoaderFixture>
{
    public PrayerRunStateTests(PrayerPackLoaderFixture _)
    {
    }

    [Fact]
    public void ResumeRequiresAnUnfinishedMatchingPosition()
    {
        var today = new DateOnly(2026, 9, 3);
        var saved = new PrayerRunState("same", 4, "he", "2026-09-03");
        var atStart = saved with { Position = 0 };
        var finished = saved with { Position = 10 };

        Assert.True(saved.CanResume("same", 10, sameLocalDayOnly: false, today));
        Assert.False(atStart.CanResume("same", 10, false, today));
        Assert.False(finished.CanResume("same", 10, false, today));
        Assert.False(saved.CanResume("different", 10, false, today));
    }

    [Fact]
    public void OnlyRosaryStyleSameDayResumeExpiresAtLocalMidnight()
    {
        var today = new DateOnly(2026, 9, 3);
        var yesterday = new PrayerRunState("rosary", 4, "arc", "2026-09-02");

        Assert.False(yesterday.CanResume("rosary", 10, sameLocalDayOnly: true, today));
        Assert.True(yesterday.CanResume("rosary", 10, sameLocalDayOnly: false, today));
        Assert.True((yesterday with { SavedLocalDate = "2026-09-03" })
            .CanResume("rosary", 10, sameLocalDayOnly: true, today));
    }

    [Fact]
    public void LocalStoreRoundTripsLanguageAndRemovesCheckpoint()
    {
        string? json = null;
        var store = new LocalPrayerRunStore(() => json, value => json = value);
        var state = new PrayerRunState("signature", 7, "he-x-gamliel", "2026-09-03");

        store.Save("rosary:one", state);
        Assert.Equal(state, store.Get("rosary:one"));

        store.Remove("rosary:one");
        Assert.Null(store.Get("rosary:one"));
    }

    [Fact]
    public void RunKeysKeepCustomFormsAndSavedCountersIndependent()
    {
        var first = Guid.Parse("11111111-1111-1111-1111-111111111111");
        var second = Guid.Parse("22222222-2222-2222-2222-222222222222");

        Assert.NotEqual(
            PrayerRunKeys.Custom("stations", "traditional", 0),
            PrayerRunKeys.Custom("stations", "scriptural", 0));
        Assert.NotEqual(
            PrayerRunKeys.Custom("novena", null, 0),
            PrayerRunKeys.Custom("novena", null, 1));
        Assert.NotEqual(
            PrayerRunKeys.Jesus(first, new JesusPrayerTarget.Count(33)),
            PrayerRunKeys.Jesus(second, new JesusPrayerTarget.Count(33)));
        Assert.Equal("jesus:33", PrayerRunKeys.Jesus(null, new JesusPrayerTarget.Count(33)));
        Assert.Equal("jesus:unbounded", PrayerRunKeys.Jesus(null, new JesusPrayerTarget.Unbounded()));
    }

    [Fact]
    public void CustomSignatureIncludesSequenceChangingOptions()
    {
        var included = PrayerRunSignatures.Custom(
            "crown", null, 0, new Dictionary<string, string> { ["extra"] = "true" });
        var omitted = PrayerRunSignatures.Custom(
            "crown", null, 0, new Dictionary<string, string> { ["extra"] = "false" });

        Assert.NotEqual(included, omitted);
    }

    [Fact]
    public void CustomSignatureIncludesTheEffectiveLanguageSelectedForm()
    {
        var ordinary = PrayerRunSignatures.Custom("trisagion", "ordinary", 0);
        var syriac = PrayerRunSignatures.Custom("trisagion", "syriac", 0);

        Assert.NotEqual(ordinary, syriac);
        Assert.Equal(7, CustomDevotionViewModel.PositionAfterLanguageSwitch("syriac", "syriac", 7));
        Assert.Equal(0, CustomDevotionViewModel.PositionAfterLanguageSwitch("ordinary", "syriac", 7));
    }

    [Fact]
    public void CorruptLocalStoreValueBehavesAsEmpty()
    {
        var store = new LocalPrayerRunStore(() => "{not json", _ => { });
        Assert.Null(store.Get("anything"));
    }

    [Fact]
    public void MysteryNavigationJumpsToFirstStepOfAdjacentMystery()
    {
        var steps = new List<RosaryStep>
        {
            new("Opening", null, ""),
            new("First announcement", null, "", DecadeIndex: 0),
            new("First prayer", null, "", DecadeIndex: 0),
            new("Second announcement", null, "", DecadeIndex: 1),
            new("Second prayer", null, "", DecadeIndex: 1),
            new("Closing", null, ""),
        };

        Assert.Equal(1, MysteryStepNavigation.Next(steps, 0));
        Assert.Equal(3, MysteryStepNavigation.Next(steps, 2));
        Assert.Equal(1, MysteryStepNavigation.Previous(steps, 3));
        Assert.Equal(1, MysteryStepNavigation.Previous(steps, 4));
        Assert.Equal(3, MysteryStepNavigation.Previous(steps, 5));
        Assert.Null(MysteryStepNavigation.Previous(steps, 1));
        Assert.Null(MysteryStepNavigation.Next(steps, 4));
    }

    [Fact]
    public async Task RosaryLanguageSwitchKeepsMysteryAndPersistsItsContinuationLanguage()
    {
        var prayer = new Prayer
        {
            Id = Guid.Parse("33333333-3333-3333-3333-333333333333"),
            Name = "Aramaic test",
            Kind = PrayerKind.Rosary,
            IsDefault = true,
            LanguageCode = "en",
            Rosary = new RosaryOptions
            {
                MysterySelectionMode = MysterySelectionMode.Specific,
                SpecificMysteryGroup = MysteryGroup.Joyful,
            },
        };
        var presets = new MemoryPresetStore(prayer);
        string? json = null;
        var runs = new LocalPrayerRunStore(() => json, value => json = value);
        var calendar = new LiturgicalCalendarService();
        var viewModel = new RosaryViewModel(
            presets, new PrayerEngine(calendar), calendar, runs);

        await viewModel.LoadAsync(prayer.Id);
        viewModel.GoToNextMysteryCommand.Execute(null);
        var mysteryProgress = viewModel.ProgressText;

        await viewModel.SelectLanguageAsync("arc");

        Assert.Equal(mysteryProgress, viewModel.ProgressText);
        Assert.Contains("— לוקא א׳ 26–38 (פשיטתא)", viewModel.Body);
        Assert.True(viewModel.HasTransliteration);
        Assert.Equal("arc", runs.Get(PrayerRunKeys.Rosary(prayer.Id))?.LanguageCode);

        viewModel.ToggleTransliterationCommand.Execute(null);
        Assert.Contains("— ܠܘܩܐ 1:26–38 (ܦܫܝܛܬܐ)", viewModel.Body);

        var reopened = new RosaryViewModel(
            presets, new PrayerEngine(calendar), calendar, runs);
        await reopened.LoadAsync(prayer.Id);
        Assert.True(reopened.HasSavedContinuation);
        reopened.ContinueSavedRun();
        Assert.Equal(mysteryProgress, reopened.ProgressText);
        Assert.Contains("— לוקא א׳ 26–38 (פשיטתא)", reopened.Body);
    }

    [Fact]
    public async Task JesusPrayerContinuesAcrossDaysAtTheSavedCount()
    {
        var presets = new MemoryPresetStore();
        string? json = null;
        var runs = new LocalPrayerRunStore(() => json, value => json = value);
        var calendar = new LiturgicalCalendarService();
        var target = new JesusPrayerTarget.Count(33);
        var viewModel = new JesusPrayerViewModel(presets, calendar, runs);

        await viewModel.LoadAsync(null, target);
        viewModel.NextCommand.Execute(null);
        viewModel.NextCommand.Execute(null);

        var key = PrayerRunKeys.Jesus(null, target);
        Assert.Equal(2, runs.Get(key)?.Position);
        var saved = runs.Get(key)!;
        runs.Save(key, saved with { SavedLocalDate = "1999-01-01" });

        var reopened = new JesusPrayerViewModel(presets, calendar, runs);
        await reopened.LoadAsync(null, target);
        Assert.True(reopened.HasSavedContinuation);
        reopened.ContinueSavedRun();
        Assert.Equal(2, reopened.RepetitionState.CurrentIndex);
    }

    private sealed class MemoryPresetStore : IPresetStore
    {
        private readonly List<Prayer> _prayers;

        public MemoryPresetStore(params Prayer[] prayers)
        {
            _prayers = [.. prayers];
        }

        public Task<List<Prayer>> GetAllAsync() => Task.FromResult(_prayers.ToList());

        public Task<Prayer?> GetDefaultAsync(PrayerKind kind) => Task.FromResult(
            _prayers.FirstOrDefault(prayer => prayer.Kind == kind && prayer.IsDefault)
            ?? _prayers.FirstOrDefault(prayer => prayer.Kind == kind));

        public Task<Prayer?> GetAsync(Guid id) =>
            Task.FromResult(_prayers.FirstOrDefault(prayer => prayer.Id == id));

        public Task SaveAsync(Prayer prayer)
        {
            var index = _prayers.FindIndex(existing => existing.Id == prayer.Id);
            if (index >= 0) _prayers[index] = prayer;
            else _prayers.Add(prayer);
            return Task.CompletedTask;
        }

        public Task DeleteAsync(Prayer prayer)
        {
            _prayers.RemoveAll(existing => existing.Id == prayer.Id);
            return Task.CompletedTask;
        }
    }
}
