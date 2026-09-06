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
    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(DisplaySubtitle))]
    private string _title = string.Empty;
    public required string IconGlyph { get; init; }
    public required ICommand Command { get; init; }

    /// <summary>Whether this devotion has saved presets worth a menu item — the Rosary does,
    /// the rest are configured in their own flow. Mirrors iOS's DevotionRow.presetsRoute.</summary>
    public bool HasSavedPresets { get; init; }
    public bool CanHaveReminders => !Id.StartsWith("basic:", StringComparison.Ordinal);

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(DisplaySubtitle))]
    private string _subtitle = string.Empty;

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(DisplaySubtitle))]
    private string _interfaceSubtitle = string.Empty;

    public string DisplaySubtitle => string.Join(Environment.NewLine,
        new[] { InterfaceSubtitle, Subtitle }.Where(text => !string.IsNullOrWhiteSpace(text)
            && !string.Equals(text.Trim(), Title.Trim(), StringComparison.Ordinal)).Distinct());

    [ObservableProperty]
    private Color _accentColor = Color.FromArgb(0xFF, 0x80, 0x80, 0x80);
}

/// <summary>
/// Drives the Pray tab's devotion cards — one card per devotion: the Rosary first (the app's
/// namesake), then every generic (bundle-driven) devotion in pack-load order — icon/title/accent
/// read from each bundle's own manifest, nothing hardcoded here — and the Jesus Prayer (the
/// counter-based odd one out) last. Adding a devotion means shipping a bundle; this ViewModel
/// doesn't change. Each card routes straight to its flow page when a default favorite exists, or
/// to that devotion's "getting started" surface otherwise (the preset picker for the Rosary, the flow
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

    /// <summary>Every devotion the app can pray, pinned or not — <see cref="DevotionCards"/> is
    /// the subset that Pray shows.</summary>
    private readonly List<DevotionCardModel> _allCards = [];

    public ObservableCollection<DevotionCardModel> DevotionCards { get; } = [];

    /// <summary>What the + button offers: everything installed that is not on Pray.</summary>
    public ObservableCollection<DevotionCardModel> UnpinnedCards { get; } = [];

    public bool HasUnpinnedCards => UnpinnedCards.Count > 0;

    // The Home "Today" section is refreshed every time the existing page is navigated back to,
    // so changes made in Settings (including a calendar switch) take effect immediately.
    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(ShowsTodayFeast))]
    [NotifyPropertyChangedFor(nameof(TodayFeastTitle))]
    [NotifyPropertyChangedFor(nameof(TodayFeastRank))]
    private FeastDay? _todayFeast;

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(ShowsMonthIntention))]
    [NotifyPropertyChangedFor(nameof(MonthIntentionTitle))]
    [NotifyPropertyChangedFor(nameof(MonthIntentionText))]
    private PopeIntention? _monthIntention;

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(TodayDayText))]
    [NotifyPropertyChangedFor(nameof(ShowsTodayDay))]
    private LiturgicalDayInfo _todayDay = TodayInfoStore.LiturgicalDay(DateOnly.FromDateTime(DateTime.Today));

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(IsSelectedDateToday))]
    [NotifyPropertyChangedFor(nameof(SelectedDateText))]
    [NotifyPropertyChangedFor(nameof(SelectedDateAccessibilityLabel))]
    [NotifyCanExecuteChangedFor(nameof(YesterdayCommand))]
    [NotifyCanExecuteChangedFor(nameof(TomorrowCommand))]
    private DateTimeOffset? _selectedTodayDate = new DateTimeOffset(DateTime.Today);

    public DateTimeOffset MinimumTodayDate => new(new DateTime(1900, 1, 1));
    public DateTimeOffset MaximumTodayDate => new(new DateTime(2100, 12, 31));
    public DateOnly SelectedDate => DateOnly.FromDateTime((SelectedTodayDate ?? new DateTimeOffset(DateTime.Today)).Date);
    public bool IsSelectedDateToday => SelectedDate == DateOnly.FromDateTime(DateTime.Today);
    public bool CanSelectYesterday => SelectedDate > DateOnly.FromDateTime(MinimumTodayDate.Date);
    public bool CanSelectTomorrow => SelectedDate < DateOnly.FromDateTime(MaximumTodayDate.Date);

    public string SelectedDateText
    {
        get
        {
            var culture = (System.Globalization.CultureInfo)System.Globalization.CultureInfo
                .GetCultureInfo(UiLanguageCatalog.ResourceTag(TodayLanguage)).Clone();
            culture.DateTimeFormat.Calendar = new System.Globalization.GregorianCalendar();
            return SelectedDate.ToString("d MMMM yyyy", culture);
        }
    }

    public string SelectedDateAccessibilityLabel => string.Format(
        Loc.Tr("home_today_choose_date", "Choose a date: {0}", TodayLanguage), SelectedDateText);

    partial void OnSelectedTodayDateChanged(DateTimeOffset? value)
    {
        ShowsFullCitations = false;
        RefreshToday();
    }

    [RelayCommand(CanExecute = nameof(CanSelectYesterday))]
    private void Yesterday() => SelectedTodayDate = new DateTimeOffset(SelectedDate.AddDays(-1).ToDateTime(TimeOnly.MinValue));

    [RelayCommand(CanExecute = nameof(CanSelectTomorrow))]
    private void Tomorrow() => SelectedTodayDate = new DateTimeOffset(SelectedDate.AddDays(1).ToDateTime(TimeOnly.MinValue));

    [RelayCommand]
    private void SelectToday() => SelectedTodayDate = new DateTimeOffset(DateTime.Today);

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(ShowsTodayReadings))]
    [NotifyPropertyChangedFor(nameof(ReadingsText))]
    private IReadOnlyList<ReadingCitation> _todayReadings = [];

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(ShowsTodayTorahPortion))]
    [NotifyPropertyChangedFor(nameof(TorahPortionHeading))]
    [NotifyPropertyChangedFor(nameof(TorahPortionTitle))]
    [NotifyPropertyChangedFor(nameof(TorahPortionReadings))]
    private TorahPortion? _todayTorahPortion;

    public bool ShowsTodayTorahPortion => TodayTorahPortion is not null;
    public string TorahPortionHeading => TodayTorahPortion?.IsHoliday == true
        ? Loc.Tr("home_today_torah_festival", "Festival Torah reading", TodayLanguage)
        : Loc.Tr("home_today_torah_portion", "Weekly Torah portion", TodayLanguage);
    public string TorahPortionTitle => TodayTorahPortion?.LocalizedTitle(TodayLanguage) ?? "";
    public string TorahPortionReadings => TodayTorahPortion?.LocalizedReadings(TodayLanguage) ?? "";

    public string TodayLanguage => UiLanguageCatalog.Current;
    public bool TodayIsRightToLeft => UiLanguageCatalog.IsRightToLeft(TodayLanguage);

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(ReadingsText))]
    [NotifyPropertyChangedFor(nameof(CitationButtonText))]
    private bool _showsFullCitations;

    public bool ShowsTodaySection => true;

    public bool ShowsTodayFeast => TodayFeast is not null;

    public bool ShowsMonthIntention => MonthIntention is not null;

    public bool ShowsTodayReadings => TodayReadings.Count > 0;

    public bool ShowsTodayDay => TodayDay.IsVisible;

    public string TodayDayText => TodayDay.Localized(TodayLanguage);

    public TextAlignment TodayTextAlignment => TodayIsRightToLeft ? TextAlignment.Right : TextAlignment.Left;

    public HorizontalAlignment TodayContentAlignment => TodayIsRightToLeft
        ? HorizontalAlignment.Right : HorizontalAlignment.Left;

    public string TodayFeastTitle => TodayFeast?.LocalizedTitle(TodayLanguage) ?? string.Empty;

    public string TodayFeastRank => TodayFeast?.LocalizedRank(TodayLanguage) ?? string.Empty;

    public string MonthIntentionTitle => MonthIntention is { } intention
        ? string.Format(Loc.Tr("home_pope_intention", "The Pope’s intention: {0}", TodayLanguage), intention.LocalizedTitle(TodayLanguage))
        : string.Empty;

    public string MonthIntentionText => MonthIntention?.LocalizedText(TodayLanguage) ?? string.Empty;

    public string TodayReadingsTitle => Loc.Tr("HomeTodayReadings/Text", "Today’s readings", TodayLanguage);

    public string ReadingsText => ShowsFullCitations
        ? string.Join(Environment.NewLine, TodayReadings.Select(r => r.LocalizedFull(TodayLanguage)))
        : string.Join(", ", TodayReadings.Select(r => r.LocalizedShort(TodayLanguage)));

    public string CitationButtonText => ShowsFullCitations
        ? Loc.Tr("home_today_compact_citations", "Show shorthand", TodayLanguage)
        : Loc.Tr("home_today_full_citations", "View full citations", TodayLanguage);

    [RelayCommand]
    private void ToggleCitations() => ShowsFullCitations = !ShowsFullCitations;

    public HomeViewModel(IPresetStore presets, LiturgicalCalendarService calendar)
    {
        _presets = presets;
        _calendar = calendar;
        RefreshToday();

        _allCards.Add(
            new DevotionCardModel
            {
                Id = "rosary", Title = PrayerKind.Rosary.DisplayName(), IconGlyph = "\uEA3A", // CircleRing
                Command = OpenRosaryCommand, HasSavedPresets = true,
            });

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
            _allCards.Add(card);
        }

        _allCards.Add(new DevotionCardModel
        {
            Id = "jesusPrayer", Title = PrayerKind.JesusPrayer.DisplayName(), IconGlyph = "\uEB52", // HeartFill
            Command = OpenJesusPrayerCommand,
        });
    }

    /// <summary>The devotion id a card pins under — "custom.trisagion" orders, "trisagion"
    /// pins.</summary>
    private static string DevotionIdOf(DevotionCardModel card) =>
        card.Id.StartsWith("custom.", StringComparison.Ordinal) ? card.Id["custom.".Length..] : card.Id;

    /// <summary>A devotion counts as pinned by default when it already has a saved configuration,
    /// which is what keeps a fresh install from opening on an empty Pray page.</summary>
    private List<string> ImpliedPinnedIds()
    {
        var ids = new List<string> { "rosary" };
        ids.AddRange(_defaultCustomDevotions.Where(pair => pair.Value is not null).Select(pair => pair.Key));
        if (_defaultJesusPrayer is not null)
        {
            ids.Add("jesusPrayer");
        }

        return ids;
    }

    /// <summary>Pray is the pinned list: a devotion appears here because you put it here.
    /// Everything installed stays reachable on Categories and Search, so unpinning hides a card
    /// without losing anything.</summary>
    private void RebuildPinnedCards()
    {
        var implied = ImpliedPinnedIds();
        var pinned = _allCards.Where(card => FavoriteDevotions.Contains(DevotionIdOf(card), implied)).ToList();
        var language = LanguageCatalog.Resolve(AppSettings.BasicPrayersLanguageCode);
        foreach (var prayer in BasicPrayersOrder.Apply(BasicPrayerCatalog.All)
                     .Where(prayer => AppSettings.FavoriteBasicPrayerIds.Contains(prayer.Id)))
        {
            var name = PrayerCardName.ForBasicPrayer(prayer, language.Code);
            pinned.Add(new DevotionCardModel
            {
                Id = prayer.HomeCardId,
                Title = name.Title,
                InterfaceSubtitle = name.InterfaceSubtitle,
                IconGlyph = "\uE8F1",
                Command = new RelayCommand(() => Router.Navigate<BasicPrayerFlowPage>(prayer.Id)),
            });
        }

        DevotionCards.Clear();
        foreach (var card in HomeOrder.Apply(pinned, c => c.Id))
        {
            DevotionCards.Add(card);
        }

        UnpinnedCards.Clear();
        foreach (var card in _allCards.Where(card => !pinned.Contains(card)))
        {
            UnpinnedCards.Add(card);
        }

        OnPropertyChanged(nameof(HasUnpinnedCards));
    }

    [RelayCommand]
    private void PinCard(DevotionCardModel card)
    {
        FavoriteDevotions.Pin(DevotionIdOf(card), ImpliedPinnedIds());
        RebuildPinnedCards();
    }

    [RelayCommand]
    private void UnpinCard(DevotionCardModel card)
    {
        if (card.Id.StartsWith("basic:", StringComparison.Ordinal))
        {
            var prayerId = card.Id["basic:".Length..];
            if (AppSettings.FavoriteBasicPrayerIds.Contains(prayerId)) AppSettings.ToggleFavoriteBasicPrayer(prayerId);
        }
        else FavoriteDevotions.Toggle(DevotionIdOf(card), ImpliedPinnedIds());
        RebuildPinnedCards();
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
        var isDark = Application.Current?.RequestedTheme == ApplicationTheme.Dark;
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
        RefreshToday();
        var todayGroup = _calendar.GetMysteryGroupForToday();
        var all = await _presets.GetAllAsync();

        _defaultRosary = all.FirstOrDefault(p => p.Kind == PrayerKind.Rosary && p.IsDefault)
            ?? all.FirstOrDefault(p => p.Kind == PrayerKind.Rosary);
        _defaultJesusPrayer = all.FirstOrDefault(p => p.Kind == PrayerKind.JesusPrayer && p.IsDefault)
            ?? all.FirstOrDefault(p => p.Kind == PrayerKind.JesusPrayer);

        ApplyName(Card("rosary"), PrayerCardName.ForKind(PrayerKind.Rosary, _defaultRosary?.LanguageCode));
        ApplyName(Card("jesusPrayer"), PrayerCardName.ForKind(PrayerKind.JesusPrayer, _defaultJesusPrayer?.LanguageCode));

        var rosaryParts = new List<string> { string.Format(Loc.Tr("home_today", "Today: {0}"), todayGroup.UiName()) };
        if (_defaultRosary is { } rosary)
        {
            rosaryParts.Add(HebrewDisplayText.WithoutMarks(rosary.Name));
        }

        Card("rosary").AccentColor = todayGroup.AccentColor();
        Card("rosary").Subtitle = string.Join(" • ", rosaryParts);

        Card("jesusPrayer").AccentColor = PrayerKind.JesusPrayer.AccentColor();
        Card("jesusPrayer").Subtitle = _defaultJesusPrayer is { } jp
            ? $"{HebrewDisplayText.WithoutMarks(jp.Name)} • {jp.JesusPrayer.TargetDisplayName}"
            : Loc.Tr("home_click_to_set_up", "Click to set up");

        foreach (var bundleId in _customCardsByBundleId.Keys)
        {
            var match = all.FirstOrDefault(p => p.Kind == PrayerKind.Custom && p.CustomDevotionId == bundleId && p.IsDefault)
                ?? all.FirstOrDefault(p => p.Kind == PrayerKind.Custom && p.CustomDevotionId == bundleId);
            _defaultCustomDevotions[bundleId] = match;
            ApplyName(_customCardsByBundleId[bundleId], PrayerCardName.ForBundle(bundleId, match?.LanguageCode));
            _customCardsByBundleId[bundleId].Subtitle = MultiDayStatus.Subtitle(bundleId)
                ?? (match is { } favorite ? HebrewDisplayText.WithoutMarks(favorite.Name) : null)
                ?? Loc.Tr("home_click_to_pray", "Click to pray");
        }

        RebuildPinnedCards();
    }

    private void RefreshToday()
    {
        var today = SelectedDate;
        TodayFeast = AppSettings.ShowTodayFeast ? TodayInfoStore.Feast(today) : null;
        MonthIntention = AppSettings.ShowTodayIntention ? TodayInfoStore.Intention(today) : null;
        TodayDay = TodayInfoStore.LiturgicalDay(today);
        TodayReadings = TodayInfoStore.Readings(today);
        TodayTorahPortion = AppSettings.ShowTodayTorahPortion ? TodayInfoStore.WeeklyTorahPortion(today) : null;
    }

    private DevotionCardModel Card(string id) => _allCards.First(c => c.Id == id);

    private static void ApplyName(DevotionCardModel card, PrayerCardName name)
    {
        card.Title = name.Title;
        card.InterfaceSubtitle = name.InterfaceSubtitle;
    }

    private void OpenCustomDevotion(string bundleId)
    {
        var prayer = _defaultCustomDevotions.GetValueOrDefault(bundleId);
        Router.Navigate<CustomDevotionFlowPage>(new CustomDevotionFlowParams(prayer?.Id, bundleId));
    }

    [RelayCommand]
    private void OpenRosary()
    {
        // The Rosary card opens its presets: one card on Pray, however many saved Rosaries
        // behind it, with the default the first thing that screen offers.
        Router.Navigate<RosaryPresetPickerPage>();
    }

    /// <summary>A card's "Reminders…" — the saved configuration behind the card is what they
    /// belong to, so a devotion pinned but never configured has none to edit.</summary>
    [RelayCommand]
    private void OpenReminders(DevotionCardModel card)
    {
        var prayer = DevotionIdOf(card) switch
        {
            "rosary" => _defaultRosary,
            "jesusPrayer" => _defaultJesusPrayer,
            var bundleId => _defaultCustomDevotions.GetValueOrDefault(bundleId),
        };

        if (prayer is not null)
        {
            Router.Navigate<RemindersOnlyEditorPage>(prayer.Id);
        }
    }

    /// <summary>"Pray any Rosary" — the ad-hoc session the Mac's + menu opens first.</summary>
    [RelayCommand]
    private void PrayAnyRosary() => Router.Navigate<RosaryPresetPickerPage>();

    [RelayCommand]
    private void AddRosaryPreset() =>
        Router.Navigate<FavoriteEditorPage>(new FavoriteEditorParams(null, PrayerKind.Rosary));

    [RelayCommand]
    private void AddJesusPrayerPreset() =>
        Router.Navigate<FavoriteEditorPage>(new FavoriteEditorParams(null, PrayerKind.JesusPrayer));

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
    private void OpenSettings() => Router.Navigate<SettingsPage>();

    [RelayCommand]
    private void OpenAbout() => Router.Navigate<AboutPage>();
}
