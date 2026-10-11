using System.Reflection;
using Prosary.Localization;
using Prosary.Models;
using Prosary.Services;
using Prosary.ViewModels;
using Windows.Storage;
using Xunit;

namespace Prosary.Tests;

public class FilioquePrayerWordingTests : IClassFixture<PrayerPackLoaderFixture>
{
    public FilioquePrayerWordingTests(PrayerPackLoaderFixture _) { }

    [Theory]
    [InlineData("הַנּוֹבֵעַ מֵהָאָב וּמֵהַבֵּן", "הַנּוֹבֵעַ מֵהָאָב")]
    [InlineData("הַנּוֹבֵעַ מֵהָאָב וּמֵהַבֵּן", "הַנּוֹבֵעַ מֵהָאָב")]
    [InlineData("הנובע מהאב ומהבן", "הנובע מהאב")]
    [InlineData("הנובע מהאב [ומהבן]", "הנובע מהאב")]
    [InlineData("אֲשֶׁר נֶאֱצַל מִן הָאָב (וּמִן הַבֵּן)", "אֲשֶׁר נֶאֱצַל מִן הָאָב")]
    [InlineData("הַו דּמֶן אַבָא ובא ננפֶק", "הַו דּמֶן אַבָא ננפֶק")]
    [InlineData("ܗܰܘ ܕ݁ܡܶܢ ܐܰܒܳܐ ܘܒܐ ܢܢܦܶܩ", "ܗܰܘ ܕ݁ܡܶܢ ܐܰܒܳܐ ܢܢܦܶܩ")]
    [InlineData("qui ex Patre Filioque procedit", "qui ex Patre procedit")]
    public void OnlyTheSourcedClauseChangesAndOptionalParenthesesDisappear(string source, string omitted)
    {
        var body = $"before ✠ {source} after";
        var without = FilioquePrayerWording.Apply("symbolumNicaenum", body, null, false);
        Assert.Equal($"before ✠ {omitted} after", without.Text);
        Assert.Null(without.ReadingAid);
        var with = FilioquePrayerWording.Apply("symbolumNicaenum", body, null, true);
        var included = source.Replace(" (וּמִן הַבֵּן)", " וּמִן הַבֵּן").Replace(" [ומהבן]", " ומהבן");
        Assert.Equal($"before ✠ {included} after", with.Text);
        Assert.Equal(without.Text, FilioquePrayerWording.Apply("symbolumNicaenum", without.Text, null, true).Text);
    }

    [Fact]
    public void BothAramaicScriptsChangeTogetherAndTheCrossMarkStays()
    {
        var result = FilioquePrayerWording.Apply("SymbolumApostolorum",
            "הַו דּמֶן אַבָא ובא ננפֶק ✠", "ܗܰܘ ܕ݁ܡܶܢ ܐܰܒܳܐ ܘܒܐ ܢܢܦܶܩ ✠", false);
        Assert.Equal("הַו דּמֶן אַבָא ננפֶק ✠", result.Text);
        Assert.Equal("ܗܰܘ ܕ݁ܡܶܢ ܐܰܒܳܐ ܢܢܦܶܩ ✠", result.ReadingAid);
    }

    [Fact]
    public void PointedVicariateProcessionLeavesThePrintedCoWorshipClauseUntouched()
    {
        using var preference = new AppSettingsFilioqueScope(true);
        var source = PrayerPackStore.ResolveBodyText("rosary", "he", "symbolumNicaenum");
        const string included = "הַנּוֹבֵעַ מֵהָאָב וּמֵהַבֵּן";
        Assert.Contains(included, source);
        var suffix = source[(source.IndexOf(included, StringComparison.Ordinal) + included.Length)..];
        Assert.Equal(source.Replace(included, "הַנּוֹבֵעַ מֵהָאָב", StringComparison.Ordinal),
            FilioquePrayerWording.Apply("symbolumNicaenum", source, null, false).Text);
        Assert.EndsWith(suffix, FilioquePrayerWording.Apply("symbolumNicaenum", source, null, false).Text);
        Assert.Equal(source, FilioquePrayerWording.Apply("symbolumNicaenum", source, null, true).Text);
    }

    [Fact]
    public void CandidateStepCountsDoNotChooseTheFirstTradition()
    {
        using var preference = new AppSettingsFilioqueScope(null);
        var engine = new PrayerEngine(new LiturgicalCalendarService());
        var greek = new Prayer { LanguageCode = "el" };
        var candidate = engine.BuildSteps(greek, initializeFilioque: false);
        Assert.NotEmpty(candidate);
        Assert.Contains(candidate, step => step.Body.Contains("τὸ ἐκ τοῦ Πατρὸς ἐκπορευόμενον", StringComparison.Ordinal));
        Assert.Null(AppSettings.IncludeFilioquePreference);
        BasicPrayerCatalog.Step(BasicPrayerCatalog.Prayer("niceneCreed")!, "he");
        Assert.True(AppSettings.IncludeFilioquePreference);
        Assert.Equal(candidate.Count, engine.BuildSteps(greek).Count);
        Assert.True(AppSettings.IncludeFilioquePreference);
    }

