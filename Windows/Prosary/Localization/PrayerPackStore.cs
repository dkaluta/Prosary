using System.Globalization;
using System.IO.Compression;
using System.Text.Json;
using System.Text.Json.Serialization;
using Prosary.Models;
using Windows.Storage;

namespace Prosary.Localization;

/// <summary>
/// Loads the bundled .prosaryprayer packs (Rosary, and every generic bundle-driven devotion —
/// see Shared/ARCHITECTURE.markdown's "Content bundles" section) and merges their content into
/// <see cref="PrayerTranslations"/>/<see cref="MysteryTranslations"/> as an override layer.
/// PrayerKey/mystery imageKey entries are a shared pool across devotions (e.g. "our_father" is
/// used by Rosary and several bundle devotions alike), so a pack can only ever add to the
/// hardcoded tables, never replace them wholesale.
/// <para>
/// A bundle with a <c>devotion.json</c> is a *generic devotion*:
/// <see cref="Prosary.Models.PrayerKind.Custom"/> + a <c>CustomDevotionId</c> are the only
/// engine/model plumbing it needs (see <c>PrayerEngine.BuildCustomDevotionSteps</c>) — its step
/// sequence (flat "steps" type, or decade/bead-structured "rosary" type) and per-step body text
/// are entirely data-driven from here, via <see cref="Definition"/>/<see cref="ResolveBodyText"/>.
/// </para>
/// </summary>
public static class PrayerPackStore
{
    /// <summary>Load order — also the display order of generic-devotion cards/rows (Home,
    /// Favorites), so this list is deliberately an ordered array, never a dictionary's unordered
    /// keys. The rosary pack loads first so its shared mystery texts/images are the base other
    /// bundles build on.</summary>
    private static readonly string[] PackNames =
    [
        "rosary", "angelus", "stationsOfTheCross", "viaLucis", "franciscanCrown", "sevenSorrows",
        "divineMercyChaplet", "trisagion", "oAntiphons",
    ];

    // Imported packs are untrusted. These ceilings are intentionally far above every shipped
    // pack while keeping central-directory metadata, JSON, decoded images, and recordings from
    // turning attacker-controlled ZIP sizes into unbounded managed allocations.
    internal const long MaxPackArchiveBytes = 512L * 1024 * 1024;
    internal const int MaxPackEntryCount = 4_096;
    internal const long MaxControlEntryBytes = 8L * 1024 * 1024;
    internal const long MaxControlTotalBytes = 32L * 1024 * 1024;
    internal const long MaxImageEntryBytes = 64L * 1024 * 1024;
    internal const long MaxAudioEntryBytes = 256L * 1024 * 1024;
    private const string UnreadablePackMessage =
        "This file is not a readable .prosaryprayer bundle.";

    private static readonly Dictionary<string, Dictionary<string, string>> PrayerOverrides = new();
    private static readonly Dictionary<string, Dictionary<string, MysteryTextOverride>> MysteryOverrides = new();
    /// <summary>Image key → pack entries that provide it, in load order. Only the tiny entry
    /// locations stay resident: JPEG bytes are streamed from the winning pack when WinUI first
    /// asks for an image, then released after the cache file is written. Some shared artwork is
    /// intentionally present in more than one portable pack, so keeping the earlier locations
    /// also gives a corrupt/missing later pack a working fallback.</summary>
    private static readonly Dictionary<string, List<PackEntryLocation>> ImageLocationsByKey = new();
    private static readonly Dictionary<string, string> ExtractedImageUris = new();
    private static long _nextImageRevision;
    private static string? _imageCacheDirectoryOverride;
    private static readonly string ImageCacheSessionName = Guid.NewGuid().ToString("N");

    /// <summary>Test/unpackaged-host seam: those processes have no package identity, hence no
    /// <see cref="ApplicationData.Current"/>. Changing it also invalidates URI memoization so a
    /// temporary test directory can never leak into a later caller.</summary>
    internal static string? ImageCacheDirectoryOverride
    {
        get => _imageCacheDirectoryOverride;
        set
        {
            _imageCacheDirectoryOverride = value;
            ExtractedImageUris.Clear();
        }
    }

    /// <summary>Unfiltered per-bundle content, keyed bundleId -> language -> raw (camelCase)
    /// key -> text — unlike <see cref="PrayerOverrides"/> (PascalCased, merged globally), this
    /// keeps each bundle's own keys addressable per bundle, which is how a generic devotion's
    /// <c>devotion.json</c> resolves bundle-local body text. See <see cref="ResolveBodyText"/>.</summary>
    private static readonly Dictionary<string, Dictionary<string, Dictionary<string, string>>> RawContentByBundle = new();

    /// <summary>bundleId → language → prayer key → transliterated text (v0.7 reading aid).</summary>
    private static readonly Dictionary<string, Dictionary<string, Dictionary<string, string>>> TransliterationsByBundle = new();
    private static readonly Dictionary<string, CustomDevotionDefinition> DefinitionByBundle = new();
    private static readonly Dictionary<string, List<CustomDevotionOption>> OptionsByBundle = new();
    private static readonly Dictionary<string, List<DevotionAudioTrack>> AudioTracksByBundle = new();

    /// <summary>Each loaded bundle's re-openable pack source. Images and audio are streamed from
    /// here on demand instead of being retained as byte arrays at startup.</summary>
    private static readonly Dictionary<string, Func<Stream?>> PackSourceByBundle = new();

    /// <summary>Bundle ids with a devotion.json, in pack-load order.</summary>
    private static readonly List<string> OrderedCustomIds = new();
    private static readonly Dictionary<string, CustomDevotionInfo> InfoByBundle = new();

    /// <summary>Bundle ids installed by the user (files in <see cref="InstalledPacksDirectory"/>),
    /// in load order.</summary>
    private static readonly List<string> InstalledIds = new();

