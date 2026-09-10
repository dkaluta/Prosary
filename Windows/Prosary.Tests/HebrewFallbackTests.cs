using System.IO.Compression;
using System.Reflection;
using System.Text.Json;
using Prosary.Localization;
using Prosary.Models;
using Xunit;

namespace Prosary.Tests;

public class HebrewFallbackTests : IClassFixture<PrayerPackLoaderFixture>
{
    public HebrewFallbackTests(PrayerPackLoaderFixture _) { }

    [Theory]
    [InlineData("")]
    [InlineData("fr")]
    public void SavedLanguageLabelFollowsHebrewOnlyPlaybackWithoutRewritingRequestedChoice(string raw)
    {
        var previousDefault = AppSettings.DefaultLanguageCode;
        try
        {
            AppSettings.SetDefaultLanguageCode("la");
            using var fixture = new ImportedPack(new Dictionary<string, object>
            {
                ["he"] = new { prayers = new { genericBody = "Hebrew-only fixture" } },
            });
            fixture.SetOrder("he", "he-x-gamliel");
            var prayer = new Prayer { Kind = PrayerKind.Custom, CustomDevotionId = fixture.Id, LanguageCode = raw };
            Assert.Equal(raw.Length == 0 ? "la" : "fr", prayer.ResolvedLanguageCode);
            Assert.Equal("he", prayer.EffectiveLanguageCode);
            Assert.Equal("עברית", prayer.LanguageNativeName);
            Assert.Contains("עברית", prayer.LanguageDisplayName);
            Assert.DoesNotContain("Latina", prayer.LanguageDisplayName);
            var engine = new Prosary.Services.PrayerEngine(new Prosary.Services.LiturgicalCalendarService());
            Assert.Equal("Hebrew-only fixture", Assert.Single(engine.BuildSteps(prayer)).Body);
            Assert.Equal(raw, prayer.LanguageCode);
        }
        finally { AppSettings.SetDefaultLanguageCode(previousDefault); }
    }

    [Fact]
    public void SavedLanguageLabelReevaluatesTheCurrentBundleFallbackOrder()
    {
        var previousDefault = AppSettings.DefaultLanguageCode;
        try
        {
            AppSettings.SetDefaultLanguageCode("la");
            using var fixture = new ImportedPack(new Dictionary<string, object>
            {
                ["he"] = new { prayers = new { genericBody = "Hebrew fixture" } },
                ["fr"] = new { prayers = new { genericBody = "French fixture" } },
            });
            var prayer = new Prayer { Kind = PrayerKind.Custom, CustomDevotionId = fixture.Id };
            fixture.SetOrder("fr", "he", "he-x-gamliel");
            Assert.Equal("fr", prayer.EffectiveLanguageCode);
            Assert.Equal("Français", prayer.LanguageNativeName);
            fixture.SetOrder("he", "fr", "he-x-gamliel");
            Assert.Equal("he", prayer.EffectiveLanguageCode);
            Assert.Equal("עברית", prayer.LanguageNativeName);
            Assert.Equal(LanguageCatalog.DefaultSentinel, prayer.LanguageCode);
        }
        finally { AppSettings.SetDefaultLanguageCode(previousDefault); }
    }

    [Fact]
    public void UnknownDeclaredBundleLanguageIsNotMislabeledAsLatin()
    {
        using var fixture = new ImportedPack(new Dictionary<string, object>
        {
            ["zz"] = new { prayers = new { genericBody = "Unknown-language fixture" } },
        });
        var prayer = new Prayer { Kind = PrayerKind.Custom, CustomDevotionId = fixture.Id, LanguageCode = "en" };
        Assert.Equal("en", prayer.ResolvedLanguageCode);
        Assert.Equal("zz", prayer.EffectiveLanguageCode);
        Assert.Equal("zz", prayer.LanguageNativeName);
        Assert.Equal("zz", prayer.LanguageDisplayName);
    }

    [Fact]
    public void OrdinaryPrayerKindsAndMissingCustomIdsKeepRequestedResolution()
    {
        var previousDefault = AppSettings.DefaultLanguageCode;
        try
        {
            AppSettings.SetDefaultLanguageCode("uk");
            foreach (var kind in Enum.GetValues<PrayerKind>())
            {
                var prayer = new Prayer { Kind = kind };
                Assert.Equal("uk", prayer.ResolvedLanguageCode);
                Assert.Equal("uk", prayer.EffectiveLanguageCode);
                Assert.Equal("Українська", prayer.LanguageNativeName);
            }
        }
        finally { AppSettings.SetDefaultLanguageCode(previousDefault); }
    }

