using System.IO.Compression;
using System.Text.Json;
using Windows.Storage;

namespace Prosary.Localization;

/// <summary>
/// Loads the bundled .prosaryprayer packs (Rosary, Angelus, and any generic bundle-driven
/// devotion such as Trisagion — see Shared/ARCHITECTURE.md's "Content bundles" section) and
/// merges their content into <see cref="PrayerTranslations"/>/<see cref="MysteryTranslations"/>
/// as an override layer. PrayerKey/mystery imageKey entries are a shared pool across devotions
/// (e.g. "our_father" is used by Rosary, Angelus, Franciscan Crown, Seven Sorrows, and Divine
/// Mercy alike), so a pack can only ever add to the hardcoded tables, never replace them
/// wholesale — devotions without a shipped pack keep resolving 100% from hardcoded source,
/// unaffected.
/// <para>
/// A bundle with a <c>steps.json</c> is a *generic devotion*: <see cref="Prosary.Models.PrayerKind.Custom"/>
/// + a <c>CustomDevotionId</c> are the only engine/model plumbing it needs (see
/// <c>PrayerEngine.BuildCustomDevotionSteps</c>) — its actual step sequence and per-step body
/// text are entirely data-driven from here, via <see cref="Steps"/>/<see cref="ResolveBodyText"/>.
/// Unlike iOS/Android, <see cref="PrayerKey"/> here is just a set of <c>string</c> constants with
/// no validating enum, and <see cref="PrayerOverrides"/> is never filtered against it — so a
/// bundle-local-only key (e.g. "TrisagionAcclamation") merges into the very same global override
/// table as a shared "main" key, and <see cref="ResolveBodyText"/> only needs to PascalCase the
/// incoming key and delegate to <see cref="PrayerTranslations.Get"/>, which already implements
/// the full override → per-language table → Latin → raw-key fallback chain for any key.
/// </para>
/// </summary>
public static class PrayerPackStore
{
    private static readonly Dictionary<string, Dictionary<string, string>> PrayerOverrides = new();
    private static readonly Dictionary<string, Dictionary<string, MysteryText>> MysteryOverrides = new();
    private static readonly Dictionary<string, byte[]> ImageDataByKey = new();
    private static readonly Dictionary<string, string> ExtractedImageUris = new();
    private static readonly Dictionary<string, List<CustomDevotionStep>> StepsByBundle = new();
    private static readonly Dictionary<string, CustomDevotionInfo> InfoByBundle = new();
    private static readonly JsonSerializerOptions JsonOptions = new() { PropertyNameCaseInsensitive = true };
    private static bool _didLoad;

    public static string? PrayerOverride(string languageCode, string key) =>
        PrayerOverrides.TryGetValue(languageCode, out var table) && table.TryGetValue(key, out var text) ? text : null;

    public static MysteryText? MysteryOverride(string languageCode, string imageKey) =>
        MysteryOverrides.TryGetValue(languageCode, out var table) && table.TryGetValue(imageKey, out var text) ? text : null;

    public static byte[]? ImageData(string imageKey) => ImageDataByKey.TryGetValue(imageKey, out var data) ? data : null;

    /// <summary>The ordered step sequence for a generic (bundle-driven) devotion, e.g.
    /// "trisagion". Empty for any bundle with no <c>steps.json</c> (Rosary/Angelus, which stay
    /// hardcoded).</summary>
    public static IReadOnlyList<CustomDevotionStep> Steps(string bundleId) =>
        StepsByBundle.TryGetValue(bundleId, out var steps) ? steps : [];

    /// <summary>Every loaded bundle id that has a <c>steps.json</c> — i.e. every generic devotion
    /// discovered at load time, without hardcoding devotion names anywhere in view code.</summary>
    public static IReadOnlyList<string> CustomDevotionIds() => StepsByBundle.Keys.ToList();

    public static CustomDevotionInfo? Info(string bundleId) =>
        InfoByBundle.TryGetValue(bundleId, out var info) ? info : null;

