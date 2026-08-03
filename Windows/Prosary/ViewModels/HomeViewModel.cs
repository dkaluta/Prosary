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
using Microsoft.UI.Xaml;
using Windows.UI;

namespace Prosary.ViewModels;

/// <summary>
/// One devotion's rendering state for a Home card. See <see cref="HomeViewModel.DevotionCards"/>.
/// </summary>
public partial class DevotionCardModel : ObservableObject
{
    public required string Id { get; init; }
    public required string Title { get; init; }
    public required string IconGlyph { get; init; }
    public required ICommand Command { get; init; }

    [ObservableProperty]
    private string _subtitle = string.Empty;

    [ObservableProperty]
    private Color _accentColor = Color.FromArgb(0xFF, 0x80, 0x80, 0x80);
}

/// <summary>
/// Drives the Home screen's devotion cards — one card per devotion: the Rosary first (the app's
/// namesake), then every generic (bundle-driven) devotion in pack-load order — icon/title/accent
/// read from each bundle's own manifest, nothing hardcoded here — and the Jesus Prayer (the
/// counter-based odd one out) last. Adding a devotion means shipping a bundle; this ViewModel
/// doesn't change. Each card routes straight to its flow page when a default favorite exists, or
/// to that devotion's "getting started" surface otherwise (Favorites for the Rosary, the flow
/// page itself with no favorite for generic devotions, Setup for Jesus Prayer).
/// </summary>
public partial class HomeViewModel : ObservableObject
{
    private readonly IPresetStore _presets;
    private readonly LiturgicalCalendarService _calendar;

    private Prayer? _defaultRosary;
    private Prayer? _defaultJesusPrayer;

    /// <summary>Default favorite per discovered generic devotion, keyed by bundle id.</summary>
    private readonly Dictionary<string, Prayer?> _defaultCustomDevotions = [];

    private readonly Dictionary<string, DevotionCardModel> _customCardsByBundleId = [];

    public ObservableCollection<DevotionCardModel> DevotionCards { get; }

    // The Home "Today" section — the day's feast per the Holy Land (Latin Patriarchate of
    // Jerusalem) calendar and the Pope's monthly prayer intention; null hides each row.
    public FeastDay? TodayFeast { get; } = TodayInfoStore.Feast(DateOnly.FromDateTime(DateTime.Today));

    public PopeIntention? MonthIntention { get; } = TodayInfoStore.Intention(DateOnly.FromDateTime(DateTime.Today));

    public bool ShowsTodaySection => TodayFeast is not null || MonthIntention is not null;

    public bool ShowsTodayFeast => TodayFeast is not null;

    public bool ShowsMonthIntention => MonthIntention is not null;

    public string TodayFeastTitle => TodayFeast?.Title ?? string.Empty;

    public string TodayFeastRank => TodayFeast?.Rank ?? string.Empty;

    public string MonthIntentionTitle => MonthIntention is { } intention
        ? string.Format(Loc.Tr("home_pope_intention", "The Pope’s intention: {0}"), intention.Title)
        : string.Empty;

    public string MonthIntentionText => MonthIntention?.Text ?? string.Empty;

    public HomeViewModel(IPresetStore presets, LiturgicalCalendarService calendar)
    {
        _presets = presets;
        _calendar = calendar;

        DevotionCards =
        [
            new DevotionCardModel { Id = "rosary", Title = PrayerKind.Rosary.DisplayName(), IconGlyph = "\uEA3A", Command = OpenRosaryCommand }, // CircleRing
        ];

        foreach (var bundleId in PrayerPackStore.CustomDevotionIds())
        {
            var info = PrayerPackStore.Info(bundleId);
            if (info is null)
            {
                continue;
            }

            var card = new DevotionCardModel
            {
                Id = $"custom.{bundleId}",
                Title = info.LocalizedDisplayName,
                IconGlyph = info.IconGlyph ?? GlyphForSystemName(info.IconSystemName),
                AccentColor = CustomAccent(info),
                Command = new RelayCommand(() => OpenCustomDevotion(bundleId)),
            };
            _customCardsByBundleId[bundleId] = card;
            DevotionCards.Add(card);
        }

        DevotionCards.Add(new DevotionCardModel
        {
            Id = "jesusPrayer", Title = PrayerKind.JesusPrayer.DisplayName(), IconGlyph = "\uEB52", // HeartFill
            Command = OpenJesusPrayerCommand,
        });

        ApplySavedOrder();
    }

    /// <summary>Re-sorts <see cref="DevotionCards"/> by the persisted per-user order
    /// (v0.7, Gamaliel item 2 — the approved drag-handle pattern lives in HomePage's
    /// reorder dialog; this applies whatever it saved).</summary>
    public void ApplySavedOrder()
    {
        var ordered = HomeOrder.Apply(DevotionCards.ToList(), c => c.Id);
        for (var target = 0; target < ordered.Count; target++)
        {
            var current = DevotionCards.IndexOf(ordered[target]);
            if (current != target)
            {
                DevotionCards.Move(current, target);
            }
        }
    }

