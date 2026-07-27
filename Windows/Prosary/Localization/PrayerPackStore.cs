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
        "rosary", "angelus", "stationsOfTheCross", "franciscanCrown", "sevenSorrows",
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
    private static readonly Dictionary<string, CustomDevotionDefinition> DefinitionByBundle = new();

    /// <summary>Bundle ids with a devotion.json, in pack-load order.</summary>
    private static readonly List<string> OrderedCustomIds = new();
    private static readonly Dictionary<string, CustomDevotionInfo> InfoByBundle = new();
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

    /// <summary>Every loaded bundle id that has a <c>devotion.json</c> — i.e. every generic
    /// devotion discovered at load time, in pack-load order, without hardcoding devotion names
    /// anywhere in view code.</summary>
    public static IReadOnlyList<string> CustomDevotionIds() => OrderedCustomIds;

    public static CustomDevotionInfo? Info(string bundleId) =>
        InfoByBundle.TryGetValue(bundleId, out var info) ? info : null;

    /// <summary>Resolves a <c>devotion.json</c> entry's <c>bodyKey</c>/<c>titleKey</c> to display
    /// text: (1) the bundle's own raw content for this key — the requested language, else the
    /// bundle's Latin (mirroring <see cref="PrayerTranslations.Get"/>'s Latin fallback, so e.g.
    /// the sentinel/unknown language prays in Latin, not raw keys); (2) else the ordinary
    /// PascalCased <see cref="PrayerTranslations.Get"/> chain — this is how shared "main" keys
    /// (e.g. "gloriaPatri") resolve, and it ends in the raw-key last resort.</summary>
    public static string ResolveBodyText(string bundleId, string? languageCode, string key)
    {
        if (RawContentByBundle.TryGetValue(bundleId, out var byLanguage))
        {
            if (languageCode is not null &&
                byLanguage.TryGetValue(languageCode, out var content) && content.TryGetValue(key, out var text))
            {
                return text;
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
    public static void Initialize(Func<string, Stream?> openPack)
    {
        if (_didLoad) return;
        _didLoad = true;

        foreach (var packName in PackNames)
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

        InfoByBundle[manifest.Id] = new CustomDevotionInfo(
            manifest.DisplayName,
            manifest.Languages,
            manifest.AccentColorHex,
            manifest.AccentColorDarkHex,
            manifest.IconSystemName,
            manifest.DisplayNameByLanguage ?? new Dictionary<string, string>(),
            manifest.ReminderBody ?? new Dictionary<string, string>(),
            manifest.ReminderPresetHours,
            manifest.ReminderPresetFooter ?? new Dictionary<string, string>());

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
            OrderedCustomIds.Add(manifest.Id);
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
        string? AccentColorDarkHex = null,
        string? IconSystemName = null,
        Dictionary<string, string>? DisplayNameByLanguage = null,
        Dictionary<string, string>? ReminderBody = null,
        List<int>? ReminderPresetHours = null,
        Dictionary<string, string>? ReminderPresetFooter = null);

    private sealed record PackContent(Dictionary<string, string>? Prayers, Dictionary<string, MysteryText>? Mysteries);
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
    string? ImageKey = null,
    int? Repeat = null,
    CustomDevotionStep.SpecialKind? Kind = null)
{
    public enum SpecialKind
    {
        /// <summary>The seasonal Marian antiphon (Franciscan Crown) — calendar-dependent, so it
        /// stays runtime-composed by the engine's shared antiphon builder rather than
        /// data-driven.</summary>
        SeasonalMarianAntiphon,
    }
}

/// <summary>Parsed <c>devotion.json</c> — the complete structural description of a generic
/// devotion. Field validity per type is enforced at authoring time by
/// <c>Shared/tools/validate-devotion.py</c>; the decoder is deliberately lenient (all optionals)
/// so the engine can switch on <see cref="Type"/> alone.</summary>
public sealed record CustomDevotionDefinition(
    CustomDevotionDefinition.DevotionType Type,
    // steps type
    List<CustomDevotionStep>? Steps = null,
    // Whole-sequence swap during Eastertide (the Angelus → Regina Caeli substitution).
    List<CustomDevotionStep>? EastertideSteps = null,
    // rosary type
    List<CustomDevotionStep>? Opening = null,
    CustomDevotionDefinition.DecadesDefinition? Decades = null,
    List<CustomDevotionStep>? Closing = null,
    bool? HasClosingCross = null)
{
    public enum DevotionType
    {
        /// <summary>A flat, fixed step list (Angelus, Stations, Trisagion).</summary>
        Steps,

        /// <summary>A decade/bead-structured devotion (Franciscan Crown, Seven Sorrows, Divine
        /// Mercy).</summary>
        Rosary,
    }

    public sealed record DecadesDefinition(
        // "Joy" / "Sorrow" / "Decade" — combined with the engine's ordinal array into "1st Joy" etc.
        string OrdinalNoun,
        // True: each decade opens with an announcement step whose title/body come from the
        // mystery text of that decade's catalog entry (via the merged MysteryTranslations path).
        bool AnnounceMystery,
        DecadesDefinition.FixedStep MajorStep,
        DecadesDefinition.FixedStep MinorStep,
        int MinorCount,
        // Per-decade catalog (Franciscan Crown/Seven Sorrows). Mutually exclusive with
        // Count+FixedImageKey (Divine Mercy).
        List<DecadesDefinition.CatalogEntry>? Entries = null,
        int? Count = null,
        string? FixedImageKey = null)
    {
        public sealed record CatalogEntry(
            string ImageKey,
            // Announcement steps are scripture by default; the one traditional non-Gospel scene
            // (the Seven Sorrows' meeting on the way) opts out.
            bool? IsScripture = null);

        public sealed record FixedStep(string Title, string BodyKey);
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
    IReadOnlyDictionary<string, string> DisplayNameByLanguage,
    IReadOnlyDictionary<string, string> ReminderBody,
    IReadOnlyList<int>? ReminderPresetHours,
    IReadOnlyDictionary<string, string> ReminderPresetFooter)
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