    [Fact]
    public void JaffaWordingChangesOnlyResolvedVicariateTextAndRestoresTheOriginal()
    {
        var previous = AppSettings.UseJaffaHailMaryWording;
        try
        {
            AppSettings.SetUseJaffaHailMaryWording(false);
            var original = PrayerTranslations.Get("he", PrayerKey.AveMaria);
            var native = PrayerTranslations.NativeTextAtProbe(LanguageCatalog.VicariateContentCode, PrayerKey.AveMaria);
            var mission = PrayerTranslations.Get("he-x-gamliel", PrayerKey.AveMaria);
            Assert.Contains("מְלֵאַת הַחֶסֶד", original);

            AppSettings.SetUseJaffaHailMaryWording(true);
            var expected = original.Replace("מְלֵאַת הַחֶסֶד", "בְּרוּכַת הַחֶסֶד");
            Assert.Equal(expected, PrayerTranslations.Get("he", PrayerKey.AveMaria));
            Assert.Equal(expected, PrayerPackStore.ResolveBodyText("missing_bundle", "he", "aveMaria"));
            Assert.Equal(mission, PrayerTranslations.Get("he-x-gamliel", PrayerKey.AveMaria));
            Assert.Equal(native, PrayerTranslations.NativeTextAtProbe(LanguageCatalog.VicariateContentCode, PrayerKey.AveMaria));

            AppSettings.SetUseJaffaHailMaryWording(false);
            Assert.Equal(original, PrayerTranslations.Get("he", PrayerKey.AveMaria));
            Assert.Equal(original, PrayerPackStore.ResolveBodyText("missing_bundle", "he", "aveMaria"));
        }
        finally { AppSettings.SetUseJaffaHailMaryWording(previous); }
    }

    [Theory]
    [InlineData("מְלֵאַת הַחֶסֶד", "בְּרוּכַת הַחֶסֶד")]
    [InlineData("מלאת החסד", "ברוכת החסד")]
    public void JaffaWordingFollowsMarkedFallbackContentAndSuppressesOnlyMismatchedAids(
        string originalPhrase, string replacementPhrase)
    {
        using var fixture = new ImportedPack(new Dictionary<string, object>
        {
            ["he"] = new Dictionary<string, object>
            {
                ["prayers"] = new { genericBody = $"Before {originalPhrase}. After {originalPhrase}.", noChange = "unaltered Vicariate body" },
                ["transliterations"] = new { genericBody = "original matching aid", noChange = "unaltered matching aid" },
                ["$prayerTraditionByKey"] = new { genericBody = "vicariate", noChange = "vicariate" },
            },
            ["arc"] = new { prayers = new { anotherBody = "Aramaic" } },
        });
        fixture.SetOrder("he-x-gamliel", "arc", "he");
        AppSettings.SetUseJaffaHailMaryWording(false);
        var original = PrayerPackStore.ResolveBodyText(fixture.Id, "he-x-gamliel", "genericBody");
        Assert.Equal("original matching aid", PrayerPackStore.Transliteration(fixture.Id, "he-x-gamliel", "genericBody"));

        AppSettings.SetUseJaffaHailMaryWording(true);
        Assert.Equal($"Before {replacementPhrase}. After {replacementPhrase}.",
            PrayerPackStore.ResolveBodyText(fixture.Id, "he-x-gamliel", "genericBody"));
        Assert.Null(PrayerPackStore.Transliteration(fixture.Id, "he-x-gamliel", "genericBody"));
        Assert.Equal("unaltered Vicariate body", PrayerPackStore.ResolveBodyText(fixture.Id, "he-x-gamliel", "noChange"));
        Assert.Equal("unaltered matching aid", PrayerPackStore.Transliteration(fixture.Id, "he-x-gamliel", "noChange"));

        AppSettings.SetUseJaffaHailMaryWording(false);
        Assert.Equal(original, PrayerPackStore.ResolveBodyText(fixture.Id, "he-x-gamliel", "genericBody"));
        Assert.Equal("original matching aid", PrayerPackStore.Transliteration(fixture.Id, "he-x-gamliel", "genericBody"));
    }

