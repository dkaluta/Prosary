using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Prosary.Models;
using Prosary.Navigation;
using Prosary.Persistence;
using Prosary.Services;

namespace Prosary.ViewModels;

/// <summary>
/// Drives the favorite editor — ported from Android's <c>FavoriteEditorScreen.kt</c>. Unlike that
/// screen's single mutable <c>Prayer</c> copy, this flattens every field onto its own
/// <c>[ObservableProperty]</c> (matching every other ViewModel in this project) since
/// <see cref="Prayer"/> is an immutable record and two-way XAML bindings want plain mutable
/// properties, not a record rebuilt via <c>with</c> on every keystroke. <see cref="BuildPrayer"/>
/// reassembles the record only once, on save.
///
/// Kind-specific sections (Rosary options, Jesus Prayer target, Angelus quick-toggle reminder
/// rows) are always populated but only shown by the page when <see cref="Kind"/> matches — see
/// <see cref="IsRosary"/>/<see cref="IsAngelus"/>/<see cref="IsJesusPrayer"/>.
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

    [ObservableProperty]
    private JesusPrayerTarget _jesusPrayerTarget = new JesusPrayerTarget.Count(33);

    [ObservableProperty]
    private ObservableCollection<PrayerReminder> _reminders = [];

    public string Title => IsNew ? "New Favorite" : "Edit Favorite";

    public bool IsRosary => Kind == PrayerKind.Rosary;
    public bool IsAngelus => Kind == PrayerKind.Angelus;
    public bool IsJesusPrayer => Kind == PrayerKind.JesusPrayer;
    public bool IsSpecificMysteryGroup => MysterySelectionMode == MysterySelectionMode.Specific;

    // Traditional Angelus bell times — quick toggles for 6am/noon/6pm, matching Android's
    // AngelusTimeToggleRow. Any reminder outside these three exact times still shows as a normal
    // reminder row (see FavoriteEditorPage.xaml's filtered list).
    public bool Is6AmEnabled => Reminders.Any(r => r.Hour == 6 && r.Minute == 0 && r.IsEnabled);
    public bool IsNoonEnabled => Reminders.Any(r => r.Hour == 12 && r.Minute == 0 && r.IsEnabled);
    public bool Is6PmEnabled => Reminders.Any(r => r.Hour == 18 && r.Minute == 0 && r.IsEnabled);

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
        IncludeApostlesCreed = prayer.Rosary.IncludeApostlesCreed;
        IncludeOpeningPrayers = prayer.Rosary.IncludeOpeningPrayers;
        IncludeFatimaPrayer = prayer.Rosary.IncludeFatimaPrayer;
        EternalRestForDeceased = prayer.Rosary.EternalRestForDeceased;
        MarianAntiphon = prayer.Rosary.MarianAntiphon;
        IncludeStMichaelPrayer = prayer.Rosary.IncludeStMichaelPrayer;
        IncludeFinalSignOfCross = prayer.Rosary.IncludeFinalSignOfCross;
        JesusPrayerTarget = prayer.JesusPrayer.Target;
        Reminders = new ObservableCollection<PrayerReminder>(prayer.Reminders);
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
            IncludeApostlesCreed = IncludeApostlesCreed,
            IncludeOpeningPrayers = IncludeOpeningPrayers,
            IncludeFatimaPrayer = IncludeFatimaPrayer,
            EternalRestForDeceased = EternalRestForDeceased,
            MarianAntiphon = MarianAntiphon,
            IncludeStMichaelPrayer = IncludeStMichaelPrayer,
            IncludeFinalSignOfCross = IncludeFinalSignOfCross,
        },
        JesusPrayer = new JesusPrayerOptions { Target = JesusPrayerTarget },
        Reminders = [.. Reminders],
    };

    partial void OnKindChanged(PrayerKind value)
    {
        OnPropertyChanged(nameof(IsRosary));
        OnPropertyChanged(nameof(IsAngelus));
        OnPropertyChanged(nameof(IsJesusPrayer));
    }

    partial void OnMysterySelectionModeChanged(MysterySelectionMode value) => OnPropertyChanged(nameof(IsSpecificMysteryGroup));

    partial void OnRemindersChanged(ObservableCollection<PrayerReminder> value)
    {
        OnPropertyChanged(nameof(Is6AmEnabled));
        OnPropertyChanged(nameof(IsNoonEnabled));
        OnPropertyChanged(nameof(Is6PmEnabled));
    }

    [RelayCommand]
    private void ToggleAngelusTime(int hour)
    {
        if (Reminders.Any(r => r.Hour == hour && r.Minute == 0 && r.IsEnabled))
        {
            Reminders = new ObservableCollection<PrayerReminder>(Reminders.Where(r => !(r.Hour == hour && r.Minute == 0)));
        }
        else if (Reminders.Any(r => r.Hour == hour && r.Minute == 0))
        {
            Reminders = new ObservableCollection<PrayerReminder>(
                Reminders.Select(r => r.Hour == hour && r.Minute == 0 ? r with { IsEnabled = true } : r));
        }
        else
        {
            Reminders = new ObservableCollection<PrayerReminder>(Reminders.Append(new PrayerReminder(hour, 0)));
        }
    }

    [RelayCommand]
    private void AddReminder() => Reminders = new ObservableCollection<PrayerReminder>(Reminders.Append(new PrayerReminder(9, 0)));

    [RelayCommand]
    private void RemoveReminder(PrayerReminder reminder)
        => Reminders = new ObservableCollection<PrayerReminder>(Reminders.Where(r => r.Id != reminder.Id));

    /// <summary>Invoked directly from the reminder row's TimePicker value-changed handler in
    /// code-behind rather than a Command binding — a TimePicker's new value doesn't naturally
    /// carry which reminder it belongs to as a single CommandParameter.</summary>
    public void UpdateReminderTime(PrayerReminder reminder, int hour, int minute)
        => Reminders = new ObservableCollection<PrayerReminder>(
            Reminders.Select(r => r.Id == reminder.Id ? r with { Hour = hour, Minute = minute } : r));

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