    /// <summary>Where user-imported .prosaryprayer files live — scanned (sorted by filename)
    /// after the built-in packs on every load, so installs survive restarts. Set before
    /// <see cref="Initialize"/> (App.xaml.cs; tests may point it at a temp dir).</summary>
    public static string? InstalledPacksDirectory { get; set; }
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
        Converters = { new JsonStringEnumConverter(JsonNamingPolicy.CamelCase) },
    };
    private static bool _didLoad;

    public static string? PrayerOverride(string languageCode, string key)
    {
        if (key == PrayerKey.SignumCrucis
            && (LanguageCatalog.BaseLanguage(languageCode) ?? languageCode) == "arc"
            && AppSettings.UsesSystemWideAramaicSignOfCrossForm
            && AppSettings.AramaicSignOfCrossForm == AppSettings.AramaicSignOfCrossFormB
            && RawContentByBundle.TryGetValue("rosary", out var rosaryLanguages)
            && rosaryLanguages.TryGetValue("arc", out var aramaic)
            && aramaic.TryGetValue("signumCrucisFormB", out var formBText))
        {
            return formBText;
        }
        return PrayerOverrides.TryGetValue(languageCode, out var table) && table.TryGetValue(key, out var text)
            ? text
            : null;
    }

    public static MysteryTextOverride? MysteryOverride(string languageCode, string imageKey) =>
        MysteryOverrides.TryGetValue(languageCode, out var table) && table.TryGetValue(imageKey, out var text) ? text : null;

    /// <summary>Reads one pack-provided image on demand. This byte-level compatibility seam is
    /// mainly useful to callers/tests that need the encoded data; WinUI rendering goes through
    /// <see cref="ImageFileUri"/>, which streams directly to disk without creating this array.</summary>
    public static byte[]? ImageData(string imageKey)
    {
        if (!ImageLocationsByKey.TryGetValue(imageKey, out var locations)) return null;

        for (var index = locations.Count - 1; index >= 0; index--)
        {
            if (TryReadPackEntry(
                    locations[index],
                    MaxImageEntryBytes,
                    entry => ReadAllBytes(entry, MaxImageEntryBytes),
                    out byte[] data))
            {
                return data;
            }
        }

        return null;
    }

    /// <summary>The parsed <c>devotion.json</c> for a generic (bundle-driven) devotion, e.g.
    /// "trisagion". Null for any bundle without one (Rosary, which stays override-only).</summary>
    public static CustomDevotionDefinition? Definition(string bundleId) =>
        DefinitionByBundle.TryGetValue(bundleId, out var definition) ? definition : null;

    /// <summary>Bundle ids the user has imported (subset of <see cref="CustomDevotionIds"/>),
    /// in load order.</summary>
    public static IReadOnlyList<string> InstalledBundleIds() => InstalledIds;

    /// <summary>The on-disk .prosaryprayer file of an *installed* bundle — the export seam:
    /// sharing this file is how a devotion travels back to Compose for editing (v0.7,
    /// Gamaliel item 7). Null for shipped bundles.</summary>
    public static string? InstalledPackPath(string bundleId)
    {
        if (!InstalledIds.Contains(bundleId) || InstalledPacksDirectory is not { } dir) return null;
        var path = Path.Combine(dir, $"{bundleId}.prosaryprayer");
        return File.Exists(path) ? path : null;
    }

    /// <summary>The language a session actually prays a bundle in: the chosen (or app-default)
    /// language when the bundle ships it, else the bundle's own first (manifest-order)
    /// language — never a language the bundle lacks, which would degrade bundle-local text
    /// into fallback chains or raw keys.</summary>
    public static string EffectiveLanguage(string bundleId, string? chosen)
    {
        var resolved = Prosary.Models.LanguageCatalog.Resolve(
            chosen ?? Prosary.Models.LanguageCatalog.DefaultSentinel).Code;
        var available = Info(bundleId)?.Languages ?? [];
        if (available.Count == 0) return resolved;
        foreach (var code in LanguageCatalog.FallbackChain(resolved))
        {
            if (available.Contains(code))
            {
                return code == LanguageCatalog.BaseLanguage(resolved) ? resolved : code;
            }
        }

        return available[0];
    }

    public sealed class InstallException : Exception
    {
        public InstallException(string message) : base(message)
        {
        }
    }

    /// <summary>Imports a user-provided bundle: validates it (readable zip, parseable manifest +
    /// devotion.json, content for every declared language, not a builtin-kind pack, no id
    /// collision), copies it into <see cref="InstalledPacksDirectory"/>, and loads it live.
    /// Returns the installed bundle id.</summary>
    public static string InstallPack(byte[] bytes)
    {
        PackManifest manifest;
        try
        {
            ValidateArchiveLength(bytes.LongLength);
            using var probe = new ZipArchive(new MemoryStream(bytes), ZipArchiveMode.Read);
            var entries = ValidateArchive(probe);
            var manifestEntry = entries.GetValueOrDefault("manifest.json")
                ?? throw new InstallException("This file is not a readable .prosaryprayer bundle.");
            manifest = Deserialize<PackManifest>(manifestEntry)
                ?? throw new InstallException("This file is not a readable .prosaryprayer bundle.");
            if (!IsValidBundleId(manifest.Id))
            {
                throw new InstallException("This file is not a readable .prosaryprayer bundle.");
            }

            var devotionEntry = entries.GetValueOrDefault("devotion.json");
            if (devotionEntry is null || manifest.BuiltinKind is not null
                || Deserialize<CustomDevotionDefinition>(devotionEntry) is null)
            {
                throw new InstallException("This bundle does not contain a devotion.");
            }

            foreach (var language in manifest.Languages)
            {
                var contentEntry = entries.GetValueOrDefault($"content/{language}.json")
                    ?? throw new InstallException("This file is not a readable .prosaryprayer bundle.");
                _ = Deserialize<PackContent>(contentEntry)
                    ?? throw new InstallException("This file is not a readable .prosaryprayer bundle.");
            }
        }
        catch (Exception e) when (e is not InstallException)
        {
            throw new InstallException("This file is not a readable .prosaryprayer bundle.");
        }

        if (InfoByBundle.ContainsKey(manifest.Id))
        {
            throw new InstallException($"A devotion named \"{manifest.Id}\" is already installed.");
        }

        var directory = InstalledPacksDirectory
            ?? throw new InstallException("This file is not a readable .prosaryprayer bundle.");
        Directory.CreateDirectory(directory);
        var destination = Path.Combine(directory, $"{manifest.Id}.prosaryprayer");
        File.WriteAllBytes(destination, bytes);
        using (var stream = File.OpenRead(destination))
        {
            Load(stream);
        }

        InstalledIds.Add(manifest.Id);
        PackSourceByBundle[manifest.Id] = () => File.OpenRead(destination);
        return manifest.Id;
    }

    /// <summary>Deletes an installed bundle's file and unregisters its devotion. Shared text
    /// overrides remain until the next launch, matching the existing merge semantics; lazy image
    /// locations are removed immediately so they never retain a dead pack source.</summary>
    public static void RemoveInstalledPack(string id)
    {
        if (!IsValidBundleId(id) || !InstalledIds.Contains(id)) return;
        if (InstalledPacksDirectory is { } directory)
        {
            var path = Path.Combine(directory, $"{id}.prosaryprayer");
            if (File.Exists(path)) File.Delete(path);
        }

        InstalledIds.Remove(id);
        OrderedCustomIds.Remove(id);
        DefinitionByBundle.Remove(id);
        InfoByBundle.Remove(id);
        OptionsByBundle.Remove(id);
        AudioTracksByBundle.Remove(id);
        RawContentByBundle.Remove(id);
        TransliterationsByBundle.Remove(id);
        PackSourceByBundle.Remove(id);

        foreach (var (imageKey, locations) in ImageLocationsByKey.ToList())
        {
            if (locations.RemoveAll(location => location.BundleId == id) == 0) continue;
            if (locations.Count == 0) ImageLocationsByKey.Remove(imageKey);
            ExtractedImageUris.Remove(imageKey);
        }
    }

    /// <summary>The options a bundle's <c>options.json</c> declares, in authored order (the
    /// editor's display order). Empty for bundles without one.</summary>
    public static IReadOnlyList<CustomDevotionOption> Options(string bundleId) =>
        OptionsByBundle.TryGetValue(bundleId, out var options) ? options : [];

    /// <summary>Every loaded bundle id that has a <c>devotion.json</c> — i.e. every generic
    /// devotion discovered at load time, in pack-load order, without hardcoding devotion names
    /// anywhere in view code. A snapshot, not the live list — a caller iterating while an
    /// install/remove mutates the store (tests; a future background install) must not throw.</summary>
    public static IReadOnlyList<string> CustomDevotionIds() => OrderedCustomIds.ToList();

    public static CustomDevotionInfo? Info(string bundleId) =>
        InfoByBundle.TryGetValue(bundleId, out var info) ? info : null;

    /// <summary>The narrated recordings a bundle's <c>audio.json</c> declares, in authored order.
    /// Empty for bundles without audio (see Shared/ARCHITECTURE.markdown's "Audio").</summary>
    public static IReadOnlyList<DevotionAudioTrack> AudioTracks(string bundleId) =>
        AudioTracksByBundle.TryGetValue(bundleId, out var tracks) ? tracks : [];

    /// <summary>Content identity for a declared recording, obtained from the ZIP directory
    /// without inflating the entry. Extracted-audio filenames include it so a same-id pack
    /// replacement cannot reuse stale bytes.</summary>
    public static string? AudioCacheKey(string bundleId, string file)
    {
        if (!AudioTracksByBundle.TryGetValue(bundleId, out var tracks) || tracks.All(t => t.File != file))
        {
            return null;
        }

        return TryReadPackEntry(
            new PackEntryLocation(bundleId, file),
            MaxAudioEntryBytes,
            entry => $"{entry.Crc32:x8}-{entry.Length}",
            out string key)
            ? key
            : null;
    }

    /// <summary>The raw Ogg Opus bytes of one of a bundle's *declared* audio files
    /// (<see cref="DevotionAudioTrack.File"/>), re-read from the pack on demand. Null for a file
    /// no track declares. Kept as a byte-level compatibility/test seam; playback uses
    /// <see cref="ExtractAudioFile"/> so a full recording is never materialized in memory.</summary>
    public static byte[]? AudioData(string bundleId, string file)
    {
        if (!AudioTracksByBundle.TryGetValue(bundleId, out var tracks) || tracks.All(t => t.File != file))
        {
            return null;
        }
        return TryReadPackEntry(
            new PackEntryLocation(bundleId, file),
            MaxAudioEntryBytes,
            entry => ReadAllBytes(entry, MaxAudioEntryBytes),
            out byte[] data)
            ? data
            : null;
    }

    /// <summary>Streams one declared Ogg Opus file from its pack to <paramref name="path"/>.
    /// Unlike <see cref="AudioData"/>, this keeps a full recording out of managed memory and is
    /// therefore the path used by the player.</summary>
    public static bool ExtractAudioFile(string bundleId, string file, string path)
    {
        if (!AudioTracksByBundle.TryGetValue(bundleId, out var tracks) || tracks.All(t => t.File != file))
        {
            return false;
        }

        return TryCopyPackEntry(new PackEntryLocation(bundleId, file), path, MaxAudioEntryBytes);
    }

    /// <summary>Resolves a <c>devotion.json</c> <c>bodyKey</c>/<c>titleKey</c>: bundle content in
    /// the requested code and its base language first; then the shared prayer table for shared
    /// keys; then bundle content through the user's language precedence; finally the raw key.</summary>
    /// <summary>The v0.7 reading aid: this key's text transliterated into another script, if
    /// the bundle's language file carries one. No fallback chain — a transliteration belongs
    /// to exactly the language it transliterates.</summary>
    public static string? Transliteration(string bundleId, string? languageCode, string key)
    {
        if (key == "signumCrucis" && languageCode is not null
            && (LanguageCatalog.BaseLanguage(languageCode) ?? languageCode) == "arc"
            && AppSettings.UsesSystemWideAramaicSignOfCrossForm
            && AppSettings.AramaicSignOfCrossForm == AppSettings.AramaicSignOfCrossFormB
            && TransliterationsByBundle.TryGetValue("rosary", out var rosaryLanguages)
            && rosaryLanguages.TryGetValue("arc", out var aramaic)
            && aramaic.TryGetValue("signumCrucisFormB", out var formBText))
        {
            return formBText;
        }
        return languageCode is not null
            && TransliterationsByBundle.TryGetValue(bundleId, out var byLanguage)
            && byLanguage.TryGetValue(languageCode, out var map)
            && map.TryGetValue(key, out var text)
            ? text
            : null;
    }

    public static string ResolveBodyText(string bundleId, string? languageCode, string key)
    {
        if (languageCode == "he-x-gamliel" && key == "paterNosterTitle") return "תפילת האדון";
        if (key == "signumCrucis" && languageCode is not null
            && (LanguageCatalog.BaseLanguage(languageCode) ?? languageCode) == "arc"
            && AppSettings.UsesSystemWideAramaicSignOfCrossForm
            && AppSettings.AramaicSignOfCrossForm == AppSettings.AramaicSignOfCrossFormB
            && RawContentByBundle.TryGetValue("rosary", out var rosaryLanguages)
            && rosaryLanguages.TryGetValue("arc", out var aramaic)
            && aramaic.TryGetValue("signumCrucisFormB", out var formBText))
        {
            return formBText;
        }
        if (RawContentByBundle.TryGetValue(bundleId, out var byLanguage))
        {
            var chain = LanguageCatalog.FallbackChain(languageCode);
            var requested = chain.FirstOrDefault() ?? LanguageCatalog.DefaultCode;
            var requestedCodes = new[] { requested, LanguageCatalog.BaseLanguage(requested) }
                .Where(code => code is not null).Cast<string>().Distinct().ToList();
            foreach (var code in requestedCodes)
            {
                if (byLanguage.TryGetValue(code, out var content) && content.TryGetValue(key, out var text)) return text;
            }

            if (key == "signumCrucisFormB")
            {
                return PrayerTranslations.Get(languageCode, PrayerKey.SignumCrucis);
            }

            var sharedPascalKey = ToPascalCase(key);
            var shared = PrayerTranslations.Get(languageCode, sharedPascalKey);
            if (shared != sharedPascalKey) return shared;

            foreach (var code in chain.Where(code => !requestedCodes.Contains(code)))
            {
                if (byLanguage.TryGetValue(code, out var content) && content.TryGetValue(key, out var text)) return text;
            }
        }

        if (key == "signumCrucisFormB")
        {
            return PrayerTranslations.Get(languageCode, PrayerKey.SignumCrucis);
        }

        var pascalKey = ToPascalCase(key);
        var resolved = PrayerTranslations.Get(languageCode, pascalKey);
        // PrayerTranslations' raw-key last resort returns the PascalCased form it was given —
        // surface the original key instead, matching iOS/Android.
        return resolved == pascalKey ? key : resolved;
    }

    /// <summary>Resolves a bundle key as display chrome. The canonical body resolver remains
    /// untouched so pointed Hebrew prayer and Scripture text is never rewritten.</summary>
    public static string ResolveDisplayText(string bundleId, string? languageCode, string key) =>
        HebrewDisplayText.WithoutMarks(ResolveBodyText(bundleId, languageCode, key));

    /// <summary>Extracts a pack-provided image to a cache file on first request — WinUI's
    /// <c>Image.Source</c> needs a file/ms-appx URI, not raw bytes — and returns its <c>file://</c>
    /// URI. The encoded JPEG is copied straight from the zip entry rather than retained in the
    /// process-wide store.</summary>
    public static string? ImageFileUri(string imageKey)
    {
        if (ExtractedImageUris.TryGetValue(imageKey, out var cachedUri)) return cachedUri;

        if (!ImageLocationsByKey.TryGetValue(imageKey, out var locations)) return null;
        if (Path.GetFileName(imageKey) != imageKey) return null;

        try
        {
            var directory = ImageCacheDirectory();
            if (directory is null) return null;
            Directory.CreateDirectory(directory);
            // The source revision is part of the filename. BitmapImage caches by URI and may
            // keep a file open, so overwriting one key-stable path would either show stale pixels
            // or fail while an earlier frame still owns the file.
            for (var index = locations.Count - 1; index >= 0; index--)
            {
                var location = locations[index];
                var path = Path.Combine(directory, $"{imageKey}-{location.Revision:x}.jpg");
                // A revisioned final path can only be created by the atomic writer below. Reuse
                // it when an overridden source becomes active again: WinUI may still hold the
                // original BitmapImage file open, which would make even an atomic replacement
                // fail despite the existing bytes already being exactly the ones we need.
                if (!File.Exists(path)
                    && !TryCopyPackEntry(location, path, MaxImageEntryBytes)) continue;

                var uri = new Uri(path).AbsoluteUri;
                ExtractedImageUris[imageKey] = uri;
                return uri;
            }
            return null;
        }
        catch (Exception error)
        {
            System.Diagnostics.Debug.WriteLine($"[PrayerPackStore] image extract failed: {error}");
            return null;
        }
    }

    /// <summary>Resolves an image from its portable pack, with the only loose raster in the app
    /// (the tiny generated placeholder) as a graceful fallback.</summary>
    public static string ImageFileUriOrPlaceholder(string imageKey) =>
        ImageFileUri(imageKey) ?? "ms-appx:///Assets/Images/cross_placeholder.png";

    /// <summary><paramref name="openPack"/> returns a fresh, readable stream for a named pack's
    /// bytes (e.g. a file under the app's install directory), or null if that pack isn't
    /// available. Safe to call more than once; only the first call does any work.</summary>
    private static readonly object InitLock = new();

    public static void Initialize(Func<string, Stream?> openPack)
    {
        // The lock (and setting _didLoad only after the loop) makes concurrent callers block
        // until loading has fully finished rather than returning against a half-loaded store —
        // the app initializes once at startup, but xunit runs test classes in parallel and
        // every fixture calls this.
        lock (InitLock)
        {
            if (_didLoad) return;

            // Image files exist only to bridge zip entries to WinUI's URI-based Image.Source.
            // They have no cross-launch value and would otherwise accumulate as users install
            // and remove packs, so discard the previous process's disposable cache before any
            // page can hold one of its URIs.
            ClearPriorImageCache();

            foreach (var packName in PackNames)
            {
                using var stream = openPack(packName);
                if (stream is null) continue;
                try
                {
                    // openPack is documented re-callable with a fresh stream, which is what lets
                    // audio bytes be re-read on demand instead of cached at load — see AudioData.
                    if (Load(stream) is { } id)
                    {
                        PackSourceByBundle[id] = () => openPack(packName);
                    }
                }
                catch
                {
                    // Corrupt/unreadable pack — leave overrides empty for it, fall back to hardcoded content.
                }
            }

            // User-installed bundles load after the built-ins (so shipped content always wins
            // the shared merges) and are skipped on id collision with anything already loaded.
            if (InstalledPacksDirectory is { } directory && Directory.Exists(directory))
            {
                foreach (var path in Directory.GetFiles(directory, "*.prosaryprayer").OrderBy(p => p))
                {
                    var id = Path.GetFileNameWithoutExtension(path);
                    if (InfoByBundle.ContainsKey(id)) continue;
                    try
                    {
                        using var stream = File.OpenRead(path);
                        if (Load(stream) is { } loadedId)
                        {
                            InstalledIds.Add(loadedId);
                            PackSourceByBundle[loadedId] = () => File.OpenRead(path);
                        }
                    }
                    catch
                    {
                        // Corrupt installed pack — ignored, same as a corrupt built-in.
                    }
                }
            }

            _didLoad = true;
        }
    }

    /// <summary>Returns the loaded bundle's id (null for a zip with no manifest) so callers can
    /// register a re-openable pack source for it — see <see cref="AudioData"/>.</summary>
    private static string? Load(Stream stream)
    {
        using var seekable = PrepareSeekablePack(stream);
        using var archive = new ZipArchive(seekable, ZipArchiveMode.Read);
        // Zip directory records (e.g. a bare "images/" entry) have no isDirectory flag in
        // System.IO.Compression — the convention is a FullName ending in "/" — and must be
        // excluded here, not just at each lookup site, or the images/ prefix-stripping loop below
        // would try to slice a name shorter than the prefix+suffix it's stripping.
        var entries = ValidateArchive(archive);

        if (!entries.TryGetValue("manifest.json", out var manifestEntry)) return null;
        var manifest = Deserialize<PackManifest>(manifestEntry)
            ?? throw new InvalidDataException("manifest.json did not deserialize");
        if (!IsValidBundleId(manifest.Id))
        {
            throw new InvalidDataException("manifest.json contains an invalid bundle id");
        }

        InfoByBundle[manifest.Id] = new CustomDevotionInfo(
            manifest.DisplayName,
            manifest.Languages,
            manifest.AccentColorHex,
            manifest.AccentColorDarkHex,
            manifest.IconSystemName,
            manifest.IconGlyph,
            manifest.DisplayNameByLanguage ?? new Dictionary<string, string>(),
            manifest.ReminderBody ?? new Dictionary<string, string>(),
            manifest.ReminderPresetHours,
            manifest.ReminderPresetFooter ?? new Dictionary<string, string>(),
            manifest.Tags ?? []);

        // Declared languages are what the bundle *offers*; any other content/<code>.json it
        // carries is an overlay resolved key by key — how a community variant ("he-x-gamliel")
        // ships its own wording for a few prayers without owing a complete translation.
        var overlayLanguages = entries.Keys
            .Where(name => name.StartsWith("content/", StringComparison.Ordinal) &&
                           name.EndsWith(".json", StringComparison.Ordinal))
            .Select(name => name["content/".Length..^".json".Length])
            .Where(code => !manifest.Languages.Contains(code))
            .ToList();

        foreach (var language in manifest.Languages.Concat(overlayLanguages))
        {
            if (!entries.TryGetValue($"content/{language}.json", out var contentEntry)) continue;
            var content = Deserialize<PackContent>(contentEntry)
                ?? throw new InvalidDataException($"content/{language}.json did not deserialize");

            var rawContent = content.Prayers ?? new Dictionary<string, string>();
            if (!RawContentByBundle.TryGetValue(manifest.Id, out var byLanguage))
            {
                byLanguage = new Dictionary<string, Dictionary<string, string>>();
                RawContentByBundle[manifest.Id] = byLanguage;
            }
            byLanguage[language] = rawContent;
            if (content.Transliterations is { Count: > 0 } transliterations)
            {
                if (!TransliterationsByBundle.TryGetValue(manifest.Id, out var translitByLanguage))
                {
                    translitByLanguage = new Dictionary<string, Dictionary<string, string>>();
                    TransliterationsByBundle[manifest.Id] = translitByLanguage;
                }
                translitByLanguage[language] = transliterations;
            }

            var prayers = PrayerOverrides.TryGetValue(language, out var existingPrayers) ? existingPrayers : new Dictionary<string, string>();
            foreach (var (key, text) in rawContent)
            {
                prayers[ToPascalCase(key)] = text;
            }
            PrayerOverrides[language] = prayers;

            // Mysteries merge whenever a bundle ships any — `hasCatalog` strictly means "has a
            // catalog.json authoring file" (the Rosary), not "may contribute mystery text":
            // generic rosary-type devotions (Seven Sorrows, Franciscan Crown) ship their
            // per-decade texts in the mysteries map without any catalog.json.
            if (content.Mysteries is { Count: > 0 })
            {
                var mysteries = MysteryOverrides.TryGetValue(language, out var existingMysteries)
                    ? existingMysteries
                    : new Dictionary<string, MysteryTextOverride>();
                foreach (var (key, text) in content.Mysteries)
                {
                    if (mysteries.TryGetValue(key, out var earlier))
                    {
                        mysteries[key] = MergeMysteryOverrides(earlier, text);
                    }
                    else
                    {
                        mysteries[key] = text;
                    }
                }
                MysteryOverrides[language] = mysteries;
            }
        }

        if (entries.TryGetValue("devotion.json", out var devotionEntry))
        {
            var definition = Deserialize<CustomDevotionDefinition>(devotionEntry)
                ?? throw new InvalidDataException("devotion.json did not deserialize");
            DefinitionByBundle[manifest.Id] = definition;
            if (manifest.BuiltinKind is null)
            {
                OrderedCustomIds.Add(manifest.Id);
            }
        }

        if (entries.TryGetValue("options.json", out var optionsEntry))
        {
            var packOptions = Deserialize<PackOptions>(optionsEntry)
                ?? throw new InvalidDataException("options.json did not deserialize");
            OptionsByBundle[manifest.Id] = packOptions.Options;
        }

        if (entries.TryGetValue("audio.json", out var audioEntry))
        {
            var packAudio = Deserialize<PackAudio>(audioEntry)
                ?? throw new InvalidDataException("audio.json did not deserialize");
            AudioTracksByBundle[manifest.Id] = packAudio.Tracks;
        }

        foreach (var entry in entries.Values)
        {
            if (entry.FullName.StartsWith("images/", StringComparison.Ordinal)
                && entry.FullName.EndsWith(".jpg", StringComparison.Ordinal))
            {
                var imageKey = entry.FullName["images/".Length..^".jpg".Length];
                if (!ImageLocationsByKey.TryGetValue(imageKey, out var locations))
                {
                    locations = [];
                    ImageLocationsByKey[imageKey] = locations;
                }
                locations.Add(new PackEntryLocation(
                    manifest.Id,
                    entry.FullName,
                    checked(++_nextImageRevision)));
                ExtractedImageUris.Remove(imageKey);
            }
        }

        return manifest.Id;
    }

    /// <summary>Combines two pack layers without a sparse later layer blanking fields supplied
    /// earlier. Description and transliteration form a provenance pair: replacing the former
    /// also replaces (or deliberately removes) the latter, while a transliteration without its
    /// own description can never attach itself to unrelated text.</summary>
    internal static MysteryTextOverride MergeMysteryOverrides(
        MysteryTextOverride earlier,
        MysteryTextOverride later) =>
        new(
            later.Title ?? earlier.Title,
            later.Fruit ?? earlier.Fruit,
            later.Description ?? earlier.Description,
            later.Description is not null
                ? later.TransliteratedDescription
                : earlier.TransliteratedDescription);

    /// <summary>Bundle content JSON keys are the camelCase form used across every platform's
    /// schema (e.g. "oratioFatimae"); <see cref="PrayerKey"/>'s constants are the same names
    /// PascalCased (OratioFatimae).</summary>
    private static string ToPascalCase(string jsonKey) =>
        jsonKey.Length == 0 ? jsonKey : char.ToUpperInvariant(jsonKey[0]) + jsonKey[1..];

    /// <summary>Bundle ids become filenames on every platform. Restrict them to one portable
    /// ASCII component while continuing to support dotted repository ids.</summary>
    private static bool IsValidBundleId(string id) =>
        !string.IsNullOrEmpty(id)
        && char.IsAsciiLetterOrDigit(id[0])
        && id.All(character => char.IsAsciiLetterOrDigit(character) || character is '.' or '_' or '-');

    internal static void ValidateArchiveLength(long length)
    {
        if (length is < 0 or > MaxPackArchiveBytes)
        {
            throw new InvalidDataException("Prayer pack is larger than the supported archive limit.");
        }
    }

    internal static void ValidateInstallArchiveLength(long length)
    {
        try
        {
            ValidateArchiveLength(length);
        }
        catch (InvalidDataException)
        {
            throw new InstallException(UnreadablePackMessage);
        }
    }

    /// <summary>Reads a picked or downloaded archive with the same raw-size ceiling enforced by
    /// <see cref="InstallPack"/>. Seekable inputs are rejected from metadata before the first
    /// payload allocation; known lengths must also match the complete body. Unknown-length
    /// network streams spool to a disposable file so only the final, exactly-sized byte array is
    /// resident in managed memory.</summary>
    internal static async Task<byte[]> ReadInstallBytesAsync(
        Stream input,
        CancellationToken cancellationToken = default,
        long? expectedLength = null,
        string? temporaryDirectory = null)
    {
        if (input.CanSeek)
        {
            var remainingLength = input.Length - input.Position;
            if (expectedLength is { } declaredLength && declaredLength != remainingLength)
            {
                throw new InstallException(UnreadablePackMessage);
            }
            expectedLength = remainingLength;
        }

        if (expectedLength is { } declaredLength)
        {
            return await ReadExactArchiveBytesAsync(input, declaredLength, cancellationToken);
        }

        var spoolDirectory = temporaryDirectory ?? Path.GetTempPath();
        Directory.CreateDirectory(spoolDirectory);
        var spoolPath = Path.Combine(spoolDirectory, $"prosary-import-{Guid.NewGuid():N}.tmp");
        try
        {
            await using var spool = new FileStream(
                spoolPath,
                new FileStreamOptions
                {
                    Mode = FileMode.CreateNew,
                    Access = FileAccess.ReadWrite,
                    Share = FileShare.None,
                    BufferSize = 32 * 1024,
                    Options = FileOptions.Asynchronous | FileOptions.SequentialScan |
                              FileOptions.DeleteOnClose,
                });
            var buffer = new byte[32 * 1024];
            long total = 0;
            while (true)
            {
                var count = await input.ReadAsync(buffer.AsMemory(), cancellationToken);
                if (count == 0) break;
                if (total > MaxPackArchiveBytes - count)
                {
                    throw new InstallException(UnreadablePackMessage);
                }
                await spool.WriteAsync(buffer.AsMemory(0, count), cancellationToken);
                total += count;
            }

            await spool.FlushAsync(cancellationToken);
            spool.Position = 0;
            return await ReadExactArchiveBytesAsync(spool, total, cancellationToken);
        }
        finally
        {
            try
            {
                if (File.Exists(spoolPath)) File.Delete(spoolPath);
            }
            catch (Exception error) when (error is IOException or UnauthorizedAccessException)
            {
                System.Diagnostics.Debug.WriteLine($"[PrayerPackStore] import spool cleanup failed: {error}");
            }
        }
    }

    private static async Task<byte[]> ReadExactArchiveBytesAsync(
        Stream input,
        long expectedLength,
        CancellationToken cancellationToken)
    {
        ValidateInstallArchiveLength(expectedLength);
        var data = GC.AllocateUninitializedArray<byte>(checked((int)expectedLength));
        try
        {
            await input.ReadExactlyAsync(data.AsMemory(), cancellationToken);
        }
        catch (EndOfStreamException)
        {
            throw new InstallException(UnreadablePackMessage);
        }

        var probe = new byte[1];
        if (await input.ReadAsync(probe.AsMemory(), cancellationToken) != 0)
        {
            throw new InstallException(UnreadablePackMessage);
        }
        return data;
    }

    /// <summary>Validates every central-directory declaration before any entry is inflated or an
    /// output-sized array is allocated. Unknown payloads remain ignored, but the raw archive and
    /// entry count still bound the amount of metadata they can contribute.</summary>
    private static Dictionary<string, ZipArchiveEntry> ValidateArchive(ZipArchive archive)
    {
        ValidateEntryCount(archive.Entries.Count);

        var files = new Dictionary<string, ZipArchiveEntry>(StringComparer.Ordinal);
        var seenNames = new HashSet<string>(StringComparer.Ordinal);
        long controlBytes = 0;

        foreach (var entry in archive.Entries)
        {
            if (!seenNames.Add(entry.FullName))
            {
                throw new InvalidDataException("Prayer pack contains duplicate entries.");
            }

            ValidateEntryDeclaration(entry.FullName, entry.Length, entry.CompressedLength);

            if (IsControlEntry(entry.FullName))
            {
                if (entry.Length > MaxControlTotalBytes - controlBytes)
                {
                    throw new InvalidDataException("Prayer-pack metadata is too large.");
                }
                controlBytes += entry.Length;
            }

            if (!entry.FullName.EndsWith('/'))
            {
                files.Add(entry.FullName, entry);
            }
        }

        return files;
    }

    internal static void ValidateEntryCount(int count)
    {
        if (count is < 0 or > MaxPackEntryCount)
        {
            throw new InvalidDataException("Prayer pack contains too many entries.");
        }
    }

    internal static void ValidateEntryDeclaration(
        string name,
        long length,
        long compressedLength)
    {
        if (EntryLimit(name) is { } maxBytes)
        {
            ValidateDeclaredLength(name, length, compressedLength, maxBytes);
        }
    }

    private static long? EntryLimit(string name)
    {
        if (IsControlEntry(name)) return MaxControlEntryBytes;
        if (name.StartsWith("images/", StringComparison.Ordinal)) return MaxImageEntryBytes;
        if (name.StartsWith("audio/", StringComparison.Ordinal)) return MaxAudioEntryBytes;
        return null;
    }

    private static bool IsControlEntry(string name) =>
        name is "manifest.json" or "devotion.json" or "catalog.json" or "options.json" or "audio.json"
        || (name.StartsWith("content/", StringComparison.Ordinal)
            && name.EndsWith(".json", StringComparison.Ordinal));

    private static void ValidateEntryLength(ZipArchiveEntry entry, long maxBytes)
        => ValidateDeclaredLength(entry.FullName, entry.Length, entry.CompressedLength, maxBytes);

    private static void ValidateDeclaredLength(
        string name,
        long length,
        long compressedLength,
        long maxBytes)
    {
        if (length < 0 || compressedLength < 0
            || length > maxBytes || compressedLength > maxBytes)
        {
            throw new InvalidDataException($"Prayer-pack entry {name} is too large.");
        }
    }

    private static byte[] ReadAllBytes(ZipArchiveEntry entry, long maxBytes)
    {
        ValidateEntryLength(entry, maxBytes);
        using var entryStream = entry.Open();
        var data = GC.AllocateUninitializedArray<byte>(checked((int)entry.Length));
        entryStream.ReadExactly(data);
        if (entryStream.ReadByte() != -1)
        {
            throw new InvalidDataException(
                $"Prayer-pack entry {entry.FullName} expands beyond its declared size.");
        }
        return data;
    }

    private static T? Deserialize<T>(ZipArchiveEntry entry) =>
        JsonSerializer.Deserialize<T>(ReadAllBytes(entry, MaxControlEntryBytes), JsonOptions);

    private static bool TryReadPackEntry<T>(
        PackEntryLocation location,
        long maxBytes,
        Func<ZipArchiveEntry, T> read,
        out T result)
    {
        result = default!;
        if (!PackSourceByBundle.TryGetValue(location.BundleId, out var openPack)) return false;

        try
        {
            using var stream = openPack();
            if (stream is null) return false;
            using var seekable = PrepareSeekablePack(stream);
            using var archive = new ZipArchive(seekable, ZipArchiveMode.Read);
            var entries = ValidateArchive(archive);
            if (!entries.TryGetValue(location.EntryName, out var entry)) return false;
            ValidateEntryLength(entry, maxBytes);
            result = read(entry);
            return true;
        }
        catch (Exception error) when (error is IOException or InvalidDataException or UnauthorizedAccessException)
        {
            System.Diagnostics.Debug.WriteLine($"[PrayerPackStore] pack entry read failed: {error}");
            return false;
        }
    }

    private static bool TryCopyPackEntry(PackEntryLocation location, string path, long maxBytes)
    {
        return TryReadPackEntry(location, maxBytes, entry =>
        {
            using var input = entry.Open();
            return TryWriteFileAtomically(input, path, entry.Length, maxBytes);
        }, out bool copied) && copied;
    }

    /// <summary>Copies a stream through a sibling temporary file so a failed read, decompression,
    /// or disk write can never leave a truncated cache entry that later callers mistake for a
    /// complete image or recording.</summary>
    internal static bool TryWriteFileAtomically(
        Stream input,
        string path,
        long? expectedLength = null,
        long maxBytes = long.MaxValue)
    {
        var directory = Path.GetDirectoryName(path);
        if (string.IsNullOrEmpty(directory)) return false;

        Directory.CreateDirectory(directory);
        var temporaryPath = Path.Combine(
            directory,
            $".{Path.GetFileName(path)}.{Guid.NewGuid():N}.tmp");

        try
        {
            using (var output = new FileStream(
                       temporaryPath,
                       FileMode.CreateNew,
                       FileAccess.Write,
                       FileShare.None))
            {
                CopyBounded(input, output, maxBytes, expectedLength);
                output.Flush(flushToDisk: true);
            }

            File.Move(temporaryPath, path, overwrite: true);
            return true;
        }
        catch (Exception error) when (
            error is IOException or InvalidDataException or UnauthorizedAccessException)
        {
            System.Diagnostics.Debug.WriteLine($"[PrayerPackStore] atomic cache write failed: {error}");
            return false;
        }
        finally
        {
            try
            {
                if (File.Exists(temporaryPath)) File.Delete(temporaryPath);
            }
            catch (Exception error) when (error is IOException or UnauthorizedAccessException)
            {
                // A stale uniquely named temporary file is never considered a valid cache hit.
                System.Diagnostics.Debug.WriteLine($"[PrayerPackStore] temporary cache cleanup failed: {error}");
            }
        }
    }

    private static long CopyBounded(
        Stream input,
        Stream output,
        long maxBytes,
        long? expectedLength = null)
    {
        if (maxBytes < 0 || expectedLength is < 0 || expectedLength > maxBytes)
        {
            throw new InvalidDataException("Prayer-pack stream has an invalid size.");
        }

        var hardLimit = expectedLength ?? maxBytes;
        var buffer = new byte[32 * 1024];
        long written = 0;
        while (true)
        {
            var remaining = hardLimit - written;
            var requested = remaining >= buffer.Length
                ? buffer.Length
                : checked((int)remaining + 1);
            var count = input.Read(buffer, 0, requested);
            if (count == 0) break;
            if (count < 0 || count > remaining)
            {
                throw new InvalidDataException("Prayer-pack stream exceeds its declared size.");
            }
            output.Write(buffer, 0, count);
            written += count;
        }

        if (expectedLength is { } expected && written != expected)
        {
            throw new InvalidDataException("Prayer-pack stream is shorter than its declared size.");
        }
        return written;
    }

    internal static void ClearPriorImageCache()
    {
        ExtractedImageUris.Clear();
        try
        {
            var root = ImageCacheRootDirectory();
            if (root is null) return;
            if (Directory.Exists(root)) Directory.Delete(root, recursive: true);
        }
        catch (Exception error)
        {
            // LocalCacheFolder is disposable. A locked/temporarily unavailable old cache is
            // harmless; the process-unique child name keeps its stale bytes unreachable.
            System.Diagnostics.Debug.WriteLine($"[PrayerPackStore] old image-cache cleanup failed: {error}");
        }
    }

    private static string? ImageCacheDirectory()
    {
        var root = ImageCacheRootDirectory();
        return root is null ? null : Path.Combine(root, ImageCacheSessionName);
    }

    private static string? ImageCacheRootDirectory()
    {
        if (_imageCacheDirectoryOverride is { Length: > 0 } directory) return directory;
        try
        {
            return Path.Combine(ApplicationData.Current.LocalCacheFolder.Path, "PrayerPackImages");
        }
        catch
        {
            return null;
        }
    }

    private static Stream PrepareSeekablePack(Stream stream)
    {
        if (!stream.CanSeek) return CopyToMemory(stream);
        ValidateArchiveLength(stream.Length);
        return stream;
    }

    private static MemoryStream CopyToMemory(Stream stream)
    {
        var memory = new MemoryStream();
        try
        {
            CopyBounded(stream, memory, MaxPackArchiveBytes);
            memory.Position = 0;
            return memory;
        }
        catch
        {
            memory.Dispose();
            throw;
        }
    }

    private sealed record PackManifest(
        string Id,
        // Set ("rosary") when this bundle's devotion.json backs a dedicated PrayerKind rather
        // than a generic Custom devotion — the definition loads, but the bundle stays out of
        // CustomDevotionIds() so the devotion directory does not list it twice.
        string? BuiltinKind,
        string DisplayName,
        List<string> Languages,
        bool HasCatalog,
        string? AccentColorHex = null,
        string? AccentColorDarkHex = null,
        string? IconSystemName = null,
        // One grapheme (letter or emoji) drawn instead of IconSystemName — Compose's "your
        // own" icon (v0.7, Gamaliel item 6).
        string? IconGlyph = null,
        Dictionary<string, string>? DisplayNameByLanguage = null,
        Dictionary<string, string>? ReminderBody = null,
        List<int>? ReminderPresetHours = null,
        Dictionary<string, string>? ReminderPresetFooter = null,
        List<string>? Tags = null);

    private sealed record PackEntryLocation(string BundleId, string EntryName, long Revision = 0);

    private sealed record PackContent(
        Dictionary<string, string>? Prayers,
        Dictionary<string, MysteryTextOverride>? Mysteries,
        // Optional reading aid (v0.7): prayer key -> the same text in another script.
        Dictionary<string, string>? Transliterations = null);

    private sealed record PackOptions(List<CustomDevotionOption> Options);

    private sealed record PackAudio(List<DevotionAudioTrack> Tracks);
}