    [Fact]
    public void NestedCandidateScopesDoNotPersistAndRestoreInitializationAfterAnException()
    {
        using var state = new AppSettingsFilioqueScope(null);
        Assert.Throws<InvalidOperationException>(() => AppSettings.WithoutFilioqueInitialization<string>(() =>
        {
            var primary = AppSettings.WithoutFilioqueInitialization(() =>
                FilioquePrayerWording.Apply("symbolumNicaenum", "הַנּוֹבֵעַ מֵהָאָב וּמֵהַבֵּן", null).Text);
            Assert.Contains("וּמֵהַבֵּן", primary);
            Assert.Null(AppSettings.IncludeFilioquePreference);
            throw new InvalidOperationException("candidate rejected");
        }));
        Assert.Null(AppSettings.IncludeFilioquePreference);
        FilioquePrayerWording.Apply("symbolumApostolorum", "τὸ ἐκ τοῦ Πατρὸς ἐκπορευόμενον", null);
        Assert.False(AppSettings.IncludeFilioquePreference);
    }

    [Theory]
    [InlineData("symbolumApostolorum", "I believe in God, the Father almighty.")]
    [InlineData("symbolumNicaenum", "τὸ ἐκ τοῦ Πατρὸς ἐκπορευόμενον")]
    [InlineData("unrelatedPrayer", "qui ex Patre Filioque procedit")]
    [InlineData("symbolumNicaenum", "An unfamiliar authored creed.")]
    public void OrdinaryApostlesGreekAndUnknownWordingRemainUntouched(string key, string source)
    {
        foreach (var included in new[] { true, false })
        {
            var result = FilioquePrayerWording.Apply(key, source, "unchanged aid", included);
            Assert.Equal(source, result.Text);
            Assert.Equal("unchanged aid", result.ReadingAid);
        }
    }

    [Fact]
    public void FirstExplicitLanguageChoicePersistsUntilTheUserChangesTheToggle()
    {
        using var state = new AppSettingsFilioqueScope(null);
        AppSettings.InitializeFilioqueForLanguage("");
        Assert.Null(AppSettings.IncludeFilioquePreference);
        AppSettings.InitializeFilioqueForLanguage("el");
        Assert.False(AppSettings.IncludeFilioque);
        AppSettings.InitializeFilioqueForLanguage("he-x-gamliel");
        Assert.False(AppSettings.IncludeFilioque);
        AppSettings.SetIncludeFilioque(true);
        AppSettings.InitializeFilioqueForLanguage("el");
        Assert.True(AppSettings.IncludeFilioque);
        state.AssertStoredValue(true);
    }

    [Fact]
    public void OpeningSettingsDoesNotPickATraditionButAnExplicitPickerChoiceDoes()
    {
        using var state = new AppSettingsFilioqueScope(null);
        var previousLanguage = AppSettings.PrayerLanguageCode;
        try
        {
            var settings = new SettingsViewModel(initialAudioCacheBytes: 0);
            Assert.Null(AppSettings.IncludeFilioquePreference);
            // Choose a different entry first so the generated property does fire when Greek
            // was already selected before this test.
            settings.SelectedLanguage = settings.LanguageOptions.First(option => option.Code == "");
            settings.SelectedLanguage = settings.LanguageOptions.First(option => option.Code == "el");
            Assert.False(settings.IncludeFilioque);
            Assert.False(AppSettings.IncludeFilioque);
            settings.IncludeFilioque = true;
            settings.SelectedLanguage = settings.LanguageOptions.First(option => option.Code == "he");
            Assert.True(settings.IncludeFilioque);
            state.AssertStoredValue(true);
        }
        finally { AppSettings.SetDefaultLanguageCode(previousLanguage); }
    }

    [Fact]
    public void WinningCreedSourceInitializesThePreferenceAfterFallback()
    {
        using var state = new AppSettingsFilioqueScope(null);
        var previousOrder = AppSettings.LanguageFallbackOrder.ToArray();
        try
        {
            AppSettings.SetLanguageFallbackOrder(["he", "el", "la"]);
            var text = PrayerPackStore.ResolveBodyText("rosary", "en", "symbolumNicaenum");
            Assert.Contains("הַנּוֹבֵעַ מֵהָאָב וּמֵהַבֵּן", text);
            Assert.True(AppSettings.IncludeFilioque);
            // Switching the requested language cannot reset the already initialized choice.
            Assert.Contains("τὸ ἐκ τοῦ Πατρὸς ἐκπορευόμενον",
                PrayerPackStore.ResolveBodyText("rosary", "el", "symbolumNicaenum"));
            Assert.True(AppSettings.IncludeFilioque);
        }
        finally { AppSettings.SetLanguageFallbackOrder(previousOrder); }
    }

