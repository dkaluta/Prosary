using System.Collections.ObjectModel;
using System.Globalization;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Microsoft.UI.Xaml.Media.Imaging;
using Microsoft.UI.Xaml.Media;
using Prosary.Localization;
using Prosary.Models;
using Prosary.Navigation;
using Prosary.Persistence;
using Prosary.Services;
using Prosary.Views;

namespace Prosary.ViewModels;

public partial class HomeWidgetCard : ObservableObject
{
    public required string Id { get; init; }
    public required string Title { get; init; }
    public required string Glyph { get; init; }
    public string ActionTitle { get; init; } = "";
    public bool HasAction => ActionTitle.Length > 0;
    public bool IsPhoto => Id == "photo";
    public bool IsPopeIntention => Id == "popeIntention";
    public bool IsFeast => Id == "feast";
    public bool CanChooseGraphic => !IsFeast;
    public bool IsReflection => Id == "reflection";
    public bool IsScripture => Id == "scripture";
    public bool HasScripturePassages => IsScripture || Id == "torah";
    public string ColorLabel => Loc.Tr("home_widgets_set_accent_color", "Set Accent Color…");
    public string RemoveAccentColorLabel => Loc.Tr("home_widgets_remove_accent_color", "Remove Accent Color");
    [ObservableProperty] private Brush? _cardBackground;
    public string AddGraphicLabel => HasGraphicChoice ? Loc.Tr("home_widgets_change_graphic", "Change Image") : Loc.Tr("home_widgets_add_graphic", "Add Image");
    public string RemoveGraphicLabel => Loc.Tr("home_widgets_remove_graphic", "Remove Image");
    public string GraphicDescription => Loc.Tr("home_widgets_graphic_description", "Your selected image");
    public string SizeActionLabel => IsExpanded ? Loc.Tr("home_widgets_collapse", "Collapse") : Loc.Tr("home_widgets_expand", "Expand");
    public string SizeGlyph => IsExpanded ? "\uE70E" : "\uE70D";
    [ObservableProperty, NotifyPropertyChangedFor(nameof(SizeActionLabel)), NotifyPropertyChangedFor(nameof(SizeGlyph))]
    private bool _isExpanded = true;
    public string ChoosePhotoLabel => Loc.Tr("home_widgets_choose_photo", "Choose Photo");
    public string RemovePhotoLabel => Loc.Tr("home_widgets_remove_photo", "Remove Photo");
    public string PhotoDescription => Loc.Tr("home_widgets_photo_description", "Your selected photo");
    public string DetailsLabel => Loc.Tr("home_widgets_feast_details", "About the Feast and Day");
    public string NoDescriptionLabel => Loc.Tr("home_widgets_no_feast_description", "No explanation is available in this language.");
    public string MoveUpLabel => Loc.Tr("home_widgets_move_up", "Move Up");
    public string MoveDownLabel => Loc.Tr("home_widgets_move_down", "Move Down");
    public string RemoveLabel => Loc.Tr("home_widgets_remove", "Remove Widget");
    [ObservableProperty, NotifyPropertyChangedFor(nameof(HasBody)), NotifyPropertyChangedFor(nameof(Summary))] private string _body = "";
    [ObservableProperty, NotifyPropertyChangedFor(nameof(Summary))] private string? _summaryOverride;
    public bool HasBody => Body.Length > 0;
    public string Summary => SummaryOverride ?? EventSummary.FirstParagraph(IsReflection && Descriptions.Count > 0 ? Descriptions[0].Text
        : Id == "reminders" && Reminders.Count > 0 ? Reminders[0].Title + " · " + Reminders[0].Time
        : IsPhoto && !HasBody ? (HasPhoto ? PhotoDescription : ChoosePhotoLabel) : Body, 150);
    [ObservableProperty, NotifyPropertyChangedFor(nameof(HasPhoto)), NotifyPropertyChangedFor(nameof(AddGraphicLabel)), NotifyPropertyChangedFor(nameof(Summary))] private BitmapImage? _photoSource;
    public bool HasPhoto => PhotoSource is not null;
    [ObservableProperty, NotifyPropertyChangedFor(nameof(AddGraphicLabel))] private bool _hasGraphicChoice;
    [ObservableProperty, NotifyPropertyChangedFor(nameof(HasGraphicError))] private string _graphicError = "";
    public bool HasGraphicError => GraphicError.Length > 0;
    [ObservableProperty, NotifyPropertyChangedFor(nameof(HasDescriptions)), NotifyPropertyChangedFor(nameof(HasNoDescriptions)), NotifyPropertyChangedFor(nameof(Summary))]
    private IReadOnlyList<SaintDescription> _descriptions = [];
    public bool HasDescriptions => Descriptions.Count > 0;
    public bool HasNoDescriptions => IsFeast && Descriptions.Count == 0;
    [ObservableProperty, NotifyPropertyChangedFor(nameof(Summary))] private IReadOnlyList<HomeReminderRow> _reminders = [];
    [ObservableProperty] private IReadOnlyList<ReadingPassageViewModel> _scripturePassages = [];
}

