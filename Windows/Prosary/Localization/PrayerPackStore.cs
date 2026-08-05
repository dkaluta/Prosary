using System.Globalization;
using System.IO.Compression;
using System.Text.Json;
using System.Text.Json.Serialization;
using Windows.Storage;

namespace Prosary.Localization;

/// <summary>
/// Loads the bundled .prosaryprayer packs (Rosary, and every generic bundle-driven devotion —
/// see Shared/ARCHITECTURE.md's "Content bundles" section) and merges their content into
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
        "divineMercyChaplet", "trisagion",
    ];

    private static readonly Dictionary<string, Dictionary<string, string>> PrayerOverrides = new();
    private static readonly Dictionary<string, Dictionary<string, MysteryText>> MysteryOverrides = new();
    private static readonly Dictionary<string, byte[]> ImageDataByKey = new();
    private static readonly Dictionary<string, string> ExtractedImageUris = new();

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

    /// <summary>Each loaded bundle's re-openable pack source — audio bytes are re-read from here
    /// on demand rather than held in the load-time cache the way images are (a recording dwarfs
    /// every other bundle asset). See <see cref="AudioData"/>.</summary>
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

    public static string? PrayerOverride(string languageCode, string key) =>
        PrayerOverrides.TryGetValue(languageCode, out var table) && table.TryGetValue(key, out var text) ? text : null;

    public static MysteryText? MysteryOverride(string languageCode, string imageKey) =>
        MysteryOverrides.TryGetValue(languageCode, out var table) && table.TryGetValue(imageKey, out var text) ? text : null;

    public static byte[]? ImageData(string imageKey) => ImageDataByKey.TryGetValue(imageKey, out var data) ? data : null;

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
        if (available.Count == 0 || available.Contains(resolved))
        {
            return resolved;
        }

        // A community variant keeps its code when the bundle ships its base language —
        // bundle text falls back per key.
        if (Prosary.Models.LanguageCatalog.BaseLanguage(resolved) is { } baseLang && available.Contains(baseLang))
        {
            return resolved;
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
            using var probe = new ZipArchive(new MemoryStream(bytes), ZipArchiveMode.Read);
            var manifestEntry = probe.GetEntry("manifest.json")
                ?? throw new InstallException("This file is not a readable .prosaryprayer bundle.");
            manifest = JsonSerializer.Deserialize<PackManifest>(ReadAllBytes(manifestEntry), JsonOptions)
                ?? throw new InstallException("This file is not a readable .prosaryprayer bundle.");

            var devotionEntry = probe.GetEntry("devotion.json");
            if (devotionEntry is null || manifest.BuiltinKind is not null
                || JsonSerializer.Deserialize<CustomDevotionDefinition>(ReadAllBytes(devotionEntry), JsonOptions) is null)
            {
                throw new InstallException("This bundle does not contain a devotion.");
            }

            foreach (var language in manifest.Languages)
            {
                var contentEntry = probe.GetEntry($"content/{language}.json")
                    ?? throw new InstallException("This file is not a readable .prosaryprayer bundle.");
                _ = JsonSerializer.Deserialize<PackContent>(ReadAllBytes(contentEntry), JsonOptions)
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

    /// <summary>Deletes an installed bundle's file and unregisters its devotion. Its merged
    /// prayer/image content stays in memory until the next launch — harmless, since nothing
    /// references it once the devotion is gone from <see cref="CustomDevotionIds"/>.</summary>
    public static void RemoveInstalledPack(string id)
    {
        if (!InstalledIds.Contains(id)) return;
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
        TransliterationsByBundle.Remove(id);
        PackSourceByBundle.Remove(id);
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
    /// Empty for bundles without audio (see Shared/ARCHITECTURE.md's "Audio").</summary>
    public static IReadOnlyList<DevotionAudioTrack> AudioTracks(string bundleId) =>
        AudioTracksByBundle.TryGetValue(bundleId, out var tracks) ? tracks : [];

    /// <summary>The raw Ogg Opus bytes of one of a bundle's *declared* audio files
    /// (<see cref="DevotionAudioTrack.File"/>), re-read from the pack on demand. Null for a file
    /// no track declares. The playback milestone will extract to a cache file for the OS player
    /// (the <see cref="ImageFileUri"/> pattern) rather than keep whole recordings in memory;
    /// this byte-level accessor is the seam it builds on.</summary>
    public static byte[]? AudioData(string bundleId, string file)
    {
        if (!AudioTracksByBundle.TryGetValue(bundleId, out var tracks) || tracks.All(t => t.File != file))
        {
            return null;
        }
        if (!PackSourceByBundle.TryGetValue(bundleId, out var openPack)) return null;

        using var stream = openPack();
        if (stream is null) return null;
        using var seekable = stream.CanSeek ? stream : CopyToMemory(stream);
        using var archive = new ZipArchive(seekable, ZipArchiveMode.Read);
        var entry = archive.GetEntry(file);
        return entry is null ? null : ReadAllBytes(entry);
    }

    /// <summary>Resolves a <c>devotion.json</c> entry's <c>bodyKey</c>/<c>titleKey</c> to display
    /// text: (1) the bundle's own raw content for this key — the requested language, else the
    /// bundle's Latin (mirroring <see cref="PrayerTranslations.Get"/>'s Latin fallback, so e.g.
    /// the sentinel/unknown language prays in Latin, not raw keys); (2) else the ordinary
    /// PascalCased <see cref="PrayerTranslations.Get"/> chain — this is how shared "main" keys
    /// (e.g. "gloriaPatri") resolve, and it ends in the raw-key last resort.</summary>
    /// <summary>The v0.7 reading aid: this key's text transliterated into another script, if
    /// the bundle's language file carries one. No fallback chain — a transliteration belongs
    /// to exactly the language it transliterates.</summary>
    public static string? Transliteration(string bundleId, string? languageCode, string key) =>
        languageCode is not null
            && TransliterationsByBundle.TryGetValue(bundleId, out var byLanguage)
            && byLanguage.TryGetValue(languageCode, out var map)
            && map.TryGetValue(key, out var text)
        ? text
        : null;

    public static string ResolveBodyText(string bundleId, string? languageCode, string key)
    {
        if (RawContentByBundle.TryGetValue(bundleId, out var byLanguage))
        {
            if (languageCode is not null &&
                byLanguage.TryGetValue(languageCode, out var content) && content.TryGetValue(key, out var text))
            {
                return text;
            }

            // Community variants ("he-x-gamliel") overlay their base language's bundle text.
            if (languageCode is not null && Prosary.Models.LanguageCatalog.BaseLanguage(languageCode) is { } baseCode
                && byLanguage.TryGetValue(baseCode, out var baseContent) && baseContent.TryGetValue(key, out var baseText))
            {
                return baseText;
            }

            if (byLanguage.TryGetValue("la", out var latinContent) && latinContent.TryGetValue(key, out var latinText))
            {
                return latinText;
            }
        }

        var pascalKey = ToPascalCase(key);
        var resolved = PrayerTranslations.Get(languageCode, pascalKey);
        // PrayerTranslations' raw-key last resort returns the PascalCased form it was given —
        // surface the original key instead, matching iOS/Android.
        return resolved == pascalKey ? key : resolved;
    }

    /// <summary>Extracts a pack-provided image to a cache file on first request — WinUI's
    /// <c>Image.Source</c> needs a file/ms-appx URI, not raw bytes — and returns its <c>file://</c>
    /// URI. Returns null if no pack provides this key, so call sites can fall back to their
    /// existing <c>ms-appx:///Assets/Images/...</c> URI exactly as before this existed.</summary>
    public static string? ImageFileUri(string imageKey)
    {
        if (ExtractedImageUris.TryGetValue(imageKey, out var cachedUri)) return cachedUri;

        var data = ImageData(imageKey);
        if (data is null) return null;

        var directory = Path.Combine(ApplicationData.Current.LocalCacheFolder.Path, "PrayerPackImages");
        Directory.CreateDirectory(directory);
        var path = Path.Combine(directory, $"{imageKey}.jpg");
        if (!File.Exists(path))
        {
            File.WriteAllBytes(path, data);
        }

        var uri = new Uri(path).AbsoluteUri;
        ExtractedImageUris[imageKey] = uri;
        return uri;
    }

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
                        if (Load(stream) is not null)
                        {
                            InstalledIds.Add(id);
                            PackSourceByBundle[id] = () => File.OpenRead(path);
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
        using var seekable = stream.CanSeek ? stream : CopyToMemory(stream);
        using var archive = new ZipArchive(seekable, ZipArchiveMode.Read);
        // Zip directory records (e.g. a bare "images/" entry) have no isDirectory flag in
        // System.IO.Compression — the convention is a FullName ending in "/" — and must be
        // excluded here, not just at each lookup site, or the images/ prefix-stripping loop below
        // would try to slice a name shorter than the prefix+suffix it's stripping.
        var entries = archive.Entries
            .Where(e => !e.FullName.EndsWith('/'))
            .ToDictionary(e => e.FullName, e => e);

        if (!entries.TryGetValue("manifest.json", out var manifestEntry)) return null;
        var manifest = JsonSerializer.Deserialize<PackManifest>(ReadAllBytes(manifestEntry), JsonOptions)
            ?? throw new InvalidDataException("manifest.json did not deserialize");

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

        foreach (var language in manifest.Languages)
        {
            if (!entries.TryGetValue($"content/{language}.json", out var contentEntry)) continue;
            var content = JsonSerializer.Deserialize<PackContent>(ReadAllBytes(contentEntry), JsonOptions)
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
                var mysteries = MysteryOverrides.TryGetValue(language, out var existingMysteries) ? existingMysteries : new Dictionary<string, MysteryText>();
                foreach (var (key, text) in content.Mysteries)
                {
                    mysteries[key] = text;
                }
                MysteryOverrides[language] = mysteries;
            }
        }

        if (entries.TryGetValue("devotion.json", out var devotionEntry))
        {
            var definition = JsonSerializer.Deserialize<CustomDevotionDefinition>(ReadAllBytes(devotionEntry), JsonOptions)
                ?? throw new InvalidDataException("devotion.json did not deserialize");
            DefinitionByBundle[manifest.Id] = definition;
            if (manifest.BuiltinKind is null)
            {
                OrderedCustomIds.Add(manifest.Id);
            }
        }

        if (entries.TryGetValue("options.json", out var optionsEntry))
        {
            var packOptions = JsonSerializer.Deserialize<PackOptions>(ReadAllBytes(optionsEntry), JsonOptions)
                ?? throw new InvalidDataException("options.json did not deserialize");
            OptionsByBundle[manifest.Id] = packOptions.Options;
        }

        if (entries.TryGetValue("audio.json", out var audioEntry))
        {
            var packAudio = JsonSerializer.Deserialize<PackAudio>(ReadAllBytes(audioEntry), JsonOptions)
                ?? throw new InvalidDataException("audio.json did not deserialize");
            AudioTracksByBundle[manifest.Id] = packAudio.Tracks;
        }

        foreach (var entry in entries.Values)
        {
            if (entry.FullName.StartsWith("images/", StringComparison.Ordinal))
            {
                var imageKey = entry.FullName["images/".Length..^".jpg".Length];
                ImageDataByKey[imageKey] = ReadAllBytes(entry);
            }
        }

        return manifest.Id;
    }

    /// <summary>Bundle content JSON keys are the camelCase form used across every platform's
    /// schema (e.g. "oratioFatimae"); <see cref="PrayerKey"/>'s constants are the same names
    /// PascalCased (OratioFatimae).</summary>
    private static string ToPascalCase(string jsonKey) =>
        jsonKey.Length == 0 ? jsonKey : char.ToUpperInvariant(jsonKey[0]) + jsonKey[1..];

    private static byte[] ReadAllBytes(ZipArchiveEntry entry)
    {
        using var entryStream = entry.Open();
        using var memory = new MemoryStream();
        entryStream.CopyTo(memory);
        return memory.ToArray();
    }

    private static MemoryStream CopyToMemory(Stream stream)
    {
        var memory = new MemoryStream();
        stream.CopyTo(memory);
        memory.Position = 0;
        return memory;
    }

    private sealed record PackManifest(
        string Id,
        // Set ("rosary") when this bundle's devotion.json backs a dedicated PrayerKind rather
        // than a generic Custom devotion — the definition loads, but the bundle stays out of
        // CustomDevotionIds() so Home/Favorites don't list it twice.
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

    private sealed record PackContent(
        Dictionary<string, string>? Prayers,
        Dictionary<string, MysteryText>? Mysteries,
        // Optional reading aid (v0.7): prayer key -> the same text in another script.
        Dictionary<string, string>? Transliterations = null);

    private sealed record PackOptions(List<CustomDevotionOption> Options);

    private sealed record PackAudio(List<DevotionAudioTrack> Tracks);
}

/// <summary>One narrated recording a bundle declares in its <c>audio.json</c> (an optional
/// bundle file, staged by both packers like options.json — see Shared/ARCHITECTURE.md's
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

    public string? LocalizedName =>
        NameByLanguage?.GetValueOrDefault(System.Globalization.CultureInfo.CurrentUICulture.TwoLetterISOLanguageName)
        ?? Name;
}

/// <summary>One entry in a generic devotion's <c>devotion.json</c> — a step of the flat "steps"
/// type, an opening/closing step of the "rosary" type, or (closing only) a
/// <see cref="Kind"/>-tagged special step. <see cref="Title"/> is a literal display string (the
/// app-wide convention that step titles are English-only UI labels); <see cref="TitleKey"/> is
/// the alternative for devotions whose step titles are themselves translated content (e.g. the
/// Stations' station names). <see cref="Repeat"/> expands into n steps titled "Title (h of n)" —
/// deliberately without bead fields, matching the hardcoded devotions' closing Hail Marys.</summary>
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
        public string LocalizedName =>
            NameByLanguage?.GetValueOrDefault(System.Globalization.CultureInfo.CurrentUICulture.TwoLetterISOLanguageName)
            ?? Name;
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

    public string LocalizedName =>
        NameByLanguage?.GetValueOrDefault(System.Globalization.CultureInfo.CurrentUICulture.TwoLetterISOLanguageName)
        ?? Name;
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
        List<CustomDevotionStep>? EastertideSteps = null)
    {
        public string LocalizedName =>
            NameByLanguage?.GetValueOrDefault(System.Globalization.CultureInfo.CurrentUICulture.TwoLetterISOLanguageName)
            ?? Name;
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

    public enum DevotionType
    {
        /// <summary>A flat, fixed step list (Angelus, Stations, Trisagion).</summary>
        Steps,

        /// <summary>A decade/bead-structured devotion (Franciscan Crown, Seven Sorrows, Divine
        /// Mercy).</summary>
        Rosary,

        /// <summary>A multi-day devotion (novenas, the 33-day Montfort consecration): one step
        /// list per day, with optional shared opening/closing prayed every day. Per-favorite
        /// day progress is a planned follow-up (see ARCHITECTURE.md's "Multi-day devotions") —
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
        public string LocalizedName =>
            NameByLanguage?.GetValueOrDefault(System.Globalization.CultureInfo.CurrentUICulture.TwoLetterISOLanguageName)
            ?? Name;
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
    public string LocalizedDisplayName =>
        DisplayNameByLanguage.TryGetValue(UiLanguage, out var name) ? name : DisplayName;

    public string? LocalizedReminderBody =>
        ReminderBody.TryGetValue(UiLanguage, out var body) ? body
        : ReminderBody.TryGetValue("en", out var english) ? english
        : null;

    public string? LocalizedReminderPresetFooter =>
        ReminderPresetFooter.TryGetValue(UiLanguage, out var footer) ? footer
        : ReminderPresetFooter.TryGetValue("en", out var english) ? english
        : null;
}
