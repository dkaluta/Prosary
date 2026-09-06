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
    public void SharedAramaicPrayersKeepTheirHeadingsAndMatchingReadingAid()
    {
        Assert.Equal("שוּבחָא לַאבָא", PrayerPackStore.ResolveBodyText("oAntiphons", "arc", "gloriaPatriTitle"));
        Assert.Equal(PrayerPackStore.ResolveBodyText("trisagion", "arc", "gloriaPatri"),
            PrayerPackStore.ResolveBodyText("oAntiphons", "arc", "gloriaPatri"));
        var readingAid = PrayerPackStore.Transliteration("oAntiphons", "arc", "gloriaPatri");
        Assert.NotNull(readingAid);
        Assert.Equal(PrayerPackStore.Transliteration("trisagion", "arc", "gloriaPatri"), readingAid);
        // Rosary and Trisagion now share the corrected Gloria text and line breaks.
        Assert.Equal(PrayerPackStore.Transliteration("rosary", "arc", "gloriaPatri"), readingAid);
        Assert.Null(PrayerPackStore.Transliteration("oAntiphons", "en", "gloriaPatri"));
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
    public void SparseMysteryLayersMergeFieldsWithoutCrossPairingTransliterations()
    {
        var complete = new MysteryTextOverride(
            Title: "Earlier title",
            Fruit: "Earlier fruit",
            Description: "Earlier description",
            TransliteratedDescription: "Earlier transliteration");

        var titleOnly = PrayerPackStore.MergeMysteryOverrides(
            complete,
            new MysteryTextOverride(Title: "Later title"));
        Assert.Equal("Later title", titleOnly.Title);
        Assert.Equal("Earlier fruit", titleOnly.Fruit);
        Assert.Equal("Earlier description", titleOnly.Description);
        Assert.Equal("Earlier transliteration", titleOnly.TransliteratedDescription);

        var newDescription = PrayerPackStore.MergeMysteryOverrides(
            titleOnly,
            new MysteryTextOverride(Description: "Later description"));
        Assert.Equal("Later title", newDescription.Title);
        Assert.Equal("Earlier fruit", newDescription.Fruit);
        Assert.Equal("Later description", newDescription.Description);
        Assert.Null(newDescription.TransliteratedDescription);
    }

    [Fact]
    public void AngelusPackProvidesHebrewComposedBody()
    {
        var text = PrayerPackStore.ResolveBodyText("angelus", "he", "angelusCollectBody");
        Assert.False(string.IsNullOrEmpty(text));
        Assert.Contains("נִתְפַּלְּלָה", text);
    }

    /// <summary>The "main" prayers (Sign of the Cross, Creed, Our Father, Hail Mary, Glory Be) are
    /// deliberately absent from every bundle (see Shared/ARCHITECTURE.markdown) and must keep resolving
    /// from the hardcoded table even with both packs loaded. (Expected text hardcoded here rather
    /// than read from PrayerTranslations' per-language dictionaries — those are private to the
    /// Prosary assembly and not visible from this test project.)</summary>
    [Fact]
    public void MainPrayerKeyStillResolvesFromHardcodedTableNotFromAPack()
    {
        var text = PrayerTranslations.Get("en", PrayerKey.AveMaria);
        var expectedLines = new[]
        {
            "Hail Mary,",
            "full of grace, the Lord is with thee.",
            "Blessed art thou amongst women,",
            "and blessed is the fruit of thy womb, Jesus.",
            "Holy Mary, Mother of God,",
            "pray for us sinners,",
            "now and at the hour of our death. Amen.",
        };

        Assert.Equal(expectedLines, text.Split('\n'));
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
    public void EveryImageShippedByTheBuiltInPacksResolvesFromAPack()
    {
        var imageKeys = new HashSet<string>(StringComparer.Ordinal);
        foreach (var path in Directory.EnumerateFiles(
                     Path.Combine(AppContext.BaseDirectory, "PrayerPacks"),
                     "*.prosaryprayer"))
        {
            using var stream = File.OpenRead(path);
            using var archive = new System.IO.Compression.ZipArchive(
                stream, System.IO.Compression.ZipArchiveMode.Read);
            foreach (var entry in archive.Entries.Where(entry =>
                         entry.FullName.StartsWith("images/", StringComparison.Ordinal)
                         && entry.FullName.EndsWith(".jpg", StringComparison.Ordinal)))
            {
                imageKeys.Add(entry.FullName["images/".Length..^".jpg".Length]);
            }
        }

        // The counter-based Jesus Prayer has no pack of its own, so its illustration must be
        // supplied by one of the shared built-in packs before the loose JPEGs can stay deleted.
        Assert.Contains("christ_pantocrator", imageKeys);
        Assert.NotEmpty(imageKeys);
        Assert.All(imageKeys, key => Assert.NotEmpty(PrayerPackStore.ImageData(key) ?? []));
    }

    [Fact]
    public void PackImageExtractsInAnUnpackagedHostWithAnInjectedCacheDirectory()
    {
        var directory = Path.Combine(Path.GetTempPath(), $"prosary_image_cache_{Guid.NewGuid():N}");
        PrayerPackStore.ImageCacheDirectoryOverride = directory;
        try
        {
            var uri = PrayerPackStore.ImageFileUri("christ_pantocrator");

            Assert.NotNull(uri);
            var path = new Uri(uri!).LocalPath;
            Assert.True(path.StartsWith(directory, StringComparison.Ordinal));
            Assert.Equal(PrayerPackStore.ImageData("christ_pantocrator"), File.ReadAllBytes(path));
            Assert.Equal(uri, PrayerPackStore.ImageFileUri("christ_pantocrator"));
        }
        finally
        {
            PrayerPackStore.ImageCacheDirectoryOverride = null;
            if (Directory.Exists(directory)) Directory.Delete(directory, recursive: true);
        }
    }

    [Fact]
    public void PriorImageCacheCleanupDeletesFilesAndInvalidatesMemoizedUris()
    {
        var directory = Path.Combine(Path.GetTempPath(), $"prosary_image_cache_{Guid.NewGuid():N}");
        PrayerPackStore.ImageCacheDirectoryOverride = directory;
        try
        {
            var uri = PrayerPackStore.ImageFileUri("christ_pantocrator");
            Assert.NotNull(uri);
            var path = new Uri(uri!).LocalPath;
            Assert.True(File.Exists(path));

            PrayerPackStore.ClearPriorImageCache();

            Assert.False(Directory.Exists(directory));
            Assert.Equal(uri, PrayerPackStore.ImageFileUri("christ_pantocrator"));
            Assert.True(File.Exists(path));
        }
        finally
        {
            PrayerPackStore.ImageCacheDirectoryOverride = null;
            if (Directory.Exists(directory)) Directory.Delete(directory, recursive: true);
        }
    }

    [Fact]
    public void ImageOverrideAndRemovalUseRevisionedUrisAndRestoreTheBuiltInBytes()
    {
        var packDirectory = Path.Combine(Path.GetTempPath(), $"prosary_test_packs_{Guid.NewGuid():N}");
        var cacheDirectory = Path.Combine(Path.GetTempPath(), $"prosary_image_cache_{Guid.NewGuid():N}");
        var id = $"imageoverride{Random.Shared.Next(1000, 9999)}";
        const string imageKey = "christ_pantocrator";
        PrayerPackStore.InstalledPacksDirectory = packDirectory;
        PrayerPackStore.ImageCacheDirectoryOverride = cacheDirectory;

        try
        {
            var originalBytes = Assert.IsType<byte[]>(PrayerPackStore.ImageData(imageKey));
            var originalUri = Assert.IsType<string>(PrayerPackStore.ImageFileUri(imageKey));
            var originalPath = new Uri(originalUri).LocalPath;
            using var heldOriginal = new FileStream(
                originalPath,
                FileMode.Open,
                FileAccess.Read,
                FileShare.Read);
            var overrideBytes = Assert.IsType<byte[]>(PrayerPackStore.ImageData("jesus_portrait"));
            Assert.False(originalBytes.SequenceEqual(overrideBytes));

            PrayerPackStore.InstallPack(MakeImageOverridePack(id, imageKey, overrideBytes));
            var overrideUri = Assert.IsType<string>(PrayerPackStore.ImageFileUri(imageKey));
            Assert.NotEqual(originalUri, overrideUri);
            Assert.Equal(overrideBytes, File.ReadAllBytes(new Uri(overrideUri).LocalPath));

            PrayerPackStore.RemoveInstalledPack(id);
            var restoredUri = Assert.IsType<string>(PrayerPackStore.ImageFileUri(imageKey));
            Assert.Equal(originalUri, restoredUri);
            Assert.Equal(originalBytes, File.ReadAllBytes(new Uri(restoredUri).LocalPath));
        }
        finally
        {
            PrayerPackStore.RemoveInstalledPack(id);
            PrayerPackStore.ImageCacheDirectoryOverride = null;
            if (Directory.Exists(packDirectory)) Directory.Delete(packDirectory, recursive: true);
            if (Directory.Exists(cacheDirectory)) Directory.Delete(cacheDirectory, recursive: true);
        }
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

    [Fact]
    public void PackSafetyLimitsRejectOversizedDeclarationsBeforePayloadReads()
    {
        PrayerPackStore.ValidateArchiveLength(PrayerPackStore.MaxPackArchiveBytes);
        PrayerPackStore.ValidateEntryCount(PrayerPackStore.MaxPackEntryCount);
        Assert.Throws<InvalidDataException>(
            () => PrayerPackStore.ValidateArchiveLength(PrayerPackStore.MaxPackArchiveBytes + 1));
        Assert.Throws<InvalidDataException>(
            () => PrayerPackStore.ValidateEntryCount(PrayerPackStore.MaxPackEntryCount + 1));

        var entryLimits = new (string Name, long Limit)[]
        {
            ("manifest.json", PrayerPackStore.MaxControlEntryBytes),
            ("images/example.jpg", PrayerPackStore.MaxImageEntryBytes),
            ("audio/example.opus", PrayerPackStore.MaxAudioEntryBytes),
        };
        foreach (var (name, limit) in entryLimits)
        {
            PrayerPackStore.ValidateEntryDeclaration(name, limit, limit);
            Assert.Throws<InvalidDataException>(
                () => PrayerPackStore.ValidateEntryDeclaration(name, limit + 1, 1));
            Assert.Throws<InvalidDataException>(
                () => PrayerPackStore.ValidateEntryDeclaration(name, 1, limit + 1));
        }
    }

    [Fact]
    public async Task OversizedPickedArchiveIsRejectedBeforeItsStreamIsRead()
    {
        using var input = new OversizedSeekableStream(PrayerPackStore.MaxPackArchiveBytes + 1);

        await Assert.ThrowsAsync<PrayerPackStore.InstallException>(
            () => PrayerPackStore.ReadInstallBytesAsync(input));

        Assert.False(input.WasRead);
    }

    [Fact]
    public async Task KnownInstallLengthRequiresTheCompleteBodyAndNoTrailingBytes()
    {
        var expected = "portable bundle"u8.ToArray();

        using (var exact = new NonSeekableReadStream(expected))
        {
            Assert.Equal(
                expected,
                await PrayerPackStore.ReadInstallBytesAsync(
                    exact,
                    expectedLength: expected.Length));
        }

        using (var tooShort = new NonSeekableReadStream(expected[..^1]))
        {
            await Assert.ThrowsAsync<PrayerPackStore.InstallException>(
                () => PrayerPackStore.ReadInstallBytesAsync(
                    tooShort,
                    expectedLength: expected.Length));
        }

        using (var trailing = new NonSeekableReadStream([.. expected, 0]))
        {
            await Assert.ThrowsAsync<PrayerPackStore.InstallException>(
                () => PrayerPackStore.ReadInstallBytesAsync(
                    trailing,
                    expectedLength: expected.Length));
        }

        using var seekable = new MemoryStream(expected);
        await Assert.ThrowsAsync<PrayerPackStore.InstallException>(
            () => PrayerPackStore.ReadInstallBytesAsync(
                seekable,
                expectedLength: expected.Length - 1));
    }

    [Fact]
    public async Task UnknownInstallLengthSpoolsAndAlwaysRemovesItsTemporaryFile()
    {
        var directory = Path.Combine(Path.GetTempPath(), $"prosary_import_spool_{Guid.NewGuid():N}");
        var expected = "portable bundle"u8.ToArray();

        try
        {
            using (var input = new NonSeekableReadStream(expected))
            {
                Assert.Equal(
                    expected,
                    await PrayerPackStore.ReadInstallBytesAsync(
                        input,
                        temporaryDirectory: directory));
            }
            Assert.Empty(Directory.EnumerateFiles(directory));

            using var interrupted = new InterruptedReadStream("partial bundle"u8.ToArray());
            await Assert.ThrowsAsync<IOException>(
                () => PrayerPackStore.ReadInstallBytesAsync(
                    interrupted,
                    temporaryDirectory: directory));
            Assert.Empty(Directory.EnumerateFiles(directory));
        }
        finally
        {
            if (Directory.Exists(directory)) Directory.Delete(directory, recursive: true);
        }
    }

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

    private static byte[] MakeImageOverridePack(
        string id,
        string imageKey,
        byte[] imageBytes)
    {
        using var buffer = new MemoryStream();
        using (var zip = new System.IO.Compression.ZipArchive(
                   buffer,
                   System.IO.Compression.ZipArchiveMode.Create,
                   leaveOpen: true))
        {
            void Put(string name, string text)
            {
                using var writer = new StreamWriter(zip.CreateEntry(name).Open());
                writer.Write(text);
            }

            Put("manifest.json", $$"""
                {"schemaVersion": 1, "id": "{{id}}", "kind": "{{id}}", "displayName": "Image Override",
                 "languages": ["en"], "hasCatalog": false, "images": ["{{imageKey}}"]}
                """);
            Put("content/en.json", """{"prayers": {"exampleBody": "Kyrie eleison."}, "mysteries": {}}""");
            Put("devotion.json", $$"""
                {"type": "steps", "steps": [
                  {"title": "Example", "bodyKey": "exampleBody", "imageKey": "{{imageKey}}"}
                ]}
                """);
            using var image = zip.CreateEntry($"images/{imageKey}.jpg").Open();
            image.Write(imageBytes);
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
        Assert.Equal("exampleBody", PrayerPackStore.ResolveBodyText(id, "en", "exampleBody"));
        Directory.Delete(PrayerPackStore.InstalledPacksDirectory, recursive: true);
    }

    [Fact]
    public void InstallRejectsAPathTraversingBundleId()
    {
        var root = Path.Combine(Path.GetTempPath(), $"prosary_path_test_{Guid.NewGuid():N}");
        PrayerPackStore.InstalledPacksDirectory = Path.Combine(root, "PrayerPacks");
        var escapedName = $"escaped{Random.Shared.Next(1000, 9999)}";

        try
        {
            Assert.Throws<PrayerPackStore.InstallException>(
                () => PrayerPackStore.InstallPack(MakeExamplePack($"../{escapedName}")));
            Assert.False(File.Exists(Path.Combine(root, $"{escapedName}.prosaryprayer")));
        }
        finally
        {
            if (Directory.Exists(root)) Directory.Delete(root, recursive: true);
        }
    }

    /// <summary>A days-type (multi-day) bundle decodes, installs, and prays its first day —
    /// the groundwork contract until per-favorite day progress ships (see
    /// ARCHITECTURE.markdown).</summary>
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

    /// <summary>An audio-bearing bundle (audio.json + Ogg Opus files — see ARCHITECTURE.markdown's
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
        Assert.Equal("0b4c4a52-47", PrayerPackStore.AudioCacheKey(id, "audio/en.opus"));
        Assert.Null(PrayerPackStore.AudioCacheKey(id, "manifest.json"));
        Assert.Null(PrayerPackStore.AudioData(id, "manifest.json"));
        Assert.Empty(PrayerPackStore.AudioTracks("angelus"));
        Assert.Null(PrayerPackStore.AudioData("angelus", "audio/en.opus"));

        var extractedPath = Path.Combine(PrayerPackStore.InstalledPacksDirectory, "extracted.opus");
        Assert.True(PrayerPackStore.ExtractAudioFile(id, "audio/en.opus", extractedPath));
        Assert.Equal(opusBytes, File.ReadAllBytes(extractedPath));
        Assert.False(PrayerPackStore.ExtractAudioFile(id, "manifest.json", extractedPath));

        PrayerPackStore.RemoveInstalledPack(id);
        Directory.Delete(PrayerPackStore.InstalledPacksDirectory, recursive: true);
    }

    [Fact]
    public void FailedStreamingExtractionLeavesNoTruncatedCacheFile()
    {
        var directory = Path.Combine(Path.GetTempPath(), $"prosary_audio_cache_{Guid.NewGuid():N}");
        var path = Path.Combine(directory, "interrupted.opus");

        try
        {
            using var input = new InterruptedReadStream("partial audio bytes"u8.ToArray());

            Assert.False(PrayerPackStore.TryWriteFileAtomically(input, path));
            Assert.False(File.Exists(path));
            Assert.Empty(Directory.EnumerateFiles(directory));
        }
        finally
        {
            if (Directory.Exists(directory)) Directory.Delete(directory, recursive: true);
        }
    }

    [Fact]
    public void StreamingExtractionRequiresTheDeclaredLength()
    {
        var directory = Path.Combine(Path.GetTempPath(), $"prosary_length_cache_{Guid.NewGuid():N}");
        var path = Path.Combine(directory, "recording.opus");

        try
        {
            using (var exact = new MemoryStream("abc"u8.ToArray()))
            {
                Assert.True(PrayerPackStore.TryWriteFileAtomically(
                    exact, path, expectedLength: 3, maxBytes: 3));
                Assert.Equal("abc"u8.ToArray(), File.ReadAllBytes(path));
            }

            File.Delete(path);
            using (var tooLong = new MemoryStream("abcd"u8.ToArray()))
            {
                Assert.False(PrayerPackStore.TryWriteFileAtomically(
                    tooLong, path, expectedLength: 3, maxBytes: 3));
                Assert.False(File.Exists(path));
            }

            using var tooShort = new MemoryStream("ab"u8.ToArray());
            Assert.False(PrayerPackStore.TryWriteFileAtomically(
                tooShort, path, expectedLength: 3, maxBytes: 3));
            Assert.False(File.Exists(path));
        }
        finally
        {
            if (Directory.Exists(directory)) Directory.Delete(directory, recursive: true);
        }
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

    private sealed class InterruptedReadStream(byte[] firstChunk) : Stream
    {
        private bool _returnedFirstChunk;

        public override bool CanRead => true;
        public override bool CanSeek => false;
        public override bool CanWrite => false;
        public override long Length => throw new NotSupportedException();

        public override long Position
        {
            get => throw new NotSupportedException();
            set => throw new NotSupportedException();
        }

        public override int Read(byte[] buffer, int offset, int count)
        {
            if (_returnedFirstChunk) throw new IOException("Simulated interrupted pack read.");

            var copied = Math.Min(count, firstChunk.Length);
            Array.Copy(firstChunk, 0, buffer, offset, copied);
            _returnedFirstChunk = true;
            return copied;
        }

        public override ValueTask<int> ReadAsync(
            Memory<byte> buffer,
            CancellationToken cancellationToken = default)
        {
            cancellationToken.ThrowIfCancellationRequested();
            if (_returnedFirstChunk) throw new IOException("Simulated interrupted pack read.");

            var copied = Math.Min(buffer.Length, firstChunk.Length);
            firstChunk.AsMemory(0, copied).CopyTo(buffer);
            _returnedFirstChunk = true;
            return ValueTask.FromResult(copied);
        }

        public override void Flush() => throw new NotSupportedException();
        public override long Seek(long offset, SeekOrigin origin) => throw new NotSupportedException();
        public override void SetLength(long value) => throw new NotSupportedException();
        public override void Write(byte[] buffer, int offset, int count) =>
            throw new NotSupportedException();
    }

    private sealed class NonSeekableReadStream(byte[] data) : Stream
    {
        private int _position;

        public override bool CanRead => true;
        public override bool CanSeek => false;
        public override bool CanWrite => false;
        public override long Length => throw new NotSupportedException();

        public override long Position
        {
            get => throw new NotSupportedException();
            set => throw new NotSupportedException();
        }

        public override int Read(byte[] buffer, int offset, int count)
        {
            var copied = Math.Min(count, data.Length - _position);
            data.AsSpan(_position, copied).CopyTo(buffer.AsSpan(offset, copied));
            _position += copied;
            return copied;
        }

        public override ValueTask<int> ReadAsync(
            Memory<byte> buffer,
            CancellationToken cancellationToken = default)
        {
            cancellationToken.ThrowIfCancellationRequested();
            var copied = Math.Min(buffer.Length, data.Length - _position);
            data.AsMemory(_position, copied).CopyTo(buffer);
            _position += copied;
            return ValueTask.FromResult(copied);
        }

        public override void Flush() => throw new NotSupportedException();
        public override long Seek(long offset, SeekOrigin origin) => throw new NotSupportedException();
        public override void SetLength(long value) => throw new NotSupportedException();
        public override void Write(byte[] buffer, int offset, int count) =>
            throw new NotSupportedException();
    }

    private sealed class OversizedSeekableStream(long declaredLength) : Stream
    {
        public bool WasRead { get; private set; }
        public override bool CanRead => true;
        public override bool CanSeek => true;
        public override bool CanWrite => false;
        public override long Length => declaredLength;

        public override long Position { get; set; }

        public override int Read(byte[] buffer, int offset, int count)
        {
            WasRead = true;
            throw new InvalidOperationException("The oversized stream must be rejected before reading.");
        }

        public override void Flush() => throw new NotSupportedException();
        public override long Seek(long offset, SeekOrigin origin) => throw new NotSupportedException();
        public override void SetLength(long value) => throw new NotSupportedException();
        public override void Write(byte[] buffer, int offset, int count) =>
            throw new NotSupportedException();
    }
}
