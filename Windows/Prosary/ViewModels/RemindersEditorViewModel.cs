using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Prosary.Models;

namespace Prosary.ViewModels;

/// <summary>
/// The reminders editing state/commands shared by <see cref="FavoriteEditorViewModel"/>
/// (Rosary/Jesus Prayer's full editor) and <see cref="RemindersOnlyEditorViewModel"/> (the
/// lightweight screen for the generic bundle devotions) — composed in as a child ViewModel rather
/// than duplicated, so both editors manage reminders identically instead of drifting. Mirrors
/// iOS's RemindersSection/Android's RemindersSection.kt.
///
/// A devotion with traditional fixed prayer times ships them in its bundle manifest
/// (<c>reminderPresetHours</c> — the Angelus's 6am/noon/6pm bells) and gets one quick toggle per
/// preset hour plus an explanatory footer, instead of any kind-specific special case here. The
/// three toggle rows themselves are fixed at 6/12/18 in XAML (WinUI's command-binding model makes
/// fully data-driven per-row toggle commands awkward — same reasoning as
/// Home's + menu); each row's visibility is manifest-driven, and 6/12/18
/// covers every preset devotion that exists. A future bundle with different preset hours needs
/// matching rows added here.
/// </summary>
public partial class RemindersEditorViewModel : ObservableObject
{
    [ObservableProperty]
    private ObservableCollection<PrayerReminder> _reminders = [];

    /// <summary>Preset quick-toggle hours from the devotion's bundle manifest; empty for
    /// devotions without traditional fixed times (including Rosary/Jesus Prayer, whose full
    /// editor never sets this).</summary>
    [ObservableProperty]
    private IReadOnlyList<int> _presetHours = [];

    /// <summary>Footer shown under the reminders card (instead of nothing) while any reminder
    /// exists, explaining the presets — from the manifest's <c>reminderPresetFooter</c>.</summary>
    [ObservableProperty]
    private string? _presetFooter;

    public string Preset6AmLabel => new TimeOnly(6, 0).ToString("t");
    public string PresetNoonLabel => new TimeOnly(12, 0).ToString("t");
    public string Preset6PmLabel => new TimeOnly(18, 0).ToString("t");

    public bool HasPresetHours => PresetHours.Count > 0;

    public bool Shows6AmPreset => PresetHours.Contains(6);
    public bool ShowsNoonPreset => PresetHours.Contains(12);
    public bool Shows6PmPreset => PresetHours.Contains(18);

    public bool Is6AmEnabled => Reminders.Any(r => r.Hour == 6 && r.Minute == 0 && r.IsEnabled);
    public bool IsNoonEnabled => Reminders.Any(r => r.Hour == 12 && r.Minute == 0 && r.IsEnabled);
    public bool Is6PmEnabled => Reminders.Any(r => r.Hour == 18 && r.Minute == 0 && r.IsEnabled);

    public bool ShowsPresetFooter => !string.IsNullOrEmpty(PresetFooter) && Reminders.Count > 0;

    /// <summary>Reminders that don't map to one of the preset times — shown in the plain
    /// reminder-row list so a preset time isn't rendered twice. Equal to <see cref="Reminders"/>
    /// outright for devotions without presets.</summary>
    public ObservableCollection<PrayerReminder> CustomReminders => HasPresetHours
        ? new ObservableCollection<PrayerReminder>(Reminders.Where(r => !(PresetHours.Contains(r.Hour) && r.Minute == 0)))
        : Reminders;

    partial void OnPresetHoursChanged(IReadOnlyList<int> value)
    {
        OnPropertyChanged(nameof(HasPresetHours));
        OnPropertyChanged(nameof(Shows6AmPreset));
        OnPropertyChanged(nameof(ShowsNoonPreset));
        OnPropertyChanged(nameof(Shows6PmPreset));
        OnPropertyChanged(nameof(CustomReminders));
    }

    partial void OnPresetFooterChanged(string? value) => OnPropertyChanged(nameof(ShowsPresetFooter));

    partial void OnRemindersChanged(ObservableCollection<PrayerReminder> value)
    {
        OnPropertyChanged(nameof(Is6AmEnabled));
        OnPropertyChanged(nameof(IsNoonEnabled));
        OnPropertyChanged(nameof(Is6PmEnabled));
        OnPropertyChanged(nameof(ShowsPresetFooter));
        OnPropertyChanged(nameof(CustomReminders));
    }

    // Three concrete commands rather than one CommandParameter-driven TogglePresetTime(int) — a
    // plain XAML CommandParameter ("6") would arrive as a string, not an int, so each quick-toggle
    // row gets its own no-argument command instead (same reasoning as the preset list's
    // AddNewRosary/AddNewJesusPrayer).
    [RelayCommand]
    private void TogglePreset6Am() => TogglePresetTime(6);

    [RelayCommand]
    private void TogglePresetNoon() => TogglePresetTime(12);

    [RelayCommand]
    private void TogglePreset6Pm() => TogglePresetTime(18);

    private void TogglePresetTime(int hour)
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
    /// carry which reminder it belongs to as a single CommandParameter. See
    /// FavoriteEditorPage.xaml.cs/RemindersOnlyEditorPage.xaml.cs.</summary>
    public void UpdateReminderTime(PrayerReminder reminder, int hour, int minute)
        => Reminders = new ObservableCollection<PrayerReminder>(
            Reminders.Select(r => r.Id == reminder.Id ? r with { Hour = hour, Minute = minute } : r));
}
