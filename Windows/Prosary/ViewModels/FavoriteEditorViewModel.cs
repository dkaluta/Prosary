using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Prosary.Localization;
using Prosary.Models;
using Prosary.Navigation;
using Prosary.Persistence;
using Prosary.Services;

namespace Prosary.ViewModels;

/// <summary>
/// Drives the favorite editor for Rosary/Jesus Prayer — the only two kinds with real
/// per-favorite options worth naming and saving multiple variants of (see
/// <see cref="Prosary.ViewModels.FavoritesViewModel"/> for the other 5 kinds' single-star-row
/// treatment). Ported from Android's <c>FavoriteEditorScreen.kt</c>. Unlike that screen's single
/// mutable <c>Prayer</c> copy, this flattens every field onto its own <c>[ObservableProperty]</c>
/// (matching every other ViewModel in this project) since <see cref="Prayer"/> is an immutable
/// record and two-way XAML bindings want plain mutable properties, not a record rebuilt via
/// <c>with</c> on every keystroke. <see cref="BuildPrayer"/> reassembles the record only once, on
/// save. Reminders are handled by the composed <see cref="RemindersEditor"/> rather than owned
/// directly, so this and <see cref="RemindersOnlyEditorViewModel"/> manage them identically.
///
/// Kind-specific sections (Rosary options, Jesus Prayer target) are always populated but only
/// shown by the page when <see cref="Kind"/> matches — see
/// <see cref="IsRosary"/>/<see cref="IsJesusPrayer"/>.
/// </summary>
public partial class FavoriteEditorViewModel : ObservableObject
{
    private readonly IPresetStore _presets;
    private readonly IReminderScheduler _scheduler;

    private Guid _id;
    private Prayer? _originalPrayer;

    [ObservableProperty]
    private bool _isNew = true;

    [ObservableProperty]
    private string _name = string.Empty;

    [ObservableProperty]
    private PrayerKind _kind = PrayerKind.Rosary;

    [ObservableProperty]
    private bool _isDefault;

    [ObservableProperty]
    private string _languageCode = LanguageCatalog.DefaultSentinel;

    [ObservableProperty]
    private MysterySelectionMode _mysterySelectionMode = MysterySelectionMode.TodaysMysteries;

    [ObservableProperty]
    private MysteryGroup _specificMysteryGroup = MysteryGroup.Joyful;

    /// <summary>UI-only — the ComboBox needs a bindable object with a title to display, unlike
    /// <see cref="RosaryOptions.SpecificMysteryOrder"/>'s plain persisted int. Kept in sync with
    /// that int via <see cref="BuildPrayer"/>/<see cref="ApplyFromPrayer"/> and reset to the new
    /// group's first mystery whenever <see cref="SpecificMysteryGroup"/> changes.</summary>
    [ObservableProperty]
    private Mystery? _selectedMystery;

    [ObservableProperty]
    private bool _includeApostlesCreed = true;

    [ObservableProperty]
    private bool _includeOpeningPrayers = true;

    [ObservableProperty]
    private bool _includeFatimaPrayer = true;

    [ObservableProperty]
    private EternalRestPlacement _eternalRestForDeceased = EternalRestPlacement.None;

    [ObservableProperty]
    private MarianAntiphonOption _marianAntiphon = MarianAntiphonOption.Seasonal;

    [ObservableProperty]
    private bool _includeStMichaelPrayer;

    [ObservableProperty]
    private bool _includeFinalSignOfCross = true;

    /// <summary>Collapses each decade's 10 Hail Marys and Glory Be onto one combined screen —
    /// for someone leading a group aloud from memory who doesn't need to tap through 10
    /// visually-identical screens. See <c>PrayerEngine.BuildRosarySteps</c>.</summary>
    [ObservableProperty]
    private bool _presenterMode;

    [ObservableProperty]
    private JesusPrayerTarget _jesusPrayerTarget = new JesusPrayerTarget.Count(33);

    /// <summary>Drives the same-page "submenu" swap for the 4 Rosary-specific sections (see
    /// FavoriteEditorPage.xaml) — not a separate Frame-navigated Page, since every other page in
    /// this app resolves its own ViewModel fresh from DI rather than sharing a live instance
    /// across pages, and these sections' state already lives directly on this ViewModel's flat
    /// properties (unlike iOS/Android, which bind a nested RosaryOptions object a sub-screen can
    /// take by reference/binding).</summary>
    [ObservableProperty]
    private bool _showingRosaryOptions;