public sealed record HomeReminderRow(Guid? PrayerId, string Title, string Time);

/// <summary>Home arranges reference cards while the native Library retains saved prayers and
/// each prayer retains its independent window. Reflections use exact-language supplied prose.</summary>
public partial class DashboardViewModel(IPresetStore presets) : ObservableObject
{
    public WindowNavigation Navigation { get; set; } = WindowNavigation.Detached;
    public HomeViewModel? Today { get; set; }
    public DesktopReadingsViewModel Scripture { get; } = new();
    public ObservableCollection<HomeWidgetCard> Cards { get; } = [];
    public ObservableCollection<HomeWidgetCard> AvailableCards { get; } = [];
    public bool IsEmpty => Cards.Count == 0;
    public bool HasAvailableCards => AvailableCards.Count > 0;

    private static string Label(string suffix, string fallback) => Loc.Tr("home_widgets_" + suffix, fallback);
    public string Title => Label("title", "Home");
    public string CustomizeLabel => Label("customize", "Customize Home");
    public string AddLabel => Label("add", "Add Widget");
    public string RemoveLabel => Label("remove", "Remove Widget");
    public string MoveUpLabel => Label("move_up", "Move Up");
    public string MoveDownLabel => Label("move_down", "Move Down");
    public string AvailableLabel => Label("available", "Available Widgets");
    public string SelectedLabel => Label("selected", "Your Widgets");
    public string EmptyLabel => Label("empty", "Add widgets to make this Home your own.");
    public string ChoosePhotoLabel => Label("choose_photo", "Choose Photo");
    public string RemovePhotoLabel => Label("remove_photo", "Remove Photo");
    public string PhotoDescription => Label("photo_description", "Your selected photo");
    public string DetailsLabel => Label("feast_details", "About the Feast and Day");
    public string NoDescriptionLabel => Label("no_feast_description", "No explanation is available in this language.");

    private static HomeWidgetCard Create(string id) => new()
    {
        Id = id,
        Title = id switch
        {
            "readings" => Label("readings", "Today’s Readings"),
            "torah" => Label("torah", "Weekly Torah portion and haftarah"),
            "popeIntention" => Label("pope_intention", "Pope’s Intention"),
            "calendar" => Label("calendar", "Calendar"),
            "photo" => Label("photo", "Photo"),
            "reminders" => Label("reminders", "Reminders"),
            "scripture" => Label("scripture", "Holy Scripture"),
            "reflection" => Label("reflection", "Reflection"),
            _ => Label("feast", "About the Feast and Day"),
        },
        Glyph = id switch { "readings" or "scripture" or "torah" => "\uE8A9", "calendar" => "\uE787",
            "photo" => "\uEB9F", "reminders" => "\uEA8F", "reflection" => "\uE8F2",
            "popeIntention" => "\uE8D7", _ => "\uE734" },
        ActionTitle = id switch
        {
            "readings" => Loc.Tr("bible_daily_readings", "Daily Readings"),
            "calendar" => Loc.Tr("calendar_events_title", "Event Calendar"),
            "scripture" => Loc.Tr("bible_title", "Bible"),
            "reminders" => Label("manage_reminders", "Manage Reminders"),
            _ => "",
        },
    };

    public void ReloadLayout()
    {
        var existing = Cards.Concat(AvailableCards).ToDictionary(card => card.Id);
        Cards.Clear();
        foreach (var id in AppSettings.HomeWidgetOrder)
            Cards.Add(existing.GetValueOrDefault(id) ?? Create(id));
        AvailableCards.Clear();
        foreach (var id in HomeWidgets.All.Where(id => !AppSettings.HomeWidgetOrder.Contains(id)))
            AvailableCards.Add(existing.GetValueOrDefault(id) ?? Create(id));
        foreach (var card in Cards.Concat(AvailableCards)) card.IsExpanded = !AppSettings.HomeWidgetCollapsedIds.Contains(card.Id);
        OnPropertyChanged(nameof(IsEmpty));
        OnPropertyChanged(nameof(HasAvailableCards));
        RefreshToday();
    }