/// <summary>One narrated recording a bundle declares in its <c>audio.json</c> (an optional
/// bundle file, staged by both packers like options.json — see Shared/ARCHITECTURE.markdown's
/// "Audio"). AudioPlaybackService plays these through the prayer flow's transport bar —
/// metadata loads eagerly here, bytes are served on demand via
/// <see cref="PrayerPackStore.AudioData"/> and extracted to a cache file at load. Files are Ogg Opus (RFC 7845, <c>.opus</c>) under the
/// bundle's <c>audio/</c> directory; structure is enforced at authoring time by
/// <c>Shared/tools/validate-devotion.py</c>.</summary>
public sealed record DevotionAudioTrack(
    // Unique within the bundle — what a persisted playback position would key against (persistence itself is future work).
    string Id,
    // The single language this recording is in (one of the manifest's languages).
    string Language,
    // Bundle-relative path, always audio/<name>.opus.
    string File,
    // The steps-type variant this recording follows (a traditional vs. scriptural Stations
    // recording differ). Null for single-form devotions.
    string? VariantId = null,
    // English UI label; NameByLanguage overrides it per UI localization. Null = platforms label
    // the track by its language.
    string? Name = null,
    Dictionary<string, string>? NameByLanguage = null,
    List<DevotionAudioTrack.Chapter>? Chapters = null)
{
    /// <summary>One seek point. <see cref="Start"/> is seconds from the track's beginning (the
    /// first chapter starts at 0, starts strictly increase); <see cref="Title"/> XOR
    /// <see cref="TitleKey"/> per the step-entry convention (<see cref="TitleKey"/> resolves
    /// through the track language's ordinary content chain); <see cref="StepIndex"/> is an
    /// *advisory* link into the built default-options step sequence — the built sequence is
    /// option/calendar-dependent, so the playback UI treats it as a step-syncing hint,
    /// never an invariant.</summary>
    public sealed record Chapter(
        double Start,
        string? Title = null,
        string? TitleKey = null,
        int? StepIndex = null);

    public string? LocalizedName => HebrewDisplayText.WithoutMarksOrNull(
        NameByLanguage?.GetValueOrDefault(System.Globalization.CultureInfo.CurrentUICulture.TwoLetterISOLanguageName)
        ?? Name);
}