    [Theory]
    [InlineData("he")]
    [InlineData("he-x-gamliel")]
    public void JaffaWordingLeavesGenericRepositoryAndMissionTextAndScriptureUntouched(string contentLanguage)
    {
        const string original = "מְלֵאַת הַחֶסֶד / מלאת החסד";
        using var fixture = new ImportedPack(new Dictionary<string, object>
        {
            [contentLanguage] = new
            {
                prayers = new { genericBody = original },
                transliterations = new { genericBody = "unchanged reading aid" },
                mysteries = new Dictionary<string, object>
                {
                    ["jaffa_immunity_fixture"] = new { description = original, transliteratedDescription = "unchanged Scripture aid" },
                },
            },
        });
        fixture.SetOrder("he", "he-x-gamliel", "arc");
        AppSettings.SetUseJaffaHailMaryWording(true);
        Assert.Equal(original, PrayerPackStore.ResolveBodyText(fixture.Id, "he", "genericBody"));
        Assert.Equal("unchanged reading aid", PrayerPackStore.Transliteration(fixture.Id, "he", "genericBody"));
        var mystery = MysteryTranslations.Get("he", "jaffa_immunity_fixture");
        Assert.Equal(original, mystery.Description);
        Assert.Equal("unchanged Scripture aid", mystery.TransliteratedDescription);
    }

    [Theory]
    [InlineData("he-x-gamliel", "he", "arc body", "arc aid")]
    [InlineData("he", "he-x-gamliel", "Vicariate body", "Vicariate aid")]
    public void ImportedContentKeepsTraditionsIndependentAndReadingAidsPaired(
        string first, string last, string expectedTraditionBody, string expectedAid)
    {
        using var fixture = new ImportedPack(new Dictionary<string, object>
        {
            ["he"] = new Dictionary<string, object>
            {
                ["prayers"] = new { genericBody = "generic Hebrew", traditionBody = "Vicariate body", noAid = "generic without aid" },
                ["transliterations"] = new { genericBody = "generic aid", traditionBody = "Vicariate aid" },
                ["$prayerTraditionByKey"] = new { traditionBody = "vicariate" },
            },
            ["arc"] = new
            {
                prayers = new { genericBody = "arc generic", traditionBody = "arc body", noAid = "arc with aid" },
                transliterations = new { genericBody = "arc generic aid", traditionBody = "arc aid", noAid = "arc aid to reject" },
            },
        });
        fixture.SetOrder(first, "arc", last);

        Assert.Equal("generic Hebrew", PrayerPackStore.ResolveBodyText(fixture.Id, "en", "genericBody"));
        Assert.Equal("generic aid", PrayerPackStore.Transliteration(fixture.Id, "en", "genericBody"));
        Assert.Equal(expectedTraditionBody, PrayerPackStore.ResolveBodyText(fixture.Id, "en", "traditionBody"));
        Assert.Equal(expectedAid, PrayerPackStore.Transliteration(fixture.Id, "en", "traditionBody"));
        Assert.Equal("generic without aid", PrayerPackStore.ResolveBodyText(fixture.Id, "en", "noAid"));
        Assert.Null(PrayerPackStore.Transliteration(fixture.Id, "en", "noAid"));
        Assert.Equal(first, PrayerPackStore.EffectiveLanguage(fixture.Id, "en"));
        Assert.DoesNotContain(LanguageCatalog.All, option => option.Code == LanguageCatalog.VicariateContentCode);
    }

    [Fact]
    public void EffectiveLanguageDoesNotMistakeMarkedVicariateContentForGenericHebrew()
    {
        using var fixture = new ImportedPack(new Dictionary<string, object>
        {
            ["he"] = new Dictionary<string, object>
            {
                ["prayers"] = new { traditionBody = "Vicariate only" },
                ["$prayerTraditionByKey"] = new { traditionBody = "vicariate" },
            },
            ["arc"] = new { prayers = new { traditionBody = "Aramaic first" } },
        });
        fixture.SetOrder("he-x-gamliel", "arc", "he");
        Assert.Equal("arc", PrayerPackStore.EffectiveLanguage(fixture.Id, "he-x-gamliel"));
        Assert.Equal("Aramaic first", PrayerPackStore.ResolveBodyText(fixture.Id, "he-x-gamliel", "traditionBody"));
        fixture.SetOrder("he", "arc", "he-x-gamliel");
        Assert.Equal("he", PrayerPackStore.EffectiveLanguage(fixture.Id, "en"));
    }