    public void SaveOrder() => AppSettings.SetHomeWidgetOrder(Cards.Select(card => card.Id));

    [RelayCommand] private void Add(HomeWidgetCard card) =>
        AppSettings.SetHomeWidgetOrder(HomeWidgets.Add(AppSettings.HomeWidgetOrder, card.Id));
    [RelayCommand] private void Remove(HomeWidgetCard card) =>
        AppSettings.SetHomeWidgetOrder(AppSettings.HomeWidgetOrder.Where(id => id != card.Id));
    [RelayCommand] private void MoveUp(HomeWidgetCard card) => Move(card, -1);
    [RelayCommand] private void MoveDown(HomeWidgetCard card) => Move(card, 1);
    [RelayCommand] private void ToggleSize(HomeWidgetCard card)
    {
        var collapsed = AppSettings.HomeWidgetCollapsedIds.ToList();
        if (!collapsed.Remove(card.Id)) collapsed.Add(card.Id);
        AppSettings.SetHomeWidgetCollapsedIds(collapsed);
        card.IsExpanded = !collapsed.Contains(card.Id);
    }
    private void Move(HomeWidgetCard card, int offset)
    {
        var current = Cards.IndexOf(card);
        var target = current + offset;
        if (current < 0 || target < 0 || target >= Cards.Count) return;
        Cards.Move(current, target);
        SaveOrder();
    }

    public void RefreshToday()
    {
        TodayInfoStore.SelectedCalendarId = AppSettings.FeastCalendarId;
        var date = Today?.SelectedDate ?? DateOnly.FromDateTime(DateTime.Today);
        var language = UiLanguageCatalog.Current;
        var feast = TodayInfoStore.Feast(date);
        var culture = (CultureInfo)CultureInfo.GetCultureInfo(UiLanguageCatalog.ResourceTag(language)).Clone();
        culture.DateTimeFormat.Calendar = new GregorianCalendar();
        if (Today is not null) Scripture.Refresh(Today, showsAllDailyReadings: true);
        foreach (var card in Cards.Concat(AvailableCards))
        {
            var graphicPath = !card.CanChooseGraphic ? null : card.IsPhoto ? AppSettings.HomePhotoPath : AppSettings.HomeWidgetGraphicPaths.GetValueOrDefault(card.Id);
            card.HasGraphicChoice = !string.IsNullOrWhiteSpace(graphicPath);
            card.PhotoSource = !string.IsNullOrWhiteSpace(graphicPath) && File.Exists(graphicPath)
                ? new BitmapImage(new Uri("ms-appdata:///local/HomePhotos/" + Uri.EscapeDataString(Path.GetFileName(graphicPath)))) : null;
            card.GraphicError = !card.IsPhoto && card.HasGraphicChoice && card.PhotoSource is null
                ? Label("photo_error", "Could Not Load Photo") : "";
            switch (card.Id)
            {
                case "readings":
                    var sourceCitations = TodayInfoStore.Readings(date);
                    var citations = ReadingCitation.DisplayOrder(sourceCitations, AppSettings.ReverseReadingsOrder);
                    card.Body = citations.Count == 0 ? Label("no_readings", "No readings are available for this date.")
                        : string.Join(Environment.NewLine, citations.Select(citation => citation.LocalizedFull(language)));
                    card.SummaryOverride = citations.Count == 0 ? card.Body
                        : sourceCitations.FirstOrDefault(citation => citation.Type.Equals("gospel", StringComparison.OrdinalIgnoreCase))?.LocalizedShort(language)
                            ?? string.Join(" · ", citations.Select(citation => citation.LocalizedShort(language)));
                    break;
                case "popeIntention":
                    var intention = TodayInfoStore.Intention(date);
                    card.Body = intention is null ? Label("no_intention", "No intention is available for this month.")
                        : intention.LocalizedTitle(language) + Environment.NewLine + intention.LocalizedText(language);
                    break;
                case "torah":
                    var portion = TodayInfoStore.WeeklyTorahPortion(date);
                    card.Body = portion is null ? Label("no_torah", "No Torah portion or haftarah is available for this date.")
                        : portion.LocalizedTitle(language);
                    card.SummaryOverride = portion?.LocalizedTitle(language) ?? card.Body;
                    var store = ReadingsTextStore.Default;
                    var edition = store.ResolveEdition(AppSettings.ReadingsEditionId, language);
                    card.ScripturePassages = (portion?.AllReadings ?? []).Select((reading, index) =>
                    {
                        var contextKey = $"home|{date:yyyy-MM-dd}|torah|{index}|{reading.Full}|{language}";
                        var configurationKey = $"{contextKey}|{AppSettings.ReadingsEditionId}|{edition?.Id}";
                        var existing = card.ScripturePassages.FirstOrDefault(row => row.ContextKey == contextKey);
                        return existing?.ConfigurationKey == configurationKey ? existing
                            : new ReadingPassageViewModel(store, edition, "torah", reading, language, contextKey, configurationKey)
                                { IsExpanded = existing?.IsExpanded ?? AppSettings.ExpandReadingsByDefault };
                    }).ToList();
                    break;
                case "calendar":
                    var upcoming = TodayInfoStore.PublishedEvents()
                        .Where(entry => entry.Date.Year == date.Year && entry.Date.Month == date.Month && entry.Date >= date)
                        .Take(4).Select(entry => entry.Date.ToString("d MMM", culture) + ": " + entry.Feast.LocalizedTitle(language));
                    card.Body = string.Join(Environment.NewLine,
                        new[] { date.ToString("D", culture), TodayInfoStore.Calendars.FirstOrDefault(calendar => calendar.Id == TodayInfoStore.ResolvedCalendarId)?.DisplayName ?? "" }
                            .Concat(upcoming));
                    break;
                case "photo":
                    var path = AppSettings.HomePhotoPath;
                    card.PhotoSource = File.Exists(path) ? new BitmapImage(new Uri("ms-appdata:///local/HomePhotos/" + Uri.EscapeDataString(Path.GetFileName(path)))) : null;
                    card.Body = card.PhotoSource is null && path.Length > 0 ? Label("photo_error", "Could Not Load Photo") : "";
                    break;
                case "scripture":
                    var citation = ReadingCitation.ScriptureOfDay(TodayInfoStore.Readings(date));
                    card.Body = citation?.LocalizedFull(language) ?? Label("no_readings", "No readings are available for this date.");
                    card.ScripturePassages = Scripture.ScriptureOfDay;
                    break;
                case "feast":
                    card.Body = feast is null ? Label("no_feast", "No feast information is available for this date.")
                        : feast.LocalizedTitle(language) + Environment.NewLine + feast.LocalizedRank(language);
                    card.Descriptions = feast?.LocalizedDescriptions(language, feast.LocalizedTitle(language)) ?? [];
                    break;
                case "reflection":
                    card.Descriptions = feast?.Reflections(language) ?? [];
                    card.Body = card.Descriptions.Count == 0
                        ? Label("reflection_pending", "No reflection is available for this date in this language.") : "";
                    break;
            }
        }
    }

