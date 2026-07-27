using System.Collections.ObjectModel;
using System.Windows.Input;
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
/// One devotion's rendering state for a Home card. Adding a new devotion means adding one entry
/// to <see cref="HomeViewModel.DevotionCards"/> — the accent/subtitle/launch logic for each kind
/// can still be as bespoke as it needs to be (e.g. Rosary's mystery-of-the-day accent color), but
/// <c>HomePage.xaml</c> itself no longer hand-rolls a <c>PrayerCard</c> element per kind.
/// </summary>
public partial class DevotionCardModel : ObservableObject
{
    public required PrayerKind Kind { get; init; }
    public required string Title { get; init; }
    public required string IconGlyph { get; init; }
    public required ICommand Command { get; init; }

    [ObservableProperty]
    private string _subtitle = string.Empty;

    [ObservableProperty]
    private Color _accentColor = Colors.Gray;
}

/// <summary>
/// Drives the Home screen's devotion cards — ported from Android's <c>HomeScreen.kt</c>. Each card
/// routes straight to its kind-specific flow page when a default favorite of that kind exists
/// (skipping iOS's generic <c>PrayerDispatchView</c> indirection, per the port plan — this
/// ViewModel already holds the full <see cref="Prayer"/>, not just an id, so there's nothing for
/// a dispatch step to resolve), or to that kind's "getting started" surface otherwise (Favorites
/// for the Rosary, the flow page itself with no favorite for Angelus/Stations, Setup for Jesus
/// Prayer).
/// </summary>
public partial class HomeViewModel : ObservableObject
{
    private readonly IPresetStore _presets;
    private readonly LiturgicalCalendarService _calendar;

    private Prayer? _defaultRosary;
    private Prayer? _defaultAngelus;
    private Prayer? _defaultJesusPrayer;
    private Prayer? _defaultStations;
    private Prayer? _defaultFranciscanCrown;
    private Prayer? _defaultSevenSorrows;
    private Prayer? _defaultDivineMercy;

    public ObservableCollection<DevotionCardModel> DevotionCards { get; }