    [Fact]
    public void SparseUndeclaredGreekOverlayDoesNotBecomeTheSessionLanguage()
    {
        using var fixture = new ImportedPack(new Dictionary<string, object>
        {
            ["en"] = new { prayers = new { genericBody = "declared English body" } },
            ["he"] = new { prayers = new { genericBody = "declared Hebrew body" } },
            ["el"] = new { prayers = new { overlayTitle = "sparse Greek heading" } },
        }, ["en", "he"]);
        fixture.SetOrder("en", "he", "he-x-gamliel");

        Assert.DoesNotContain("el", PrayerPackStore.Info(fixture.Id)!.Languages);
        Assert.Equal("en", PrayerPackStore.EffectiveLanguage(fixture.Id, "el"));
        Assert.Equal("sparse Greek heading", PrayerPackStore.ResolveBodyText(fixture.Id, "el", "overlayTitle"));
        Assert.Equal("declared English body", PrayerPackStore.ResolveBodyText(fixture.Id, "el", "genericBody"));
    }

    [Theory]
    [InlineData(true, "he-x-gamliel")]
    [InlineData(false, "arc")]
    public void MissionDeclarationCanUseGenericHebrewButDoesNotDeclareVicariateContent(
        bool includeGenericHebrew, string expectedLanguage)
    {
        var hebrewPrayers = new Dictionary<string, string> { ["traditionBody"] = "Vicariate body" };
        if (includeGenericHebrew) hebrewPrayers["genericBody"] = "generic Hebrew body";
        using var fixture = new ImportedPack(new Dictionary<string, object>
        {
            ["he-x-gamliel"] = new { prayers = new Dictionary<string, string>() },
            ["he"] = new Dictionary<string, object>
            {
                ["prayers"] = hebrewPrayers,
                ["$prayerTraditionByKey"] = new { traditionBody = "vicariate" },
            },
            ["arc"] = new { prayers = new { genericBody = "Aramaic body" } },
        }, ["he-x-gamliel", "arc"]);
        fixture.SetOrder("he-x-gamliel", "he", "arc");

        Assert.Equal(expectedLanguage, PrayerPackStore.EffectiveLanguage(fixture.Id, "he-x-gamliel"));
        Assert.Equal(includeGenericHebrew ? "generic Hebrew body" : "Aramaic body",
            PrayerPackStore.ResolveBodyText(fixture.Id, "he-x-gamliel", "genericBody"));
    }

    [Fact]
    public void SharedGenericHebrewAndMysteriesUseTheFirstHebrewSlotWithoutChangingNativePrecedence()
    {
        using var fixture = new ImportedPack(new Dictionary<string, object>
        {
            ["he"] = new
            {
                prayers = new { oratioFatimae = "generic shared prayer" },
                transliterations = new { oratioFatimae = "generic shared aid" },
                mysteries = new Dictionary<string, object>
                {
                    ["fallback_fixture"] = new { title = "generic title", description = "generic description", transliteratedDescription = "generic description aid" },
                },
            },
            ["arc"] = new
            {
                prayers = new { oratioFatimae = "arc shared prayer" },
                transliterations = new { oratioFatimae = "arc shared aid" },
                mysteries = new Dictionary<string, object>
                {
                    ["fallback_fixture"] = new { title = "arc title", description = "arc description", transliteratedDescription = "arc description aid" },
                },
            },
        });
        fixture.SetOrder("he-x-gamliel", "arc", "he");
        Assert.Equal("generic shared prayer", PrayerTranslations.Get("he-x-gamliel", PrayerKey.OratioFatimae));
        Assert.Equal("generic shared prayer", PrayerPackStore.ResolveBodyText("missing_bundle", "he-x-gamliel", "oratioFatimae"));
        Assert.Equal("generic shared aid", PrayerPackStore.Transliteration("missing_bundle", "he-x-gamliel", "oratioFatimae"));
        var mystery = MysteryTranslations.Get("he-x-gamliel", "fallback_fixture");
        Assert.Equal("generic title", mystery.Title);
        Assert.Equal("generic description", mystery.Description);
        Assert.Equal("generic description aid", mystery.TransliteratedDescription);
        Assert.Equal(PrayerTranslations.Get("en", PrayerKey.PaterNoster),
            PrayerPackStore.ResolveBodyText(fixture.Id, "en", "paterNoster"));
        Assert.Null(PrayerPackStore.Transliteration(fixture.Id, "en", "paterNoster"));
        Assert.Null(PrayerTranslations.NativeTextAtProbe("he", PrayerKey.OratioFatimae));
        Assert.NotNull(PrayerTranslations.NativeTextAtProbe(LanguageCatalog.VicariateContentCode, PrayerKey.OratioFatimae));
        Assert.NotNull(PrayerTranslations.NativeTextAtProbe("he", PrayerKey.FructusMysteriiLabel));
    }

