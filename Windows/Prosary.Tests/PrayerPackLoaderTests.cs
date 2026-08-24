using Prosary.Localization;
using Prosary.Models;
using Prosary.Services;
using Xunit;

namespace Prosary.Tests;

/// <summary>
/// Proves the whole .prosaryprayer pipeline end-to-end against the actual bundled
/// .prosaryprayer files (produced by Shared/tools/make-prosaryprayer.sh
/// from Shared/content/) — mirrors iOS's PrayerPackLoaderTests.swift / Android's
/// PrayerPackLoaderTest.kt. <see cref="PrayerPackStore"/> is a process-wide singleton, so loading
/// happens once via a class fixture rather than per-test.
/// </summary>
public sealed class PrayerPackLoaderFixture
{
    public PrayerPackLoaderFixture()
    {
        PrayerPackStore.Initialize(packName =>
        {
            var path = Path.Combine(AppContext.BaseDirectory, "PrayerPacks", $"{packName}.prosaryprayer");
            return File.Exists(path) ? File.OpenRead(path) : null;
        });
    }
}

public class PrayerPackLoaderTests : IClassFixture<PrayerPackLoaderFixture>
{
    public PrayerPackLoaderTests(PrayerPackLoaderFixture _)
    {
    }

    [Fact]
    public void RosaryPackProvidedKeyOverridesEnglishText()
    {
        var text = PrayerTranslations.Get("en", PrayerKey.OratioFatimae);
        Assert.Equal(
            "O my Jesus, forgive us our sins, save us from the fires of hell, lead all souls to Heaven, especially those who are in most need of Thy mercy.",
            text);
    }

    [Fact]
    public void RosaryPackProvidedMysteryOverridesLatinTitle()
    {
        var text = MysteryTranslations.Get("la", "joyful_01_annunciation");
        Assert.Equal("Nuntiatio", text.Title);
        Assert.Equal("Humilitas", text.Fruit);
    }

    [Fact]
    public void AngelusPackProvidesHebrewComposedBody()
    {
        var text = PrayerPackStore.ResolveBodyText("angelus", "he", "angelusCollectBody");
        Assert.False(string.IsNullOrEmpty(text));
        Assert.Contains("נִתְפַּלְּלָה", text);
    }

    /// <summary>The "main" prayers (Sign of the Cross, Creed, Our Father, Hail Mary, Glory Be) are
    /// deliberately absent from every bundle (see Shared/ARCHITECTURE.md) and must keep resolving
    /// from the hardcoded table even with both packs loaded. (Expected text hardcoded here rather
    /// than read from PrayerTranslations' per-language dictionaries — those are private to the
    /// Prosary assembly and not visible from this test project.)</summary>
    [Fact]
    public void MainPrayerKeyStillResolvesFromHardcodedTableNotFromAPack()
    {
        var text = PrayerTranslations.Get("en", PrayerKey.AveMaria);
        Assert.Equal(
            "Hail Mary, full of grace, the Lord is with thee. Blessed art thou amongst women, and blessed is the fruit of thy womb, Jesus.\nHoly Mary, Mother of God, pray for us sinners, now and at the hour of our death. Amen.",
            text);
    }

    /// <summary>A devotion converted to a bundle resolves entirely bundle-locally — its keys no
    /// longer exist in the hardcoded tables at all.</summary>
    [Fact]
    public void ConvertedDevotionKeyResolvesFromItsBundle()
    {
        var text = PrayerPackStore.ResolveBodyText("stationsOfTheCross", "en", "stationsOpeningPrayer");
        Assert.StartsWith("My Lord Jesus Christ, You made this journey", text);
    }

    [Fact]
    public void RosaryPackProvidesImageDataForAMysteryKey()
    {
        var data = PrayerPackStore.ImageData("joyful_01_annunciation");
        Assert.NotNull(data);
        Assert.True(data!.Length > 0);
    }

    [Fact]
    public void FranciscanCrownDeclaresItsOptions()
    {
        var options = PrayerPackStore.Options("franciscanCrown");
        Assert.Equal(["seventyTwoHailMarys", "popeIntentions"], options.Select(o => o.Key));
        Assert.All(options, o =>
        {
            Assert.Equal(CustomDevotionOption.OptionKind.Toggle, o.Kind);
            Assert.Equal("true", o.DefaultValue);
        });
        Assert.Equal("Complete the 72 Hail Marys", options[0].Name);
        Assert.Empty(PrayerPackStore.Options("angelus"));
    }

    // User-installed bundles

