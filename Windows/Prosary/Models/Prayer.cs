using Prosary.Localization;

namespace Prosary.Models;

/// <summary>A saved, user-configurable prayer session. <see cref="Kind"/> selects the Rosary,
/// the Jesus Prayer, or the generic bundle path; adding an ordinary devotion means adding a
/// bundle, not a new enum case.</summary>
public sealed record Prayer
{
    public Guid Id { get; init; } = Guid.NewGuid();

    public string Name { get; init; } = "My Prayer";

    public PrayerKind Kind { get; init; } = PrayerKind.Rosary;

    /// <summary>The primary configuration for its devotion. At most one per
    /// (<see cref="Kind"/>, <see cref="CustomDevotionId"/>) at a time.</summary>
    public bool IsDefault { get; init; } = false;

    /// <summary>Prayer language for this configuration. <see cref="LanguageCatalog.DefaultSentinel"/>
    /// means follow the app-level default language setting.</summary>
    public string LanguageCode { get; init; } = LanguageCatalog.DefaultSentinel;

    // Kind-specific options — populate the relevant record when creating a Prayer.
    public RosaryOptions Rosary { get; init; } = new();
    public JesusPrayerOptions JesusPrayer { get; init; } = new();
    /// <summary>The bundle id (e.g. "trisagion") whose <c>devotion.json</c> defines this configuration's
    /// step sequence — populated only when <see cref="Kind"/> is <see cref="PrayerKind.Custom"/>,
    /// null otherwise. See <c>PrayerEngine.BuildCustomDevotionSteps</c>.</summary>
    public string? CustomDevotionId { get; init; } = null;

    /// <summary>Which of the bundle's variants (alternate step-sets, e.g. the Stations'
    /// traditional vs. scriptural forms) this configuration prays. Null = the bundle's default
    /// variant; only meaningful when Kind == Custom and the bundle declares
    /// variants.</summary>
    public string? VariantId { get; init; } = null;

    /// <summary>Multi-day ("days"-type) devotions: the day this configuration opens on, 0-based;
    /// advances when a day's session finishes (clamped by the engine). Null = day 1.</summary>
    public int? DayIndex { get; init; } = null;

    /// <summary>This configuration's choices for the bundle's <c>options.json</c> options, keyed by
    /// option key — "true"/"false" for toggles, a case id for choices. Only overrides: an absent
    /// key means the option's declared default. Only meaningful when Kind == Custom.</summary>
    public Dictionary<string, string> CustomOptions { get; init; } = new();

    /// <summary>Daily reminders for this configuration. Scheduled via <c>WindowsReminderScheduler</c>.</summary>
    public List<PrayerReminder> Reminders { get; init; } = [];

    public bool IsNotDefault => !IsDefault;
    public string DisplayName => HebrewDisplayText.WithoutMarks(Name);
    public string ResolvedLanguageCode => LanguageCatalog.Resolve(LanguageCode).Code;
    public string LanguageNativeName => LanguageCatalog.Resolve(LanguageCode).NativeName;

    /// <summary>Display string for list rows — shows "Default (Latina)" for the sentinel, plain
    /// name otherwise.</summary>
    public string LanguageDisplayName => LanguageCode == LanguageCatalog.DefaultSentinel
        ? string.Format(Loc.Tr("language_default_parenthesized", "Default ({0})"), LanguageCatalog.Resolve(LanguageCode).NativeName)
        : LanguageCatalog.Resolve(LanguageCode).NativeName;

    /// <summary>Second line shown on a Rosary preset card.</summary>
    public string FavoriteSubtitle => HebrewDisplayText.WithoutMarks(Kind switch
    {
        PrayerKind.Rosary => $"{Rosary.MysterySelectionSummary} • {LanguageDisplayName}",
        PrayerKind.JesusPrayer => $"{JesusPrayer.TargetDisplayName} • {LanguageDisplayName}",
        // Generic configurations use bundle metadata in their own flow/editor. Kept for
        // exhaustiveness and older bindings.
        PrayerKind.Custom => LanguageDisplayName,
        _ => throw new ArgumentOutOfRangeException(nameof(Kind))
    });
}