    [Fact]
    public void FallbackKeepsTheWinningBodyReadingAidPair()
    {
        using var state = new AppSettingsFilioqueScope(false);
        var previousOrder = AppSettings.LanguageFallbackOrder.ToArray();
        try
        {
            AppSettings.SetLanguageFallbackOrder(["arc", "he", "la"]);
            var body = PrayerPackStore.ResolveBodyText("rosary", "en", "symbolumNicaenum");
            var aid = PrayerPackStore.Transliteration("rosary", "en", "symbolumNicaenum");
            Assert.Contains("הַו דּמֶן אַבָא ננפֶק", body);
            Assert.DoesNotContain("הַו דּמֶן אַבָא ובא ננפֶק", body);
            Assert.Contains("ܗܰܘ ܕ݁ܡܶܢ ܐܰܒܳܐ ܢܢܦܶܩ", aid!);
            AppSettings.SetLanguageFallbackOrder(["he", "arc", "la"]);
            Assert.Contains("הַנּוֹבֵעַ מֵהָאָב", PrayerPackStore.ResolveBodyText("rosary", "en", "symbolumNicaenum"));
            Assert.Null(PrayerPackStore.Transliteration("rosary", "en", "symbolumNicaenum"));
        }
        finally { AppSettings.SetLanguageFallbackOrder(previousOrder); }
    }

    [Fact]
    public void NiceneCreedIsASeparateBasicPrayerAndRefreshKeepsItsReadingScript()
    {
        using var state = new AppSettingsFilioqueScope(true);
        var prayer = Assert.Single(BasicPrayerCatalog.All, prayer => prayer.Id == "niceneCreed");
        Assert.Equal("symbolumNicaenum", prayer.BodyKey);
        Assert.Equal("symbolumNicaenumTitle", prayer.TitleKey);
        Assert.Equal("rosary", prayer.BundleId);
        Assert.Equal("crucifix", prayer.ImageKey);
        Assert.Equal(BasicPrayerCatalog.All.ToList().FindIndex(prayer => prayer.Id == "creed") + 1,
            BasicPrayerCatalog.All.ToList().FindIndex(prayer => prayer.Id == "niceneCreed"));
        var previousLanguage = AppSettings.BasicPrayersLanguageCode;
        var previousScript = AppSettings.AramaicDefaultScript;
        try
        {
            AppSettings.SetBasicPrayersLanguageCode("arc");
            AppSettings.SetAramaicDefaultScript("Syrc");
            var flow = new BasicPrayerViewModel();
            flow.Load(prayer.Id);
            Assert.Contains("ܘܒܐ", flow.Body);
            AppSettings.SetIncludeFilioque(false);
            flow.RefreshPrayerWording();
            Assert.Equal("Syrc", flow.AramaicScript);
            Assert.DoesNotContain("ܘܒܐ", flow.Body);
            Assert.Equal(1.0, flow.Progress);
        }
        finally
        {
            AppSettings.SetBasicPrayersLanguageCode(previousLanguage);
            AppSettings.SetAramaicDefaultScript(previousScript);
        }
    }
}

/// <summary>Keep each settings test independent, including the absence of the stored key.</summary>
internal sealed class AppSettingsFilioqueScope : IDisposable
{
    private const string Key = "includeFilioque";
    private static readonly FieldInfo Cache = typeof(AppSettings)
        .GetField("_includeFilioque", BindingFlags.NonPublic | BindingFlags.Static)!;
    private readonly object? _previousCache = Cache.GetValue(null);
    private readonly ApplicationDataContainer? _settings = (ApplicationDataContainer?)typeof(AppSettings)
        .GetMethod("TryGetLocalSettings", BindingFlags.NonPublic | BindingFlags.Static)!.Invoke(null, null);
    private readonly object? _previousStored;

    internal AppSettingsFilioqueScope(bool? preference)
    {
        _previousStored = _settings?.Values[Key];
        Cache.SetValue(null, preference);
        if (_settings is not null)
        {
            if (preference is { } value) _settings.Values[Key] = value;
            else _settings.Values.Remove(Key);
        }
    }

    internal void AssertStoredValue(bool value)
    {
        if (_settings is null) return; // An unpackaged test host only has the process cache.
        Assert.Equal(value, _settings.Values[Key]);
        Cache.SetValue(null, null);
        Assert.Equal(value, AppSettings.IncludeFilioquePreference);
    }

    public void Dispose()
    {
        if (_settings is not null)
        {
            if (_previousStored is null) _settings.Values.Remove(Key);
            else _settings.Values[Key] = _previousStored;
        }
        Cache.SetValue(null, _previousCache);
    }
}
