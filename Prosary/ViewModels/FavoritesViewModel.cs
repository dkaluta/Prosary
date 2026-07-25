using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Prosary.Models;
using Prosary.Navigation;
using Prosary.Persistence;
using Prosary.Services;
using Prosary.Views;

namespace Prosary.ViewModels;

/// <summary>
/// Drives the Favorites list — ported from Android's <c>FavoritesListScreen.kt</c>, grouped by
/// <see cref="PrayerKind"/> into three separate collections (one per section) rather than a
/// single flat list a XAML <c>CollectionViewSource</c> would need to re-group, since WinUI3 has
/// no built-in sticky-header-by-key list control as convenient as Compose's <c>LazyColumn</c>
/// <c>stickyHeader</c>.
/// </summary>
public partial class FavoritesViewModel : ObservableObject
{
    private readonly IPresetStore _presets;
    private readonly IReminderScheduler _scheduler;

    [ObservableProperty]
    private ObservableCollection<Prayer> _rosaryFavorites = [];

    [ObservableProperty]
    private ObservableCollection<Prayer> _angelusFavorites = [];

    [ObservableProperty]
    private ObservableCollection<Prayer> _jesusPrayerFavorites = [];

    public FavoritesViewModel(IPresetStore presets, IReminderScheduler scheduler)
    {
        _presets = presets;
        _scheduler = scheduler;
    }

    /// <summary>Reloads the list — called on first navigation and again whenever the page is
    /// navigated back to (e.g. after the editor saves), since favorites can change out from under
    /// this page while it's off-screen.</summary>
    public async Task LoadAsync()
    {
        var all = await _presets.GetAllAsync();
        RosaryFavorites = new ObservableCollection<Prayer>(all.Where(p => p.Kind == PrayerKind.Rosary));
        AngelusFavorites = new ObservableCollection<Prayer>(all.Where(p => p.Kind == PrayerKind.Angelus));
        JesusPrayerFavorites = new ObservableCollection<Prayer>(all.Where(p => p.Kind == PrayerKind.JesusPrayer));
    }

    [RelayCommand]
    private void Pray(Prayer prayer)
    {
        switch (prayer.Kind)
        {
            case PrayerKind.Rosary:
                Router.Navigate<RosaryPrayerPage>(prayer.Id);
                break;
            case PrayerKind.Angelus:
                Router.Navigate<AngelusFlowPage>(prayer.Id);
                break;
            case PrayerKind.JesusPrayer:
                Router.Navigate<JesusPrayerFlowPage>(new JesusPrayerFlowParams(prayer.Id, null));
                break;
        }
    }

    [RelayCommand]
    private void Edit(Prayer prayer) => Router.Navigate<FavoriteEditorPage>(new FavoriteEditorParams(prayer.Id));

    [RelayCommand]
    private void AddNew(PrayerKind kind) => Router.Navigate<FavoriteEditorPage>(new FavoriteEditorParams(null, kind));

    [RelayCommand]
    private async Task MakeDefaultAsync(Prayer prayer)
    {
        await _presets.SaveAsync(prayer with { IsDefault = true });
        await LoadAsync();
    }

    [RelayCommand]
    private async Task DeleteAsync(Prayer prayer)
    {
        _scheduler.RemoveAll(prayer);
        await _presets.DeleteAsync(prayer);
        await LoadAsync();
    }

    [RelayCommand]
    private void Back() => Router.GoBack();
}