    [RelayCommand]
    private void MoveCardToTop(DevotionCardModel card)
    {
        HomeOrder.MoveToTop(card.Id, DevotionCards.Select(c => c.Id));
        ApplySavedOrder();
    }

    /// <summary>Called by the reorder dialog after a drag-drop: persists the ListView's new
    /// sequence and mirrors it onto the Home list.</summary>
    public void CommitOrder(IEnumerable<string> ids)
    {
        HomeOrder.Save(ids);
        ApplySavedOrder();
    }

    public void ResetOrder()
    {
        HomeOrder.Reset();
        // Directory order can't be recovered by re-sorting alone (the collection is already
        // user-ordered), so just leave the current arrangement until next launch — the reset
        // dialog says so.
    }

    /// <summary>Maps a bundle manifest's <c>IconSystemName</c> (an SF Symbol name, the iOS
    /// convention) to the nearest Segoe Fluent Icons glyph. Codepoints verified against
    /// Microsoft's Segoe Fluent Icons documentation (the font has no crown or plain-triangle
    /// name of its own — PartyLeader renders a crown, IncidentTriangle a plain triangle).</summary>
    internal static string GlyphForSystemName(string? systemName) => systemName switch
    {
        "bell" => "\uEA8F",        // Ringer
        "figure.walk" => "\uE805", // Walk
        "crown" => "\uECA7",       // PartyLeader (a crown)
        "drop" => "\uEB42",        // Drop
        "sun.max" => "\uE706",     // Brightness (a sun)
        "triangle" => "\uE814",    // IncidentTriangle
        _ => "\uE734",             // FavoriteStar
    };

    /// <summary>Accent color for a generic devotion's card, honoring the manifest's light/dark
    /// pair — read once against the app-level requested theme (Home cards don't live-retheme;
    /// the page is rebuilt on navigation anyway).</summary>
    internal static Color CustomAccent(CustomDevotionInfo info)
    {
        var isDark = Application.Current.RequestedTheme == ApplicationTheme.Dark;
        var hex = isDark ? info.AccentColorDarkHex ?? info.AccentColorHex : info.AccentColorHex;
        return ColorForHex(hex) ?? PrayerKind.Custom.AccentColor();
    }

    /// <summary>Parses a bundle manifest's <c>AccentColorHex</c> (e.g. "#00796B"), or null if
    /// absent/unparseable — callers fall back to a default accent in that case.</summary>
    internal static Color? ColorForHex(string? hex)
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
        _defaultJesusPrayer = all.FirstOrDefault(p => p.Kind == PrayerKind.JesusPrayer && p.IsDefault)
            ?? all.FirstOrDefault(p => p.Kind == PrayerKind.JesusPrayer);

        var rosaryParts = new List<string> { string.Format(Loc.Tr("home_today", "Today: {0}"), todayGroup.UiName()) };
        if (_defaultRosary is { } rosary)
        {
            rosaryParts.Add(rosary.Name);
        }

        Card("rosary").AccentColor = todayGroup.AccentColor();
        Card("rosary").Subtitle = string.Join(" • ", rosaryParts);

        Card("jesusPrayer").AccentColor = PrayerKind.JesusPrayer.AccentColor();
        Card("jesusPrayer").Subtitle = _defaultJesusPrayer is { } jp
            ? $"{jp.Name} • {jp.JesusPrayer.TargetDisplayName}"
            : Loc.Tr("home_click_to_set_up", "Click to set up");

        foreach (var bundleId in _customCardsByBundleId.Keys)
        {
            var match = all.FirstOrDefault(p => p.Kind == PrayerKind.Custom && p.CustomDevotionId == bundleId && p.IsDefault)
                ?? all.FirstOrDefault(p => p.Kind == PrayerKind.Custom && p.CustomDevotionId == bundleId);
            _defaultCustomDevotions[bundleId] = match;
            _customCardsByBundleId[bundleId].Subtitle = match?.Name ?? Loc.Tr("home_click_to_pray", "Click to pray");
        }
    }

    private DevotionCardModel Card(string id) => DevotionCards.First(c => c.Id == id);

    private void OpenCustomDevotion(string bundleId)
    {
        var prayer = _defaultCustomDevotions.GetValueOrDefault(bundleId);
        Router.Navigate<CustomDevotionFlowPage>(new CustomDevotionFlowParams(prayer?.Id, bundleId));
    }

    [RelayCommand]
    private void OpenRosary()
    {
        // The picker handles every case itself (default preset up top, ad-hoc quick pray, the
        // remaining presets) — including having no presets at all.
        Router.Navigate<RosaryPresetPickerPage>();
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
