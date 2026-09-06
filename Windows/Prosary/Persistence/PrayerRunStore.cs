using System.Globalization;
using System.Text.Json;
using Windows.Storage;

namespace Prosary.Persistence;

/// <summary>A lightweight checkpoint for an interrupted prayer. Position is zero-based;
/// position zero is not considered resumable because restarting would show the same screen.</summary>
public sealed record PrayerRunState(
    string ConfigurationSignature,
    int Position,
    string LanguageCode,
    string SavedLocalDate)
{
    public bool CanResume(
        string expectedSignature,
        int positionCount,
        bool sameLocalDayOnly,
        DateOnly today) =>
        Position > 0
        && Position < positionCount
        && ConfigurationSignature == expectedSignature
        && (!sameLocalDayOnly || SavedLocalDate == LocalDateString(today));

    public static string LocalDateString(DateOnly date) =>
        date.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
}

public interface IPrayerRunStore
{
    PrayerRunState? Get(string key);
    void Save(string key, PrayerRunState state);
    void Remove(string key);
}

/// <summary>Stores all prayer checkpoints as one small JSON value in LocalSettings. The
/// delegate constructor keeps the serialization/error paths testable in an unpackaged host.</summary>
public sealed class LocalPrayerRunStore : IPrayerRunStore
{
    private const string StorageKey = "unfinishedPrayerRuns";
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    private readonly Func<string?> _read;
    private readonly Action<string> _write;

    public LocalPrayerRunStore() : this(ReadSetting, WriteSetting)
    {
    }

    public LocalPrayerRunStore(Func<string?> read, Action<string> write)
    {
        _read = read;
        _write = write;
    }

    public PrayerRunState? Get(string key) => ReadAll().GetValueOrDefault(key);

    public void Save(string key, PrayerRunState state)
    {
        var runs = ReadAll();
        runs[key] = state;
        WriteAll(runs);
    }

    public void Remove(string key)
    {
        var runs = ReadAll();
        if (runs.Remove(key))
        {
            WriteAll(runs);
        }
    }

    private Dictionary<string, PrayerRunState> ReadAll()
    {
        try
        {
            var json = _read();
            return string.IsNullOrWhiteSpace(json)
                ? []
                : JsonSerializer.Deserialize<Dictionary<string, PrayerRunState>>(json, JsonOptions) ?? [];
        }
        catch
        {
            // A partial/old value must never prevent a prayer from opening.
            return [];
        }
    }

    private void WriteAll(Dictionary<string, PrayerRunState> runs)
    {
        try
        {
            _write(JsonSerializer.Serialize(runs, JsonOptions));
        }
        catch
        {
            // Persistence is a convenience; the active prayer continues even if storage fails.
        }
    }

    private static string? ReadSetting()
    {
        try
        {
            return ApplicationData.Current.LocalSettings.Values[StorageKey] as string;
        }
        catch
        {
            return null;
        }
    }

    private static void WriteSetting(string value)
    {
        try
        {
            ApplicationData.Current.LocalSettings.Values[StorageKey] = value;
        }
        catch
        {
            // Unit tests and unpackaged hosts have no ApplicationData identity.
        }
    }
}

public static class PrayerRunSignatures
{
    public static string Rosary(Models.RosaryOptions options)
    {
        var original = string.Join("|",
        new[]
        {
            "rosary",
            ((int)options.MysterySelectionMode).ToString(),
            ((int)options.SpecificMysteryGroup).ToString(),
            options.SpecificMysteryOrder.ToString(),
            Flag(options.IncludeApostlesCreed),
            Flag(options.IncludeOpeningPrayers),
            Flag(options.IncludeOpeningFatimaPrayer),
            Flag(options.IncludeFatimaPrayer),
            ((int)options.EternalRestForDeceased).ToString(),
            ((int)options.MarianAntiphon).ToString(),
            Flag(options.IncludeClosingIntentions),
            Flag(options.IncludeStMichaelPrayer),
            Flag(options.IncludeFinalSignOfCross),
            options.AramaicSignOfCrossForm,
            Flag(options.PresenterMode),
            ((int)options.MysteryImageStyle).ToString(),
        });
        var choices = new[] { options.EffectiveClosingPopeIntention, options.EffectiveClosingBishopIntention, options.EffectiveClosingDepartedIntention };
        return choices.Any(value => value || value != options.IncludeClosingIntentions)
            ? original + "|closing-v2:" + string.Join(",", choices.Select(Flag))
            : original;
    }

    public static string Custom(
        string bundleId,
        string? effectiveVariantId,
        int dayIndex,
        IReadOnlyDictionary<string, string>? options = null)
    {
        var optionText = options is null
            ? string.Empty
            : string.Join("|", options.OrderBy(pair => pair.Key).Select(pair => $"{pair.Key}={pair.Value}"));
        return $"custom|{bundleId}|{effectiveVariantId ?? string.Empty}|{dayIndex}|{optionText}";
    }

    public static string JesusPrayer(Models.JesusPrayerTarget target) => target switch
    {
        Models.JesusPrayerTarget.Count(var count) => $"jesus|count|{count}",
        Models.JesusPrayerTarget.Unbounded => "jesus|unbounded",
        _ => throw new ArgumentOutOfRangeException(nameof(target)),
    };

    private static string Flag(bool value) => value ? "1" : "0";
}

/// <summary>Stable device-local identities for the three resumable flow types. A custom
/// devotion includes form and day because each can have a different step sequence; saved
/// Rosaries/Jesus Prayers use their preset id so two favorites never share a checkpoint.</summary>
public static class PrayerRunKeys
{
    public static string Rosary(Guid prayerId) => $"rosary:{prayerId:D}";

    public static string Custom(string bundleId, string? variantId, int dayIndex) =>
        $"custom:{bundleId}:{variantId ?? string.Empty}:{dayIndex}";

    public static string Jesus(Guid? prayerId, Models.JesusPrayerTarget target) => prayerId is { } id
        ? $"jesus:{id:D}"
        : target switch
        {
            Models.JesusPrayerTarget.Count(var count) =>
                $"jesus:{count.ToString(CultureInfo.InvariantCulture)}",
            Models.JesusPrayerTarget.Unbounded => "jesus:unbounded",
            _ => throw new ArgumentOutOfRangeException(nameof(target)),
        };
}