    [Theory]
    [InlineData("he-x-gamliel", "he", "he-x-gamliel", "he", "arc", "he-x-vicariate")]
    [InlineData("he", "he-x-gamliel", "he-x-vicariate", "he", "arc", "he-x-gamliel")]
    public void RawAndContentChainsKeepDistinctContracts(string first, string last,
        string probe1, string probe2, string probe3, string probe4)
    {
        var previous = AppSettings.LanguageFallbackOrder.ToArray();
        try
        {
            AppSettings.SetLanguageFallbackOrder([first, "arc", last, "la"]);
            Assert.Equal(new[] { first, "arc", last }, LanguageCatalog.FallbackChain(first).Take(3));
            var content = LanguageCatalog.ContentFallbackChain(first);
            Assert.Equal(new[] { probe1, probe2, probe3, probe4 }, content.Take(4));
            Assert.Single(content, code => code == "he");
            Assert.Equal("la", content.Last());
            Assert.Equal(new[] { "en-US", "en" }, LanguageCatalog.FallbackChain("en-US").Take(2));
        }
        finally { AppSettings.SetLanguageFallbackOrder(previous); }
    }

    private sealed class ImportedPack : IDisposable
    {
        public string Id { get; } = "fallback_" + Guid.NewGuid().ToString("N");
        private readonly string _directory = Path.Combine(Path.GetTempPath(), "prosary-fallback-" + Guid.NewGuid().ToString("N"));
        private readonly string? _previousDirectory = PrayerPackStore.InstalledPacksDirectory;
        private readonly string[] _previousOrder = AppSettings.LanguageFallbackOrder.ToArray();
        private readonly bool _previousJaffaWording = AppSettings.UseJaffaHailMaryWording;
        private readonly Action _restorePrayers = Snapshot<string>("PrayerOverrides");
        private readonly Action _restoreAids = Snapshot<string>("PrayerTransliterations");
        private readonly Action _restoreMysteries = Snapshot<MysteryTextOverride>("MysteryOverrides");

        public ImportedPack(Dictionary<string, object> contents, string[]? declaredLanguages = null)
        {
            PrayerPackStore.InstalledPacksDirectory = _directory;
            using var buffer = new MemoryStream();
            using (var archive = new ZipArchive(buffer, ZipArchiveMode.Create, leaveOpen: true))
            {
                void Put(string path, object value)
                {
                    using var writer = new StreamWriter(archive.CreateEntry(path).Open());
                    writer.Write(JsonSerializer.Serialize(value));
                }
                Put("manifest.json", new { schemaVersion = 1, id = Id, kind = Id, displayName = "Fallback fixture", languages = declaredLanguages ?? contents.Keys.ToArray(), hasCatalog = false, images = Array.Empty<string>() });
                Put("devotion.json", new { type = "steps", steps = new[] { new { title = "Fixture", bodyKey = "genericBody" } } });
                foreach (var (language, content) in contents) Put($"content/{language}.json", content);
            }
            PrayerPackStore.InstallPack(buffer.ToArray());
        }

        public void SetOrder(params string[] codes) => AppSettings.SetLanguageFallbackOrder(codes.Concat(["la"]));

        public void Dispose()
        {
            PrayerPackStore.RemoveInstalledPack(Id);
            _restorePrayers();
            _restoreAids();
            _restoreMysteries();
            PrayerPackStore.InstalledPacksDirectory = _previousDirectory;
            AppSettings.SetLanguageFallbackOrder(_previousOrder);
            AppSettings.SetUseJaffaHailMaryWording(_previousJaffaWording);
            if (Directory.Exists(_directory)) Directory.Delete(_directory, recursive: true);
        }

        // Removing an installed bundle intentionally leaves global overrides until relaunch.
        // Synthetic shared-key fixtures restore those maps so no later test inherits their text.
        private static Action Snapshot<T>(string field)
        {
            var map = (Dictionary<string, Dictionary<string, T>>)typeof(PrayerPackStore)
                .GetField(field, BindingFlags.NonPublic | BindingFlags.Static)!.GetValue(null)!;
            var previous = map.ToDictionary(pair => pair.Key, pair => new Dictionary<string, T>(pair.Value));
            return () =>
            {
                map.Clear();
                foreach (var (code, values) in previous) map[code] = values;
            };
        }
    }
}