/// <summary>One entry in a generic devotion's <c>devotion.json</c> — a step of the flat "steps"
/// type, an opening/closing step of the "rosary" type, or (closing only) a
/// <see cref="Kind"/>-tagged special step. <see cref="Title"/> is a literal display string (the
/// app-wide convention that step titles are English-only UI labels); <see cref="TitleKey"/> is
/// the alternative for devotions whose step titles are themselves translated content (e.g. the
/// Stations' station names). <see cref="Repeat"/> expands into n steps titled "Title (h of n)";
/// paired <see cref="CounterIndex"/>/<see cref="CounterTotal"/> adds that suffix to one authored
/// entry without repeating it.</summary>
public sealed record CustomDevotionStep(
    string? Title = null,
    string? TitleKey = null,
    string? Subtitle = null,
    string? BodyKey = null,
    // Resolved like BodyKey; emitted as the step's regular-typeface acclamation above the
    // body (the Stations' versicle/response).
    string? AcclamationKey = null,
    string? ImageKey = null,
    int? Repeat = null,
    int? CounterIndex = null,
    int? CounterTotal = null,
    bool? IsScripture = null,
    // Per-language override of IsScripture — for bodies that are quoted scripture in some
    // languages but composed prose in others (the traditional Stations: Liguori meditations in
    // la/en, scripture meditations in ar/he/ru/tl).
    Dictionary<string, bool>? IsScriptureByLanguage = null,
    string? If = null,
    // Like TitleKey for the subtitle — for subtitles that are themselves translated content
    // (the Rosary's opening Hail Marys "for Faith/Hope/Charity"). Mutually exclusive with the
    // literal Subtitle.
    string? SubtitleKey = null,
    CustomDevotionStep.SpecialKind? Kind = null,
    // For SpecialKind.MarianAntiphon: the choice option whose value names the antiphon to
    // build ("seasonal" resolves via the liturgical calendar, "none" drops the step).
    string? OptionKey = null)
{
    public enum SpecialKind
    {
        /// <summary>The seasonal Marian antiphon (Franciscan Crown) — calendar-dependent, so it
        /// stays runtime-composed by the engine's shared antiphon builder rather than
        /// data-driven.</summary>
        SeasonalMarianAntiphon,

        /// <summary>An option-selected Marian antiphon (the Rosary) — <see cref="OptionKey"/>
        /// names a choice option whose cases are antiphon ids plus "seasonal" and "none".</summary>
        MarianAntiphon,
    }
}

