using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Prosary.Models;

namespace Prosary.ViewModels;

/// <summary>
/// The reminders editing state/commands shared by <see cref="FavoriteEditorViewModel"/>
/// (Rosary/Jesus Prayer's full editor) and <see cref="RemindersOnlyEditorViewModel"/> (the
/// lightweight screen for Angelus/Stations of the Cross/Franciscan Crown/Seven Sorrows/Divine
/// Mercy Chaplet) — composed in as a child ViewModel rather than duplicated, so both editors
/// manage reminders identically instead of drifting. Mirrors iOS's RemindersSection/Android's
/// RemindersSection.kt.
/// </summary>
public partial class RemindersEditorViewModel : ObservableObject
{
    /// <summary>Hours that have dedicated Angelus toggle rows (traditional bell times).</summary>
    private static readonly HashSet<int> AngelusPresetHours = [6, 12, 18];

    [ObservableProperty]
    private PrayerKind _kind = PrayerKind.Rosary;

    [ObservableProperty]
    private ObservableCollection<PrayerReminder> _reminders = [];

    public bool IsAngelus => Kind == PrayerKind.Angelus;

    public bool Is6AmEnabled => Reminders.Any(r => r.Hour == 6 && r.Minute == 0 && r.IsEnabled);
    public bool IsNoonEnabled => Reminders.Any(r => r.Hour == 12 && r.Minute == 0 && r.IsEnabled);
    public bool Is6PmEnabled => Reminders.Any(r => r.Hour == 18 && r.Minute == 0 && r.IsEnabled);

    /// <summary>Reminders that don't map to one of the three traditional Angelus preset times —
    /// shown in the plain reminder-row list so a preset time isn't rendered twice. Equal to
    /// <see cref="Reminders"/> outright for every other kind.</summary>
    public ObservableCollection<PrayerReminder> CustomReminders => IsAngelus
        ? new ObservableCollection<PrayerReminder>(Reminders.Where(r => !(AngelusPresetHours.Contains(r.Hour) && r.Minute == 0)))
        : Reminders;

    partial void OnKindChanged(PrayerKind value)
    {
        OnPropertyChanged(nameof(IsAngelus));
        OnPropertyChanged(nameof(CustomReminders));
    }

    partial void OnRemindersChanged(ObservableCollection<PrayerReminder> value)
    {
        OnPropertyChanged(nameof(Is6AmEnabled));
        OnPropertyChanged(nameof(IsNoonEnabled));
        OnPropertyChanged(nameof(Is6PmEnabled));
        OnPropertyChanged(nameof(CustomReminders));
    }

    // Three concrete commands rather than one CommandParameter-driven ToggleAngelusTime(int) — a
    // plain XAML CommandParameter ("6") would arrive as a string, not an int, so each quick-toggle
    // row gets its own no-argument command instead (same reasoning as FavoritesViewModel's
    // AddNewRosary/AddNewAngelus/AddNewJesusPrayer).
    [RelayCommand]
    private void ToggleAngelus6Am() => ToggleAngelusTime(6);

    [RelayCommand]
    private void ToggleAngelusNoon() => ToggleAngelusTime(12);

    [RelayCommand]
    private void ToggleAngelus6Pm() => ToggleAngelusTime(18);

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
    /// carry which reminder it belongs to as a single CommandParameter. See
    /// FavoriteEditorPage.xaml.cs/RemindersOnlyEditorPage.xaml.cs.</summary>
    public void UpdateReminderTime(PrayerReminder reminder, int hour, int minute)
        => Reminders = new ObservableCollection<PrayerReminder>(
            Reminders.Select(r => r.Id == reminder.Id ? r with { Hour = hour, Minute = minute } : r));
}