    /// <summary>Builds a minimal, valid .prosaryprayer in memory — the same shape a
    /// third-party author would produce.</summary>
    private static byte[] MakeExamplePack(string id)
    {
        using var buffer = new MemoryStream();
        using (var zip = new System.IO.Compression.ZipArchive(buffer, System.IO.Compression.ZipArchiveMode.Create, leaveOpen: true))
        {
            void Put(string name, string text)
            {
                var entry = zip.CreateEntry(name);
                using var writer = new StreamWriter(entry.Open());
                writer.Write(text);
            }

            Put("manifest.json", $$"""
                {"schemaVersion": 1, "id": "{{id}}", "kind": "{{id}}", "displayName": "Example Devotion",
                 "languages": ["la", "en"], "hasCatalog": false, "images": []}
                """);
            const string content = """{"prayers": {"exampleBody": "Kyrie eleison."}, "mysteries": {}}""";
            Put("content/la.json", content);
            Put("content/en.json", content);
            Put("devotion.json", """
                {"type": "steps", "steps": [
                  {"title": "Sign of the Cross", "bodyKey": "signumCrucis", "imageKey": "crucifix"},
                  {"title": "Example Prayer", "bodyKey": "exampleBody"}
                ]}
                """);
        }

        return buffer.ToArray();
    }

    [Fact]
    public void InstallRemoveRoundTripForAnImportedBundle()
    {
        PrayerPackStore.InstalledPacksDirectory =
            Path.Combine(Path.GetTempPath(), $"prosary_test_packs_{Guid.NewGuid():N}");
        var id = $"example{Random.Shared.Next(1000, 9999)}";

        var installed = PrayerPackStore.InstallPack(MakeExamplePack(id));
        Assert.Equal(id, installed);
        Assert.Contains(id, PrayerPackStore.CustomDevotionIds());
        Assert.Contains(id, PrayerPackStore.InstalledBundleIds());
        Assert.Equal("Example Devotion", PrayerPackStore.Info(id)?.DisplayName);
        Assert.Equal("Kyrie eleison.", PrayerPackStore.ResolveBodyText(id, "en", "exampleBody"));

        // A second install of the same id must be rejected, not silently replaced.
        Assert.Throws<PrayerPackStore.InstallException>(() => PrayerPackStore.InstallPack(MakeExamplePack(id)));
        // Garbage is rejected.
        Assert.Throws<PrayerPackStore.InstallException>(() => PrayerPackStore.InstallPack("not a zip"u8.ToArray()));

        PrayerPackStore.RemoveInstalledPack(id);
        Assert.DoesNotContain(id, PrayerPackStore.CustomDevotionIds());
        Assert.Null(PrayerPackStore.Definition(id));
        Directory.Delete(PrayerPackStore.InstalledPacksDirectory, recursive: true);
    }

    /// <summary>A days-type (multi-day) bundle decodes, installs, and prays its first day —
    /// the groundwork contract until per-favorite day progress ships (see
    /// ARCHITECTURE.md).</summary>
    [Fact]
    public void DaysTypeBundlePraysItsFirstDay()
    {
        PrayerPackStore.InstalledPacksDirectory =
            Path.Combine(Path.GetTempPath(), $"prosary_test_packs_{Guid.NewGuid():N}");
        var id = $"novena{Random.Shared.Next(1000, 9999)}";

        using var buffer = new MemoryStream();
        using (var zip = new System.IO.Compression.ZipArchive(buffer, System.IO.Compression.ZipArchiveMode.Create, leaveOpen: true))
        {
            void Put(string name, string text)
            {
                using var writer = new StreamWriter(zip.CreateEntry(name).Open());
                writer.Write(text);
            }

            Put("manifest.json", $$"""
                {"schemaVersion": 1, "id": "{{id}}", "kind": "{{id}}", "displayName": "Example Novena",
                 "languages": ["la", "en"], "hasCatalog": false, "images": []}
                """);
            const string content = """{"prayers": {"day1Body": "Day one prayer.", "day2Body": "Day two prayer."}, "mysteries": {}}""";
            Put("content/la.json", content);
            Put("content/en.json", content);
            Put("devotion.json", """
                {"type": "days",
                 "opening": [{"title": "Sign of the Cross", "bodyKey": "signumCrucis", "imageKey": "crucifix"}],
                 "days": [
                   {"name": "Day 1", "steps": [{"title": "Day 1", "bodyKey": "day1Body"}]},
                   {"name": "Day 2", "steps": [{"title": "Day 2", "bodyKey": "day2Body"}]}
                 ],
                 "closing": [{"title": "Glory Be", "bodyKey": "gloriaPatri", "imageKey": "glory_be"}]}
                """);
        }

        PrayerPackStore.InstallPack(buffer.ToArray());

        var steps = PrayerEngine.BuildCustomDevotionSteps(
            id, "en", isEasterSeason: false, MarianAntiphonOption.SalveRegina);
        Assert.Equal(["Sign of the Cross", "Day 1", "Glory Be"], steps.Select(s => s.Title));
        Assert.Equal("Day one prayer.", steps[1].Body);

        PrayerPackStore.RemoveInstalledPack(id);
        Directory.Delete(PrayerPackStore.InstalledPacksDirectory, recursive: true);
    }