    public RemindersEditorViewModel RemindersEditor { get; } = new();

    public string Title => IsNew ? Loc.Tr("editor_new_favorite", "New Favorite") : Loc.Tr("editor_edit_favorite", "Edit Favorite");

    public bool IsRosary => Kind == PrayerKind.Rosary;
    public bool IsJesusPrayer => Kind == PrayerKind.JesusPrayer;
    public bool IsSpecificMysteryGroup => MysterySelectionMode is MysterySelectionMode.Specific or MysterySelectionMode.SingleMystery;
    public bool IsSingleMystery => MysterySelectionMode == MysterySelectionMode.SingleMystery;

    /// <summary>Preview text for the "Rosary Options" row that opens the submenu — mirrors
    /// <see cref="RosaryOptions.MysterySelectionSummary"/>, computed from this ViewModel's own
    /// flat properties rather than a <see cref="RosaryOptions"/> instance (this ViewModel doesn't
    /// hold one directly; see <see cref="BuildPrayer"/>).</summary>
    public string MysterySelectionSummary => MysterySelectionMode switch
    {
        MysterySelectionMode.Specific => string.Format(Loc.Tr("summary_always", "Always {0}"), SpecificMysteryGroup.UiName()),
        MysterySelectionMode.SingleMystery => string.Format(Loc.Tr("summary_only", "Only {0}"), SelectedMystery is { } m ? MysteryTranslations.Get("en", m.ImageKey).Title : SpecificMysteryGroup.UiName()),
        MysterySelectionMode.FifteenMystery => Loc.Tr("summary_fifteen", "The 15 Mysteries"),
        MysterySelectionMode.TwentyMystery => Loc.Tr("summary_twenty", "The 20 Mysteries"),
        MysterySelectionMode.TodaysMysteries => Loc.Tr("mode_todays_mysteries", "Today's Mysteries"),
        _ => throw new ArgumentOutOfRangeException(nameof(MysterySelectionMode)),
    };

    /// <summary>The 5 mysteries of <see cref="SpecificMysteryGroup"/>, for the "Which mystery"
    /// ComboBox shown only when <see cref="IsSingleMystery"/>.</summary>
    public IReadOnlyList<Mystery> MysteryOptions => MysteryCatalog.ForGroup(SpecificMysteryGroup);

    // ComboBox ItemsSource lists — each entry displayed via a Converters/*LabelConverter or
    // *DisplayName() extension rather than the raw enum/code value.
    public IReadOnlyList<string> LanguageCodeOptions { get; } =
        [LanguageCatalog.DefaultSentinel, .. LanguageCatalog.All.Select(l => l.Code)];

    public IReadOnlyList<MysterySelectionMode> MysterySelectionModeOptions { get; } = Enum.GetValues<MysterySelectionMode>();
    public IReadOnlyList<MysteryGroup> MysteryGroupOptions { get; } = Enum.GetValues<MysteryGroup>();
    public IReadOnlyList<EternalRestPlacement> EternalRestPlacementOptions { get; } = Enum.GetValues<EternalRestPlacement>();
    public IReadOnlyList<MarianAntiphonOption> MarianAntiphonOptions { get; } = Enum.GetValues<MarianAntiphonOption>();

    public IReadOnlyList<JesusPrayerTarget> JesusPrayerTargetOptions { get; } =
    [
        new JesusPrayerTarget.Count(33),
        new JesusPrayerTarget.Count(66),
        new JesusPrayerTarget.Count(99),
        new JesusPrayerTarget.Unbounded(),
    ];

    public FavoriteEditorViewModel(IPresetStore presets, IReminderScheduler scheduler)
    {
        _presets = presets;
        _scheduler = scheduler;
    }

    public async Task LoadAsync(Guid? prayerId, PrayerKind newFavoriteKind)
    {
        IsNew = prayerId is null;

        Prayer prayer;
        if (prayerId is { } id)
        {
            prayer = await _presets.GetAsync(id) ?? new Prayer { Kind = newFavoriteKind };
        }
        else
        {
            var existing = await _presets.GetAllAsync();
            prayer = new Prayer
            {
                Name = newFavoriteKind.DefaultName(),
                Kind = newFavoriteKind,
                IsDefault = existing.All(p => p.Kind != newFavoriteKind),
            };
        }

        _originalPrayer = prayer;
        _id = prayer.Id;
        ApplyFromPrayer(prayer);
    }

