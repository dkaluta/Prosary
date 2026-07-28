using System.Text.Json;
using Prosary.Models;
using SQLite;

namespace Prosary.Persistence;

/// <summary>
/// SQLite row for a saved <see cref="Prayer"/> favorite — kept as a distinct storage shape from
/// the domain <see cref="Prayer"/> record, matching iOS's <c>PresetEntry</c>/Android's
/// <c>PresetEntity</c> split. Ported from irosary's <c>RosaryConfig</c> (which this table is a
/// structural descendant of), extended with a <see cref="Kind"/> discriminator, Jesus-Prayer
/// fields, and JSON-encoded reminders — none of which existed on irosary's Rosary-only schema.
/// </summary>
public sealed class PresetEntry
{
    [PrimaryKey]
    public Guid Id { get; set; } = Guid.NewGuid();

    [MaxLength(80), NotNull]
    public string Name { get; set; } = "My Prayer";

    /// <summary>The starred/primary favorite for its <see cref="Kind"/>. At most one per kind.</summary>
    public bool IsDefault { get; set; }

    /// <summary>Empty string means "follow the app-level default" — see <see cref="LanguageCatalog.DefaultSentinel"/>.</summary>
    [NotNull]
    public string LanguageCode { get; set; } = LanguageCatalog.DefaultSentinel;

    public PrayerKind Kind { get; set; } = PrayerKind.Rosary;

    /// <summary>Bundle id for a generic (Kind == Custom) devotion, e.g. "trisagion". Null for
    /// every other kind.</summary>
    public string? CustomDevotionId { get; set; } = null;

    /// <summary>Which bundle variant (alternate step-set) this favorite prays; null = the
    /// bundle's default. CreateTableAsync auto-adds this column to existing databases.</summary>
    public string? VariantId { get; set; } = null;

    // Flattened RosaryOptions (only meaningful when Kind == Rosary).
    public MysterySelectionMode MysterySelectionMode { get; set; } = MysterySelectionMode.TodaysMysteries;
    public MysteryGroup SpecificMysteryGroup { get; set; } = MysteryGroup.Joyful;

    /// <summary>1-based index into MysteryCatalog.ForGroup(SpecificMysteryGroup); used only when
    /// MysterySelectionMode is SingleMystery. Defaults to 1 for existing rows.</summary>
    public int SpecificMysteryOrder { get; set; } = 1;

    public bool IncludeApostlesCreed { get; set; } = true;
    public bool IncludeOpeningPrayers { get; set; } = true;
    public bool IncludeFatimaPrayer { get; set; } = true;
    public EternalRestPlacement EternalRestForDeceased { get; set; } = EternalRestPlacement.None;
    public MarianAntiphonOption MarianAntiphon { get; set; } = MarianAntiphonOption.Seasonal;
    public bool IncludeStMichaelPrayer { get; set; }
    public bool IncludeFinalSignOfCross { get; set; } = true;

    /// <summary>Defaults to false for existing rows.</summary>
    public bool PresenterMode { get; set; }

    // Flattened JesusPrayerOptions (only meaningful when Kind == JesusPrayer).
    public bool JesusPrayerIsUnbounded { get; set; }
    public int JesusPrayerCount { get; set; } = 33;

    /// <summary>JSON-encoded <c>List&lt;PrayerReminder&gt;</c> — matches iOS's <c>remindersJSON: Data</c>
    /// approach rather than a separate reminders table, since it's always loaded with its parent
    /// and never queried independently.</summary>
    [NotNull]
    public string RemindersJson { get; set; } = "[]";

    public Prayer ToPrayer() => new()
    {
        Id = Id,
        Name = Name,
        Kind = Kind,
        IsDefault = IsDefault,
        LanguageCode = LanguageCode,
        CustomDevotionId = CustomDevotionId,
        VariantId = VariantId,
        Rosary = new RosaryOptions
        {
            MysterySelectionMode = MysterySelectionMode,
            SpecificMysteryGroup = SpecificMysteryGroup,
            SpecificMysteryOrder = SpecificMysteryOrder,
            IncludeApostlesCreed = IncludeApostlesCreed,
            IncludeOpeningPrayers = IncludeOpeningPrayers,
            IncludeFatimaPrayer = IncludeFatimaPrayer,
            EternalRestForDeceased = EternalRestForDeceased,
            MarianAntiphon = MarianAntiphon,
            IncludeStMichaelPrayer = IncludeStMichaelPrayer,
            IncludeFinalSignOfCross = IncludeFinalSignOfCross,
            PresenterMode = PresenterMode,
        },
        JesusPrayer = new JesusPrayerOptions
        {
            Target = JesusPrayerIsUnbounded
                ? new JesusPrayerTarget.Unbounded()
                : new JesusPrayerTarget.Count(JesusPrayerCount),
        },
        Reminders = DeserializeReminders(RemindersJson),
    };

    public static PresetEntry FromPrayer(Prayer prayer) => new()
    {
        Id = prayer.Id,
        Name = prayer.Name,
        Kind = prayer.Kind,
        IsDefault = prayer.IsDefault,
        LanguageCode = prayer.LanguageCode,
        CustomDevotionId = prayer.CustomDevotionId,
        VariantId = prayer.VariantId,
        MysterySelectionMode = prayer.Rosary.MysterySelectionMode,
        SpecificMysteryGroup = prayer.Rosary.SpecificMysteryGroup,
        SpecificMysteryOrder = prayer.Rosary.SpecificMysteryOrder,
        IncludeApostlesCreed = prayer.Rosary.IncludeApostlesCreed,
        IncludeOpeningPrayers = prayer.Rosary.IncludeOpeningPrayers,
        IncludeFatimaPrayer = prayer.Rosary.IncludeFatimaPrayer,
        EternalRestForDeceased = prayer.Rosary.EternalRestForDeceased,
        MarianAntiphon = prayer.Rosary.MarianAntiphon,
        IncludeStMichaelPrayer = prayer.Rosary.IncludeStMichaelPrayer,
        IncludeFinalSignOfCross = prayer.Rosary.IncludeFinalSignOfCross,
        PresenterMode = prayer.Rosary.PresenterMode,
        JesusPrayerIsUnbounded = prayer.JesusPrayer.Target is JesusPrayerTarget.Unbounded,
        JesusPrayerCount = prayer.JesusPrayer.Target is JesusPrayerTarget.Count(var n) ? n : 33,
        RemindersJson = JsonSerializer.Serialize(prayer.Reminders),
    };

    private static List<PrayerReminder> DeserializeReminders(string json)
    {
        try
        {
            return JsonSerializer.Deserialize<List<PrayerReminder>>(json) ?? [];
        }
        catch (JsonException)
        {
            return [];
        }
    }
}