    /// <summary>An audio-bearing bundle (audio.json + Ogg Opus files — see ARCHITECTURE.md's
    /// "Audio") parses its track metadata and serves a declared file's bytes on
    /// demand; undeclared files stay unreachable, and audio-less bundles report no tracks.</summary>
    [Fact]
    public void AudioBearingBundleParsesTracksAndServesDeclaredBytes()
    {
        PrayerPackStore.InstalledPacksDirectory =
            Path.Combine(Path.GetTempPath(), $"prosary_test_packs_{Guid.NewGuid():N}");
        var id = $"audio{Random.Shared.Next(1000, 9999)}";

        // A minimal Ogg Opus signature (RFC 7845): an "OggS" page whose one-segment payload is
        // the "OpusHead" identification header at offset 28 — enough for the format's checks,
        // no real audio needed to prove the metadata/bytes plumbing.
        var opusBytes = "OggS"u8.ToArray()
            .Concat(new byte[24]).Concat("OpusHead"u8.ToArray()).Concat(new byte[11]).ToArray();

        using var buffer = new MemoryStream();
        using (var zip = new System.IO.Compression.ZipArchive(buffer, System.IO.Compression.ZipArchiveMode.Create, leaveOpen: true))
        {
            void Put(string name, string text)
            {
                using var writer = new StreamWriter(zip.CreateEntry(name).Open());
                writer.Write(text);
            }

            Put("manifest.json", $$"""
                {"schemaVersion": 1, "id": "{{id}}", "kind": "{{id}}", "displayName": "Example Devotion",
                 "languages": ["la", "en"], "hasCatalog": false, "images": []}
                """);
            const string content = """{"prayers": {"exampleBody": "Kyrie eleison."}, "mysteries": {}}""";
            Put("content/la.json", content);
            Put("content/en.json", content);
            Put("devotion.json", """
                {"type": "steps", "steps": [
                  {"title": "Sign of the Cross", "bodyKey": "signumCrucis", "imageKey": "crucifix"},
                  {"title": "Example Prayer", "bodyKey": "exampleBody"}
                ]}
                """);
            Put("audio.json", """
                {"tracks": [
                  {"id": "en", "language": "en", "file": "audio/en.opus", "name": "Full recitation",
                   "chapters": [
                     {"start": 0, "title": "Sign of the Cross", "stepIndex": 0},
                     {"start": 12.5, "title": "Example Prayer", "stepIndex": 1}
                   ]}
                ]}
                """);
            using var opusStream = zip.CreateEntry("audio/en.opus").Open();
            opusStream.Write(opusBytes);
        }

        PrayerPackStore.InstallPack(buffer.ToArray());

        var track = Assert.Single(PrayerPackStore.AudioTracks(id));
        Assert.Equal("en", track.Id);
        Assert.Equal("en", track.Language);
        Assert.Equal("audio/en.opus", track.File);
        Assert.Null(track.VariantId);
        Assert.Equal("Full recitation", track.Name);
        Assert.Equal(new double[] { 0, 12.5 }, track.Chapters!.Select(c => c.Start));
        Assert.Equal(new int?[] { 0, 1 }, track.Chapters!.Select(c => c.StepIndex));
        Assert.Equal("Sign of the Cross", track.Chapters![0].Title);

        Assert.Equal(opusBytes, PrayerPackStore.AudioData(id, "audio/en.opus"));
        Assert.Null(PrayerPackStore.AudioData(id, "manifest.json"));
        Assert.Empty(PrayerPackStore.AudioTracks("angelus"));
        Assert.Null(PrayerPackStore.AudioData("angelus", "audio/en.opus"));

        PrayerPackStore.RemoveInstalledPack(id);
        Directory.Delete(PrayerPackStore.InstalledPacksDirectory, recursive: true);
    }