    private void ApplyFromPrayer(Prayer prayer)
    {
        Name = prayer.Name;
        Kind = prayer.Kind;
        IsDefault = prayer.IsDefault;
        LanguageCode = prayer.LanguageCode;
        MysterySelectionMode = prayer.Rosary.MysterySelectionMode;
        SpecificMysteryGroup = prayer.Rosary.SpecificMysteryGroup;
        SelectedMystery = MysteryCatalog.ForGroup(prayer.Rosary.SpecificMysteryGroup)
            .FirstOrDefault(m => m.Order == prayer.Rosary.SpecificMysteryOrder);
        IncludeApostlesCreed = prayer.Rosary.IncludeApostlesCreed;
        IncludeOpeningPrayers = prayer.Rosary.IncludeOpeningPrayers;
        IncludeFatimaPrayer = prayer.Rosary.IncludeFatimaPrayer;
        EternalRestForDeceased = prayer.Rosary.EternalRestForDeceased;
        MarianAntiphon = prayer.Rosary.MarianAntiphon;
        IncludeStMichaelPrayer = prayer.Rosary.IncludeStMichaelPrayer;
        IncludeFinalSignOfCross = prayer.Rosary.IncludeFinalSignOfCross;
        PresenterMode = prayer.Rosary.PresenterMode;
        JesusPrayerTarget = prayer.JesusPrayer.Target;
        RemindersEditor.Reminders = new ObservableCollection<PrayerReminder>(prayer.Reminders);
    }

    private Prayer BuildPrayer() => new()
    {
        Id = _id,
        Name = string.IsNullOrWhiteSpace(Name) ? Kind.DefaultName() : Name,
        Kind = Kind,
        IsDefault = IsDefault,
        LanguageCode = LanguageCode,
        Rosary = new RosaryOptions
        {
            MysterySelectionMode = MysterySelectionMode,
            SpecificMysteryGroup = SpecificMysteryGroup,
            SpecificMysteryOrder = SelectedMystery?.Order ?? 1,
            IncludeApostlesCreed = IncludeApostlesCreed,
            IncludeOpeningPrayers = IncludeOpeningPrayers,
            IncludeFatimaPrayer = IncludeFatimaPrayer,
            EternalRestForDeceased = EternalRestForDeceased,
            MarianAntiphon = MarianAntiphon,
            IncludeStMichaelPrayer = IncludeStMichaelPrayer,
            IncludeFinalSignOfCross = IncludeFinalSignOfCross,
            PresenterMode = PresenterMode,
        },
        JesusPrayer = new JesusPrayerOptions { Target = JesusPrayerTarget },
        Reminders = [.. RemindersEditor.Reminders],
    };

    partial void OnKindChanged(PrayerKind value)
    {
        OnPropertyChanged(nameof(IsRosary));
        OnPropertyChanged(nameof(IsJesusPrayer));
    }

    partial void OnMysterySelectionModeChanged(MysterySelectionMode value)
    {
        OnPropertyChanged(nameof(IsSpecificMysteryGroup));
        OnPropertyChanged(nameof(IsSingleMystery));
        OnPropertyChanged(nameof(MysterySelectionSummary));
    }

    /// <summary>Resets the "Which mystery" selection to the new group's first mystery — otherwise
    /// <see cref="SelectedMystery"/> would keep pointing at a Mystery from the group the user just
    /// switched away from.</summary>
    partial void OnSpecificMysteryGroupChanged(MysteryGroup value)
    {
        OnPropertyChanged(nameof(MysteryOptions));
        OnPropertyChanged(nameof(MysterySelectionSummary));
        SelectedMystery = MysteryOptions.FirstOrDefault();
    }

    partial void OnSelectedMysteryChanged(Mystery? value) => OnPropertyChanged(nameof(MysterySelectionSummary));

    [RelayCommand]
    private void ShowRosaryOptions() => ShowingRosaryOptions = true;

    [RelayCommand]
    private void HideRosaryOptions() => ShowingRosaryOptions = false;

    [RelayCommand]
    private async Task SaveAsync()
    {
        var toSave = BuildPrayer();
        await _presets.SaveAsync(toSave);

        // Cancel the original's reminders (by their old ids) before scheduling the new set —
        // Schedule() only knows how to (re)build toasts for reminder ids present in toSave, so a
        // reminder the user just deleted would otherwise never have its pending toasts removed.
        if (_originalPrayer is { } original)
        {
            _scheduler.RemoveAll(original);
        }
        _scheduler.Schedule(toSave);

        Router.GoBack();
    }

    [RelayCommand]
    private void Cancel() => Router.GoBack();
}
