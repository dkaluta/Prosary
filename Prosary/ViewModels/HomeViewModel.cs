using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Prosary.Models;
using Prosary.Navigation;
using Prosary.Persistence;
using Prosary.Services;
using Prosary.Views;
using Microsoft.UI;
using Windows.UI;

namespace Prosary.ViewModels;

/// <summary>
/// Drives the Home screen's three devotion cards — ported from Android's <c>HomeScreen.kt</c>.
/// Each card routes straight to its kind-specific flow page when a default favorite of that kind
/// exists (skipping iOS's generic <c>PrayerDispatchView</c> indirection, per the port plan — this
/// ViewModel already holds the full <see cref="Prayer"/>, not just an id, so there's nothing for
/// a dispatch step to resolve), or to that kind's "getting started" surface otherwise (Favorites
/// for the Rosary, the flow page itself with no favorite for Angelus, Setup for Jesus Prayer).
/// </summary>
public partial class HomeViewModel : ObservableObject
{
    private readonly IPresetStore _presets;
    private readonly LiturgicalCalendarService _calendar;

    private Prayer? _defaultRosary;
    private Prayer? _defaultAngelus;
    private Prayer? _defaultJesusPrayer;

    [ObservableProperty]
    private string _rosarySubtitle = string.Empty;

    [ObservableProperty]
    private string _angelusSubtitle = "Tap to pray";

    [ObservableProperty]
    private string _jesusPrayerSubtitle = "Tap to set up";

    [ObservableProperty]
    private Color _rosaryAccent = Color.FromArgb(0xFF, 0x7A, 0x1F, 0x3D);

    // Fixed accent colors for the other two cards, matching iOS/Android's HomeView.
    public Color AngelusAccent { get; } = Color.FromArgb(0xFF, 0x8B, 0x69, 0x14);

    public Color JesusPrayerAccent { get; } = Color.FromArgb(0xFF, 0x8B, 0x1A, 0x1A);

    public HomeViewModel(IPresetStore presets, LiturgicalCalendarService calendar)
    {
        _presets = presets;
        _calendar = calendar;
    }

    public async Task LoadAsync()
    {
        var todayGroup = _calendar.GetMysteryGroupForToday();
        var all = await _presets.GetAllAsync();

        _defaultRosary = all.FirstOrDefault(p => p.Kind == PrayerKind.Rosary && p.IsDefault)
            ?? all.FirstOrDefault(p => p.Kind == PrayerKind.Rosary);
        _defaultAngelus = all.FirstOrDefault(p => p.Kind == PrayerKind.Angelus && p.IsDefault)
            ?? all.FirstOrDefault(p => p.Kind == PrayerKind.Angelus);
        _defaultJesusPrayer = all.FirstOrDefault(p => p.Kind == PrayerKind.JesusPrayer && p.IsDefault)
            ?? all.FirstOrDefault(p => p.Kind == PrayerKind.JesusPrayer);

        RosaryAccent = todayGroup.AccentColor();

        var rosaryParts = new List<string>();
        rosaryParts.Add($"Today: {todayGroup.DisplayName()}");
        if (_defaultRosary is { } rosary)
        {
            rosaryParts.Add(rosary.Name);
        }
        RosarySubtitle = string.Join(" • ", rosaryParts);

        AngelusSubtitle = _defaultAngelus?.Name ?? "Tap to pray";
        JesusPrayerSubtitle = _defaultJesusPrayer is { } jp
            ? $"{jp.Name} • {jp.JesusPrayer.TargetDisplayName}"
            : "Tap to set up";
    }

    [RelayCommand]
    private void OpenRosary()
    {
        if (_defaultRosary is { } prayer)
        {
            Router.Navigate<RosaryPrayerPage>(prayer.Id);
        }
        else
        {
            Router.Navigate<FavoritesListPage>();
        }
    }

    [RelayCommand]
    private void OpenAngelus()
    {
        Router.Navigate<AngelusFlowPage>(_defaultAngelus?.Id);
    }

    [RelayCommand]
    private void OpenJesusPrayer()
    {
        if (_defaultJesusPrayer is { } prayer)
        {
            Router.Navigate<JesusPrayerFlowPage>(new JesusPrayerFlowParams(prayer.Id, null));
        }
        else
        {
            Router.Navigate<JesusPrayerSetupPage>();
        }
    }

    [RelayCommand]
    private void OpenFavorites() => Router.Navigate<FavoritesListPage>();

    [RelayCommand]
    private void OpenSettings() => Router.Navigate<SettingsPage>();

    [RelayCommand]
    private void OpenAbout() => Router.Navigate<AboutPage>();
}