/// <summary>One user-configurable setting a bundle declares in its <c>options.json</c> — a
/// toggle or a multi-case choice. Entry-level <c>"if"</c> expressions gate steps on the
/// resulting values (<see cref="CustomDevotionStep.If"/>); the favorite's choices persist in
/// <c>Prayer.CustomOptions</c> (only overrides — an absent key means this option's
/// <see cref="DefaultValue"/>). Structure is enforced at authoring time by
/// <c>Shared/tools/validate-devotion.py</c>.</summary>
public sealed record CustomDevotionOption(
    string Key,
    CustomDevotionOption.OptionKind Kind,
    string Name,
    Dictionary<string, string>? NameByLanguage = null,
    JsonElement Default = default,
    List<CustomDevotionOption.Case>? Cases = null)
{
    public enum OptionKind
    {
        Toggle,
        Choice,
    }

    public sealed record Case(
        string Id,
        string Name,
        Dictionary<string, string>? NameByLanguage = null)
    {
        public string LocalizedName => HebrewDisplayText.WithoutMarks(
            NameByLanguage?.GetValueOrDefault(System.Globalization.CultureInfo.CurrentUICulture.TwoLetterISOLanguageName)
            ?? Name);
    }

    /// <summary>Canonical string form of the authored <c>default</c> (a JSON boolean for a
    /// toggle, a case-id string for a choice): "true"/"false" or the case id — the same
    /// encoding <c>Prayer.CustomOptions</c> stores.</summary>
    public string DefaultValue => Default.ValueKind switch
    {
        JsonValueKind.True => "true",
        JsonValueKind.False => "false",
        JsonValueKind.String => Default.GetString() ?? string.Empty,
        _ => string.Empty,
    };

    public string LocalizedName => HebrewDisplayText.WithoutMarks(
        NameByLanguage?.GetValueOrDefault(System.Globalization.CultureInfo.CurrentUICulture.TwoLetterISOLanguageName)
        ?? Name);
}

