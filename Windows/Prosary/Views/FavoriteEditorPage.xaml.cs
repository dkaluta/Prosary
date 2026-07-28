using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;
using Prosary.Models;
using Prosary.Navigation;
using Prosary.ViewModels;

namespace Prosary.Views;

/// <summary>Navigation parameter: <see cref="FavoriteEditorParams"/>.</summary>
public sealed partial class FavoriteEditorPage : Page
{
    public FavoriteEditorViewModel ViewModel { get; }

    public FavoriteEditorPage()
    {
        ViewModel = App.Services.GetRequiredService<FavoriteEditorViewModel>();
        InitializeComponent();
    }

    protected override async void OnNavigatedTo(NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);
        var parameters = e.Parameter as FavoriteEditorParams ?? new FavoriteEditorParams(null);
        await ViewModel.LoadAsync(parameters.PrayerId, parameters.NewFavoriteKind);
    }

    // TimePicker has no per-item command hook, so its value-changed event is handled directly
    // here — the sender's DataContext is the PrayerReminder this row is bound to (set by the
    // ItemsControl's DataTemplate), matching the sibling Delete button's {Binding} parameter.
    private void OnReminderTimeChanged(object sender, TimePickerValueChangedEventArgs e)
    {
        if (sender is FrameworkElement { DataContext: PrayerReminder reminder })
        {
            ViewModel.RemindersEditor.UpdateReminderTime(reminder, e.NewTime.Hours, e.NewTime.Minutes);
        }
    }

}
