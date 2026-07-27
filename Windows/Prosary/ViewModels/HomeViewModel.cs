using System.Collections.ObjectModel;
using System.Windows.Input;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Prosary.Localization;
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

    /// <summary>Default favorite per discovered generic devotion, keyed by bundle id — unlike the
    /// 7 hardcoded kinds above, a single field per kind doesn't work here since there can be any
    /// number of generic devotions.</summary>
    private readonly Dictionary<string, Prayer?> _defaultCustomDevotions = [];

    /// <summary>Custom-devotion cards keyed by bundle id, so <see cref="LoadAsync"/> can update
    /// each one's subtitle without the <c>Card(PrayerKind)</c> lookup below (which assumes at
    /// most one card per <see cref="PrayerKind"/> — true for the 7 hardcoded kinds, not for
    /// <see cref="PrayerKind.Custom"/>, which every generic devotion shares).</summary>
    private readonly Dictionary<string, DevotionCardModel> _customCardsByBundleId = [];

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

        // Generic (bundle-driven) devotions — one card per discovered bundle, with no hardcoded
        // PrayerKind case. Only one exists today (Trisagion); each reads its icon/title/accent
        // from the bundle's own manifest instead of PrayerKindExtensions.
        foreach (var bundleId in PrayerPackStore.CustomDevotionIds())
        {
            var info = PrayerPackStore.Info(bundleId);
            if (info is null)
            {
                continue;
            }

            var card = new DevotionCardModel
            {
                Kind = PrayerKind.Custom,
                Title = info.DisplayName,
                IconGlyph = GlyphForSystemName(info.IconSystemName),
                AccentColor = ColorForHex(info.AccentColorHex) ?? PrayerKind.Custom.AccentColor(),
                Command = new RelayCommand(() => OpenCustomDevotion(bundleId)),
            };
            _customCardsByBundleId[bundleId] = card;
            DevotionCards.Add(card);
        }
    }

    /// <summary>Maps a bundle manifest's <c>IconSystemName</c> (an SF Symbol name, the iOS
    /// convention) to the nearest Segoe Fluent Icons glyph — mirrors
    /// <c>FavoritesViewModel.GlyphForSystemName</c>.</summary>
    private static string GlyphForSystemName(string? systemName) => systemName switch
    {
        "triangle" => "", // FavoriteStar — see the unverified-codepoint caveat on PrayerKindExtensions.IconGlyph
        _ => "",
    };

    /// <summary>Parses a bundle manifest's <c>AccentColorHex</c> (e.g. "#00796B"), or null if
    /// absent/unparseable — callers fall back to a default accent in that case.</summary>
    private static Color? ColorForHex(string? hex)
    {
        if (string.IsNullOrEmpty(hex) || hex[0] != '#' || (hex.Length != 7 && hex.Length != 9))
        {
            return null;
        }

        try
        {
            var r = Convert.ToByte(hex.Substring(1, 2), 16);
            var g = Convert.ToByte(hex.Substring(3, 2), 16);
            var b = Convert.ToByte(hex.Substring(5, 2), 16);
            var a = hex.Length == 9 ? Convert.ToByte(hex.Substring(7, 2), 16) : (byte)0xFF;
            return Color.FromArgb(a, r, g, b);
        }
        catch (FormatException)
        {
            return null;
        }
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

        foreach (var bundleId in _customCardsByBundleId.Keys)
        {
            var match = all.FirstOrDefault(p => p.Kind == PrayerKind.Custom && p.CustomDevotionId == bundleId && p.IsDefault)
                ?? all.FirstOrDefault(p => p.Kind == PrayerKind.Custom && p.CustomDevotionId == bundleId);
            _defaultCustomDevotions[bundleId] = match;
            _customCardsByBundleId[bundleId].Subtitle = match?.Name ?? "Click to pray";
        }
    }

    private DevotionCardModel Card(PrayerKind kind) => DevotionCards.First(c => c.Kind == kind);

    private void OpenCustomDevotion(string bundleId)
    {
        var prayer = _defaultCustomDevotions.GetValueOrDefault(bundleId);
        Router.Navigate<CustomDevotionFlowPage>(new CustomDevotionFlowParams(prayer?.Id, bundleId));
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