    /// <summary>Resolves a <c>steps.json</c> entry's <c>bodyKey</c> to display text. See this
    /// type's doc comment for why this is a single PascalCase-then-delegate step on Windows,
    /// unlike iOS/Android's two-tier bundle-local/shared-PrayerKey split.</summary>
    public static string ResolveBodyText(string? languageCode, string key) =>
        PrayerTranslations.Get(languageCode, ToPascalCase(key));

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
    public static void Initialize(Func<string, Stream?> openPack)
    {
        if (_didLoad) return;
        _didLoad = true;

        foreach (var packName in new[] { "rosary", "angelus", "trisagion" })
        {
            using var stream = openPack(packName);
            if (stream is null) continue;
            try
            {
                Load(stream);
            }
            catch
            {
                // Corrupt/unreadable pack — leave overrides empty for it, fall back to hardcoded content.
            }
        }
    }

    private static void Load(Stream stream)
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

        if (!entries.TryGetValue("manifest.json", out var manifestEntry)) return;
        var manifest = JsonSerializer.Deserialize<PackManifest>(ReadAllBytes(manifestEntry), JsonOptions)
            ?? throw new InvalidDataException("manifest.json did not deserialize");

        InfoByBundle[manifest.Id] = new CustomDevotionInfo(manifest.DisplayName, manifest.AccentColorHex, manifest.IconSystemName);

        foreach (var language in manifest.Languages)
        {
            if (!entries.TryGetValue($"content/{language}.json", out var contentEntry)) continue;
            var content = JsonSerializer.Deserialize<PackContent>(ReadAllBytes(contentEntry), JsonOptions)
                ?? throw new InvalidDataException($"content/{language}.json did not deserialize");

            var prayers = PrayerOverrides.TryGetValue(language, out var existingPrayers) ? existingPrayers : new Dictionary<string, string>();
            foreach (var (key, text) in content.Prayers ?? new Dictionary<string, string>())
            {
                prayers[ToPascalCase(key)] = text;
            }
            PrayerOverrides[language] = prayers;

            if (manifest.HasCatalog && content.Mysteries is { Count: > 0 })
            {
                var mysteries = MysteryOverrides.TryGetValue(language, out var existingMysteries) ? existingMysteries : new Dictionary<string, MysteryText>();
                foreach (var (key, text) in content.Mysteries)
                {
                    mysteries[key] = text;
                }
                MysteryOverrides[language] = mysteries;
            }
        }

        if (entries.TryGetValue("steps.json", out var stepsEntry))
        {
            var packSteps = JsonSerializer.Deserialize<PackSteps>(ReadAllBytes(stepsEntry), JsonOptions)
                ?? throw new InvalidDataException("steps.json did not deserialize");
            StepsByBundle[manifest.Id] = packSteps.Steps ?? [];
        }

        foreach (var entry in entries.Values)
        {
            if (entry.FullName.StartsWith("images/", StringComparison.Ordinal))
            {
                var imageKey = entry.FullName["images/".Length..^".jpg".Length];
                ImageDataByKey[imageKey] = ReadAllBytes(entry);
            }
        }
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
        string DisplayName,
        List<string> Languages,
        bool HasCatalog,
        string? AccentColorHex = null,
        string? IconSystemName = null);

    private sealed record PackContent(Dictionary<string, string>? Prayers, Dictionary<string, MysteryText>? Mysteries);

    private sealed record PackSteps(List<CustomDevotionStep>? Steps);
}

/// <summary>One entry in a generic (bundle-driven) devotion's <c>steps.json</c> — see
/// Shared/ARCHITECTURE.md's "Content bundles" section. <see cref="Title"/> is a literal display
/// string, not a translation key, matching the existing convention that every devotion's step
/// titles are English-only UI labels. <see cref="BodyKey"/>/<see cref="ImageKey"/> are resolved
/// via <see cref="PrayerPackStore.ResolveBodyText"/> / the ordinary image-override lookup,
/// exactly like a hardcoded devotion's step.</summary>
public sealed record CustomDevotionStep(string Title, string BodyKey, string ImageKey);

/// <summary>Metadata a generic devotion's Home card / Favorites row needs, sourced from its
/// bundle's manifest.json rather than any hardcoded per-kind table.</summary>
public sealed record CustomDevotionInfo(string DisplayName, string? AccentColorHex, string? IconSystemName);
