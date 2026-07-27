using System.IO.Compression;
using System.Text.Json;
using Windows.Storage;

namespace Prosary.Localization;

/// <summary>
/// Loads the bundled .prosaryprayer packs (currently Rosary + Angelus — see
/// Shared/ARCHITECTURE.md's "Content bundles" section) and merges their content into
/// <see cref="PrayerTranslations"/>/<see cref="MysteryTranslations"/> as an override layer.
/// PrayerKey/mystery imageKey entries are a shared pool across devotions (e.g. "our_father" is
/// used by Rosary, Angelus, Franciscan Crown, Seven Sorrows, and Divine Mercy alike), so a pack
/// can only ever add to the hardcoded tables, never replace them wholesale — devotions without a
/// shipped pack keep resolving 100% from hardcoded source, unaffected.
/// </summary>
public static class PrayerPackStore
{
    private static readonly Dictionary<string, Dictionary<string, string>> PrayerOverrides = new();
    private static readonly Dictionary<string, Dictionary<string, MysteryText>> MysteryOverrides = new();
    private static readonly Dictionary<string, byte[]> ImageDataByKey = new();
    private static readonly Dictionary<string, string> ExtractedImageUris = new();
    private static readonly JsonSerializerOptions JsonOptions = new() { PropertyNameCaseInsensitive = true };
    private static bool _didLoad;

    public static string? PrayerOverride(string languageCode, string key) =>
        PrayerOverrides.TryGetValue(languageCode, out var table) && table.TryGetValue(key, out var text) ? text : null;

    public static MysteryText? MysteryOverride(string languageCode, string imageKey) =>
        MysteryOverrides.TryGetValue(languageCode, out var table) && table.TryGetValue(imageKey, out var text) ? text : null;

    public static byte[]? ImageData(string imageKey) => ImageDataByKey.TryGetValue(imageKey, out var data) ? data : null;

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

        foreach (var packName in new[] { "rosary", "angelus" })
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

    private sealed record PackManifest(string Id, List<string> Languages, bool HasCatalog);

    private sealed record PackContent(Dictionary<string, string>? Prayers, Dictionary<string, MysteryText>? Mysteries);
}
