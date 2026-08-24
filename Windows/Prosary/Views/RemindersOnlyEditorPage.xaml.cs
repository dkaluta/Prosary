using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;
using Prosary.Models;
using Prosary.ViewModels;

namespace Prosary.Views;

/// <summary>Navigation parameter: the saved <see cref="Prosary.Models.Prayer"/>'s
/// <see cref="Guid"/> id.</summary>
public sealed partial class RemindersOnlyEditorPage : Page
{
    public RemindersOnlyEditorViewModel ViewModel { get; }

    public RemindersOnlyEditorPage()
    {
        ViewModel = App.Services.GetRequiredService<RemindersOnlyEditorViewModel>();
        InitializeComponent();
    }

    protected override async void OnNavigatedTo(NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);
        if (e.Parameter is Guid prayerId)
        {
            await ViewModel.LoadAsync(prayerId);
        }
    }

    // TimePicker has no per-item command hook, so its value-changed event is handled directly
    // here — the sender's DataContext is the PrayerReminder this row is bound to (set by the
    // ItemsControl's DataTemplate), matching the sibling Delete button's {Binding} parameter.
    // See FavoriteEditorPage.xaml.cs, which handles the same event identically.
    private void OnReminderTimeChanged(object sender, TimePickerValueChangedEventArgs e)
    {
        if (sender is FrameworkElement { DataContext: PrayerReminder reminder })
        {
            ViewModel.RemindersEditor.UpdateReminderTime(reminder, e.NewTime.Hours, e.NewTime.Minutes);
        }
    }

    // Is6AmEnabled/IsNoonEnabled/Is6PmEnabled are read-only (derived from Reminders), so these
    // ToggleSwitches bind Mode=OneWay and route the actual state change through the matching
    // command instead of a direct TwoWay bind.
    private void OnPreset6AmToggled(object sender, RoutedEventArgs e) => ViewModel.RemindersEditor.TogglePreset6AmCommand.Execute(null);

    private void OnPresetNoonToggled(object sender, RoutedEventArgs e) => ViewModel.RemindersEditor.TogglePresetNoonCommand.Execute(null);

    private void OnPreset6PmToggled(object sender, RoutedEventArgs e) => ViewModel.RemindersEditor.TogglePreset6PmCommand.Execute(null);
}