    [Fact]
    public void StationsPackProvidesItsImageData()
    {
        var data = PrayerPackStore.ImageData("station_01_condemned_to_death");
        Assert.True((data?.Length ?? 0) > 0);
    }

    [Fact]
    public void PackProvidesNoImageDataForAnUnknownKey()
    {
        Assert.Null(PrayerPackStore.ImageData("no_such_image_key"));
    }

    // Generic (bundle-driven) devotions

    [Fact]
    public void TrisagionIsDiscoveredAsACustomDevotion()
    {
        Assert.Contains("trisagion", PrayerPackStore.CustomDevotionIds());
    }

    /// <summary>The Rosary's pack now ships a devotion.json (the engine builds the Rosary from
    /// it), but its manifest's builtinKind keeps it off the generic-devotion list — it backs
    /// the dedicated PrayerKind and must never appear in the devotion directory twice. The
    /// generic devotions appear in pack-load order.</summary>
    [Fact]
    public void CustomDevotionIdsAreTheGenericDevotionsInLoadOrder()
    {
        Assert.Equal(
            ["angelus", "stationsOfTheCross", "viaLucis", "franciscanCrown", "sevenSorrows", "divineMercyChaplet", "trisagion", "oAntiphons"],
            PrayerPackStore.CustomDevotionIds());
        Assert.NotNull(PrayerPackStore.Definition("rosary"));
    }

    [Fact]
    public void TrisagionInfoReadsFromItsManifest()
    {
        var info = PrayerPackStore.Info("trisagion");
        Assert.Equal("Trisagion", info?.DisplayName);
        Assert.Equal("#00796B", info?.AccentColorHex);
        Assert.Equal("triangle", info?.IconSystemName);
    }

    [Fact]
    public void TrisagionDefinitionMatchesTheAuthoredSixStepSequence()
    {
        var definition = PrayerPackStore.Definition("trisagion");
        Assert.Equal(CustomDevotionDefinition.DevotionType.Steps, definition?.Type);
        // The bundle names its forms now (Byzantine first = the default, Syriac second); the
        // default form must remain the authored six steps, byte-identical.
        Assert.Equal(["byzantine", "syriac"], definition?.Variants?.Select(v => v.Id));
        var steps = definition?.ResolvedSteps(null).Steps ?? [];
        // Headings are translatable keys, not literals, so they read in the prayer's language.
        Assert.Equal(
            [
                "trisagionAcclamationTitle", "trisagionAcclamationTitle", "trisagionAcclamationTitle",
                "gloriaPatriTitle", "trisagionAcclamationTitle", "trisagionAcclamationTitle",
            ],
            steps.Select(s => s.TitleKey));
        Assert.Equal(
            [
                "trisagionAcclamation", "trisagionAcclamation", "trisagionAcclamation",
                "gloriaPatri", "trisagionShortAcclamation", "trisagionAcclamation",
            ],
            steps.Select(s => s.BodyKey));
    }

    /// <summary><see cref="PrayerPackStore.ResolveBodyText"/> step 1 — a bundle-local-only key
    /// (never a real <see cref="PrayerKey"/> constant) resolves from the bundle's own raw
    /// content.</summary>
    [Fact]
    public void ResolveBodyTextResolvesABundleLocalKey()
    {
        var text = PrayerPackStore.ResolveBodyText("trisagion", "en", "trisagionAcclamation");
        Assert.Equal("Holy God, Holy Mighty One, Holy Immortal One, have mercy on us.", text);
    }

    /// <summary><see cref="PrayerPackStore.ResolveBodyText"/> step 2 — a key matching a shared
    /// "main" key ("gloriaPatri", deliberately absent from every bundle) falls through to the
    /// ordinary hardcoded table.</summary>
    [Fact]
    public void ResolveBodyTextFallsThroughToASharedPrayerKey()
    {
        var text = PrayerPackStore.ResolveBodyText("trisagion", "en", "gloriaPatri");
        Assert.Equal(PrayerTranslations.Get("en", PrayerKey.GloriaPatri), text);
    }

    /// <summary><see cref="PrayerPackStore.ResolveBodyText"/> step 3 — an unresolvable key
    /// returns itself (the original camelCase form, not its PascalCased lookup), matching
    /// iOS/Android.</summary>
    [Fact]
    public void ResolveBodyTextFallsBackToTheRawKey()
    {
        var text = PrayerPackStore.ResolveBodyText("trisagion", "en", "notARealKey");
        Assert.Equal("notARealKey", text);
    }
}