/// <summary>Parsed <c>devotion.json</c> — the complete structural description of a generic
/// devotion. Field validity per type is enforced at authoring time by
/// <c>Shared/tools/validate-devotion.py</c>; the decoder is deliberately lenient (all optionals)
/// so the engine can switch on <see cref="Type"/> alone.</summary>
public sealed record CustomDevotionDefinition(
    CustomDevotionDefinition.DevotionType Type,
    // days type
    List<CustomDevotionDefinition.Day>? Days = null,
    // How the days relate: a series is worked through on consecutive days (a novena, a triduum,
    // a 33-day consecration) and gets a tracked run; "free" days are a set to pick from, like a
    // prayer for each day of the week. Null means series.
    string? DayProgression = null,
    // Advisory "HH:mm" for the daily reminder; the user's own times always win.
    string? SuggestedReminderTime = null,
    // Annual "MM-DD" the series traditionally begins on, so a pinned devotion can announce
    // itself before its first day. Advisory — starting it any day always works.
    string? SuggestedStart = null,
    // A devotion to offer once the last day is prayed. May name one this device does not
    // have — resolved at runtime and quietly dropped when it cannot be.
    string? SuggestedNext = null,
    // steps type
    List<CustomDevotionStep>? Steps = null,
    // Whole-sequence swap during Eastertide (the Angelus → Regina Caeli substitution).
    List<CustomDevotionStep>? EastertideSteps = null,
    // Alternate step-sets (steps type only), mutually exclusive with Steps. Null for
    // single-form devotions; the first variant is the default.
    List<CustomDevotionDefinition.Variant>? Variants = null,
    // rosary type
    List<CustomDevotionStep>? Opening = null,
    CustomDevotionDefinition.DecadesDefinition? Decades = null,
    List<CustomDevotionStep>? Closing = null,
    bool? HasClosingCross = null)
{
    /// <summary>One named alternate step-set of a steps-type devotion (e.g. the Stations'
    /// traditional vs. scriptural forms). Name is the English UI label (the app-wide
    /// step-title convention); NameByLanguage overrides it per UI localization, mirroring the
    /// manifest's displayNameByLanguage.</summary>
    public sealed record Variant(
        string Id,
        string Name,
        Dictionary<string, string>? NameByLanguage = null,
        List<CustomDevotionStep>? Steps = null,
        List<CustomDevotionStep>? EastertideSteps = null,
        // Exact prayer-language codes (rites included) whose sessions open in this variant when
        // the favorite carries no explicit choice — the Mission of St. Gamaliel's rite opening
        // the Trisagion in its Syriac form. Exact match only: choosing a rite is deliberate,
        // and the base language keeps the bundle's ordinary (first-variant) default.
        List<string>? DefaultForLanguages = null,
        // rosary type: the same four fields a single-form rosary devotion has.
        List<CustomDevotionStep>? Opening = null,
        DecadesDefinition? Decades = null,
        List<CustomDevotionStep>? Closing = null,
        bool? HasClosingCross = null)
    {
        public string LocalizedName => HebrewDisplayText.WithoutMarks(
            NameByLanguage?.GetValueOrDefault(System.Globalization.CultureInfo.CurrentUICulture.TwoLetterISOLanguageName)
            ?? Name);
    }

    /// <summary>The variant a session with no explicit choice opens in: the explicit
    /// <paramref name="variantId"/> when given, else the variant that names the resolved prayer
    /// language among its DefaultForLanguages, else null — which every resolver reads as the
    /// first variant. All callers that pass a possibly-null variant id route through this so a
    /// rite's native form wins everywhere (engine, variant menu, closing cross) without any
    /// per-rite code.</summary>
    public string? EffectiveVariantId(string? variantId, string? languageCode)
    {
        if (variantId is not null) return variantId;
        if (Variants is not { Count: > 0 } || languageCode is null) return null;
        return Variants.FirstOrDefault(v => v.DefaultForLanguages?.Contains(languageCode) == true)?.Id;
    }

    /// <summary>The step lists to build for <paramref name="variantId"/> — the matching
    /// variant, else the default (first) variant, else the top-level lists (single-form
    /// devotions).</summary>
    public (List<CustomDevotionStep> Steps, List<CustomDevotionStep>? EastertideSteps) ResolvedSteps(string? variantId)
    {
        if (Variants is { Count: > 0 } variants)
        {
            var variant = variants.FirstOrDefault(v => v.Id == variantId) ?? variants[0];
            return (variant.Steps ?? [], variant.EastertideSteps);
        }

        return (Steps ?? [], EastertideSteps);
    }

    /// <summary>One rosary-type form: the matching variant, else the default (first) one, else
    /// the top-level fields. Mirrors <see cref="ResolvedSteps"/> so both types pick a form the
    /// same way.</summary>
    public (List<CustomDevotionStep> Opening, DecadesDefinition? Decades,
            List<CustomDevotionStep> Closing, bool HasClosingCross) ResolvedRosary(string? variantId)
    {
        if (Variants is { Count: > 0 } variants)
        {
            var variant = variants.FirstOrDefault(v => v.Id == variantId) ?? variants[0];
            return (variant.Opening ?? [], variant.Decades, variant.Closing ?? [],
                    variant.HasClosingCross ?? false);
        }

        return (Opening ?? [], Decades, Closing ?? [], HasClosingCross ?? false);
    }

    public enum DevotionType
    {
        /// <summary>A flat, fixed step list (Angelus, Stations, Trisagion).</summary>
        Steps,

        /// <summary>A decade/bead-structured devotion (Franciscan Crown, Seven Sorrows, Divine
        /// Mercy).</summary>
        Rosary,

        /// <summary>A multi-day devotion (novenas, the 33-day Montfort consecration): one step
        /// list per day, with optional shared opening/closing prayed every day. Per-favorite
        /// day progress is a planned follow-up (see ARCHITECTURE.markdown's "Multi-day devotions") —
        /// until it lands, sessions pray day 1.</summary>
        Days,
    }

    /// <summary>One day of a days-type devotion.</summary>
    public sealed record Day(
        // English UI label ("Day 1"); NameByLanguage overrides it per UI localization.
        string Name,
        Dictionary<string, string>? NameByLanguage = null,
        // Optional grouping label for the Montfort-style structure ("First Week: Knowledge of
        // Self"), shown as period context by the day picker.
        string? Period = null,
        List<CustomDevotionStep>? Steps = null)
    {
        public string LocalizedName => HebrewDisplayText.WithoutMarks(
            NameByLanguage?.GetValueOrDefault(System.Globalization.CultureInfo.CurrentUICulture.TwoLetterISOLanguageName)
            ?? Name);
    }

    public sealed record DecadesDefinition(
        // The noun a decade is counted in ("Joy" / "Sorrow" / "Decade") — a literal, or a key
        // so it reads in the language being prayed ("Mystery" / "רז" / "Тайна").
        string? OrdinalNoun,
        string? OrdinalNounKey,
        // True: each decade opens with an announcement step whose title/body come from the
        // mystery text of that decade's catalog entry (via the merged MysteryTranslations path).
        bool AnnounceMystery,
        DecadesDefinition.FixedStep MajorStep,
        DecadesDefinition.FixedStep MinorStep,
        int MinorCount,
        // Per-decade catalog (Franciscan Crown/Seven Sorrows). Mutually exclusive with
        // Count+FixedImageKey (Divine Mercy) and with Source.
        List<DecadesDefinition.CatalogEntry>? Entries = null,
        int? Count = null,
        string? FixedImageKey = null,
        // "mysteryGroups" (the Rosary): the decade catalog is resolved at build time from the
        // engine's mystery-group machinery (RosaryOptions selection mode + liturgical calendar)
        // instead of Entries/Count — steps carry real Mystery values so the flow renders exactly
        // as the hardcoded builder did. Null for bundle-cataloged devotions.
        string? Source = null,
        // Entries emitted after each decade's minors, carrying the decade's subtitle/index (the
        // Rosary's Glory Be / Fatima Prayer / per-decade eternal rest), usually gated.
        /// <summary>Emitted before each decade's announcement — the Servite chaplet's
        /// invocation to Our Lady before each sorrow is named. Not beads: they carry the
        /// decade's subtitle but no DecadeIndex.</summary>
        List<CustomDevotionStep>? PreAnnouncement = null,
        List<CustomDevotionStep>? PostMinor = null,
        // Presenter-mode alternate decade tail: the minors collapse into one combined step with
        // HailMaryIndexInDecade = MinorCount so the bead track still renders a full decade.
        DecadesDefinition.PresenterDefinition? Presenter = null)
    {
        public sealed record CatalogEntry(
            string ImageKey,
            // Announcement steps are scripture by default; the one traditional non-Gospel scene
            // (the Seven Sorrows' meeting on the way) opts out.
            bool? IsScripture = null);

        // Title/TitleKey: a decade's Our Father/Hail Mary heading — carries a literal title or a translatable titleKey, exactly like every other step,
        // so it reads in the language being prayed.
        public sealed record FixedStep(
            string? Title,
            string? TitleKey,
            string BodyKey,
            // Fixed illustration for this step (the Rosary's Our Father icon between
            // mystery-specific images). Null = the decade's own image.
            string? ImageKey = null);

        public sealed record PresenterDefinition(
            string? CombinedTitle,
            string? CombinedTitleKey,
            // Bodies joined with a blank line (Hail Mary + Glory Be).
            List<string> BodyKeys);
    }
}