    public async Task RefreshRemindersAsync()
    {
        var rows = new List<HomeReminderRow>();
        foreach (var prayer in await presets.GetAllAsync())
            rows.AddRange(prayer.Reminders.Where(reminder => reminder.IsEnabled).Select(reminder =>
                new HomeReminderRow(prayer.Id, prayer.DisplayName, reminder.DisplayTime)));
        if (AppSettings.ReadingsReminderEnabled) rows.Add(new(null, Label("readings", "Today’s Readings"),
            new PrayerReminder(AppSettings.ReadingsReminderMinutes / 60, AppSettings.ReadingsReminderMinutes % 60).DisplayTime));
        if (AppSettings.SaintReminderEnabled) rows.Add(new(null, Label("feast", "About the Feast and Day"),
            new PrayerReminder(AppSettings.SaintReminderMinutes / 60, AppSettings.SaintReminderMinutes % 60).DisplayTime));
        foreach (var card in Cards.Concat(AvailableCards).Where(card => card.Id == "reminders"))
        {
            card.Reminders = rows;
            card.Body = rows.Count == 0 ? Label("no_reminders", "No reminders yet.") : "";
        }
    }

    [RelayCommand] private void Open(HomeWidgetCard card)
    {
        if (card.Id is "readings" or "calendar" or "scripture")
        {
            var mode = card.Id switch { "calendar" => "calendar", "scripture" => "bible", _ => "daily" };
            if (Navigation.OwnerWindow is MainWindow library) library.ShowReadingsMode(mode);
            else Navigation.Navigate<DesktopReadingsPage>(mode);
            return;
        }
        switch (card.Id)
        {
            case "reminders": Navigation.Navigate<DesktopLibraryPage>(); break;
        }
    }

    [RelayCommand] private void EditReminder(HomeReminderRow row)
    {
        if (row.PrayerId is { } id) Navigation.Navigate<RemindersOnlyEditorPage>(id);
        else Navigation.Navigate<SettingsPage>();
    }
}