    public HomeViewModel(IPresetStore presets, LiturgicalCalendarService calendar)
    {
        _presets = presets;
        _calendar = calendar;

        DevotionCards =
        [
            new DevotionCardModel { Kind = PrayerKind.Rosary, Title = PrayerKind.Rosary.DisplayName(), IconGlyph = "", Command = OpenRosaryCommand },
            new DevotionCardModel { Kind = PrayerKind.Angelus, Title = PrayerKind.Angelus.DisplayName(), IconGlyph = "", Command = OpenAngelusCommand },
            new DevotionCardModel { Kind = PrayerKind.JesusPrayer, Title = PrayerKind.JesusPrayer.DisplayName(), IconGlyph = "", Command = OpenJesusPrayerCommand },
            new DevotionCardModel { Kind = PrayerKind.StationsOfTheCross, Title = PrayerKind.StationsOfTheCross.DisplayName(), IconGlyph = "", Command = OpenStationsOfTheCrossCommand },
            new DevotionCardModel { Kind = PrayerKind.FranciscanCrown, Title = PrayerKind.FranciscanCrown.DisplayName(), IconGlyph = "", Command = OpenFranciscanCrownCommand },
            new DevotionCardModel { Kind = PrayerKind.SevenSorrows, Title = PrayerKind.SevenSorrows.DisplayName(), IconGlyph = "", Command = OpenSevenSorrowsCommand },
            new DevotionCardModel { Kind = PrayerKind.DivineMercyChaplet, Title = PrayerKind.DivineMercyChaplet.DisplayName(), IconGlyph = "", Command = OpenDivineMercyChapletCommand },
        ];
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
        _defaultStations = all.FirstOrDefault(p => p.Kind == PrayerKind.StationsOfTheCross && p.IsDefault)
            ?? all.FirstOrDefault(p => p.Kind == PrayerKind.StationsOfTheCross);
        _defaultFranciscanCrown = all.FirstOrDefault(p => p.Kind == PrayerKind.FranciscanCrown && p.IsDefault)
            ?? all.FirstOrDefault(p => p.Kind == PrayerKind.FranciscanCrown);
        _defaultSevenSorrows = all.FirstOrDefault(p => p.Kind == PrayerKind.SevenSorrows && p.IsDefault)
            ?? all.FirstOrDefault(p => p.Kind == PrayerKind.SevenSorrows);
        _defaultDivineMercy = all.FirstOrDefault(p => p.Kind == PrayerKind.DivineMercyChaplet && p.IsDefault)
            ?? all.FirstOrDefault(p => p.Kind == PrayerKind.DivineMercyChaplet);

        var rosaryParts = new List<string> { $"Today: {todayGroup.DisplayName()}" };
        if (_defaultRosary is { } rosary)
        {
            rosaryParts.Add(rosary.Name);
        }

        Card(PrayerKind.Rosary).AccentColor = todayGroup.AccentColor();
        Card(PrayerKind.Rosary).Subtitle = string.Join(" • ", rosaryParts);

        Card(PrayerKind.Angelus).AccentColor = PrayerKind.Angelus.AccentColor();
        Card(PrayerKind.Angelus).Subtitle = _defaultAngelus?.Name ?? "Click to pray";

        Card(PrayerKind.JesusPrayer).AccentColor = PrayerKind.JesusPrayer.AccentColor();
        Card(PrayerKind.JesusPrayer).Subtitle = _defaultJesusPrayer is { } jp
            ? $"{jp.Name} • {jp.JesusPrayer.TargetDisplayName}"
            : "Click to set up";

        Card(PrayerKind.StationsOfTheCross).AccentColor = PrayerKind.StationsOfTheCross.AccentColor();
        Card(PrayerKind.StationsOfTheCross).Subtitle = _defaultStations?.Name ?? "Click to pray";

        Card(PrayerKind.FranciscanCrown).AccentColor = PrayerKind.FranciscanCrown.AccentColor();
        Card(PrayerKind.FranciscanCrown).Subtitle = _defaultFranciscanCrown?.Name ?? "Click to pray";

        Card(PrayerKind.SevenSorrows).AccentColor = PrayerKind.SevenSorrows.AccentColor();
        Card(PrayerKind.SevenSorrows).Subtitle = _defaultSevenSorrows?.Name ?? "Click to pray";

        Card(PrayerKind.DivineMercyChaplet).AccentColor = PrayerKind.DivineMercyChaplet.AccentColor();
        Card(PrayerKind.DivineMercyChaplet).Subtitle = _defaultDivineMercy?.Name ?? "Click to pray";
    }

    private DevotionCardModel Card(PrayerKind kind) => DevotionCards.First(c => c.Kind == kind);

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
    private void OpenStationsOfTheCross()
    {
        Router.Navigate<StationsFlowPage>(_defaultStations?.Id);
    }

    [RelayCommand]
    private void OpenFranciscanCrown()
    {
        Router.Navigate<FranciscanCrownFlowPage>(_defaultFranciscanCrown?.Id);
    }

    [RelayCommand]
    private void OpenSevenSorrows()
    {
        Router.Navigate<SevenSorrowsFlowPage>(_defaultSevenSorrows?.Id);
    }

    [RelayCommand]
    private void OpenDivineMercyChaplet()
    {
        Router.Navigate<DivineMercyFlowPage>(_defaultDivineMercy?.Id);
    }

    [RelayCommand]
    private void OpenFavorites() => Router.Navigate<FavoritesListPage>();

    [RelayCommand]
    private void OpenSettings() => Router.Navigate<SettingsPage>();

    [RelayCommand]
    private void OpenAbout() => Router.Navigate<AboutPage>();
}