/// <summary>Metadata a generic devotion's Home card / Favorites row / reminders need, sourced
/// from its bundle's manifest.json rather than any hardcoded per-kind table.</summary>
public sealed record CustomDevotionInfo(
    string DisplayName,
    // The languages this bundle ships content for (manifest `languages`).
    IReadOnlyList<string> Languages,
    string? AccentColorHex,
    string? AccentColorDarkHex,
    string? IconSystemName,
    string? IconGlyph,
    IReadOnlyDictionary<string, string> DisplayNameByLanguage,
    IReadOnlyDictionary<string, string> ReminderBody,
    IReadOnlyList<int>? ReminderPresetHours,
    IReadOnlyDictionary<string, string> ReminderPresetFooter,
    // Lowercase category labels from the manifest ("marian", "passion") — what the
    // Categories page groups by.
    IReadOnlyList<string> Tags)
{
    private static string UiLanguage => CultureInfo.CurrentUICulture.TwoLetterISOLanguageName;

    /// <summary>The display name in the app's active UI localization (falling back to the
    /// manifest's base <see cref="DisplayName"/>) — preserves e.g. the Hebrew devotion names.</summary>
    /// <summary>The devotion's name, resolved the way its headings are: the prayer language
    /// first (exact resolved code, rites included, then its base), then the UI language, then
    /// the manifest's base DisplayName — a devotion's name is part of the prayer.</summary>
    public string LocalizedDisplayName
    {
        get
        {
            var prayerCode = Prosary.Models.LanguageCatalog.Resolve(null).Code;
            if (DisplayNameByLanguage.TryGetValue(prayerCode, out var prayerName))
                return HebrewDisplayText.WithoutMarks(prayerName);
            if (Prosary.Models.LanguageCatalog.BaseLanguage(prayerCode) is { } baseCode &&
                DisplayNameByLanguage.TryGetValue(baseCode, out var baseName))
                return HebrewDisplayText.WithoutMarks(baseName);
            return HebrewDisplayText.WithoutMarks(
                DisplayNameByLanguage.TryGetValue(UiLanguage, out var name) ? name : DisplayName);
        }
    }

    public string? LocalizedReminderBody =>
        ReminderBody.TryGetValue(UiLanguage, out var body) ? body
        : ReminderBody.TryGetValue("en", out var english) ? english
        : null;

    public string? LocalizedReminderPresetFooter =>
        ReminderPresetFooter.TryGetValue(UiLanguage, out var footer) ? footer
        : ReminderPresetFooter.TryGetValue("en", out var english) ? english
        : null;
}
