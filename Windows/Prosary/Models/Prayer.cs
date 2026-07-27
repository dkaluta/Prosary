namespace Prosary.Models;

/// <summary>A saved, user-configurable prayer session (a "Favorite"). <see cref="Kind"/> selects
/// the prayer type; kind-specific settings live in nested option records. Add new
/// <see cref="PrayerKind"/> cases and matching option records here to expand into new devotions
/// (Divine Mercy Chaplet, Seven Sorrows, etc.).</summary>
public sealed record Prayer
{
    public Guid Id { get; init; } = Guid.NewGuid();

    public string Name { get; init; } = "My Prayer";

    public PrayerKind Kind { get; init; } = PrayerKind.Rosary;

    /// <summary>The starred/primary favorite for its kind — used when Home launches this kind of
    /// prayer without the user picking one explicitly. At most one per kind at a time.</summary>
    public bool IsDefault { get; init; } = false;

    /// <summary>Prayer language for this favorite. <see cref="LanguageCatalog.DefaultSentinel"/>
    /// means follow the app-level default language setting.</summary>
    public string LanguageCode { get; init; } = LanguageCatalog.DefaultSentinel;

    // Kind-specific options — populate the relevant record when creating a Prayer.
    public RosaryOptions Rosary { get; init; } = new();
    public JesusPrayerOptions JesusPrayer { get; init; } = new();
    // Angelus has no options beyond LanguageCode.

    /// <summary>The bundle id (e.g. "trisagion") whose <c>steps.json</c> defines this favorite's
    /// step sequence — populated only when <see cref="Kind"/> is <see cref="PrayerKind.Custom"/>,
    /// null otherwise. See <c>PrayerEngine.BuildCustomDevotionSteps</c>.</summary>
    public string? CustomDevotionId { get; init; } = null;

    /// <summary>Daily reminders to pray this favorite. Scheduled via <c>WindowsReminderScheduler</c>.</summary>
    public List<PrayerReminder> Reminders { get; init; } = [];

    public bool IsNotDefault => !IsDefault;
    public string ResolvedLanguageCode => LanguageCatalog.Resolve(LanguageCode).Code;
    public string LanguageNativeName => LanguageCatalog.Resolve(LanguageCode).NativeName;

    /// <summary>Display string for list rows — shows "Default (Latina)" for the sentinel, plain
    /// name otherwise.</summary>
    public string LanguageDisplayName => LanguageCode == LanguageCatalog.DefaultSentinel
        ? $"Default ({LanguageCatalog.Resolve(LanguageCode).NativeName})"
        : LanguageCatalog.Resolve(LanguageCode).NativeName;

    /// <summary>Second line shown on a Favorites list card — matches Android's inline
    /// <c>FavoriteCard</c> subtitle logic in <c>FavoritesListScreen.kt</c>.</summary>
    public string FavoriteSubtitle => Kind switch
    {
        PrayerKind.Rosary => $"{Rosary.MysterySelectionSummary} • {LanguageDisplayName}",
        PrayerKind.JesusPrayer => $"{JesusPrayer.TargetDisplayName} • {LanguageDisplayName}",
        // Unreachable in practice — .Custom favorites render via the star row, never a full
        // FavoriteCard. Still needed for exhaustiveness.
        PrayerKind.Custom => LanguageDisplayName,
        _ => throw new ArgumentOutOfRangeException(nameof(Kind))
    };
}
