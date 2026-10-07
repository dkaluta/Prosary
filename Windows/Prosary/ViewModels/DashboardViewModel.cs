using System.Collections.ObjectModel;
using System.Globalization;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Microsoft.UI.Xaml.Media.Imaging;
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
    public bool IsReflection => Id == "reflection";
    public string ChoosePhotoLabel => Loc.Tr("home_widgets_choose_photo", "Choose Photo");
    public string RemovePhotoLabel => Loc.Tr("home_widgets_remove_photo", "Remove Photo");
    public string PhotoDescription => Loc.Tr("home_widgets_photo_description", "Your selected photo");
    public string DetailsLabel => Loc.Tr("home_widgets_feast_details", "About Today’s Feast");
    public string NoDescriptionLabel => Loc.Tr("home_widgets_no_feast_description", "No explanation is available in this language.");
    public string MoveUpLabel => Loc.Tr("home_widgets_move_up", "Move Up");
    public string MoveDownLabel => Loc.Tr("home_widgets_move_down", "Move Down");
    public string RemoveLabel => Loc.Tr("home_widgets_remove", "Remove Widget");
    [ObservableProperty, NotifyPropertyChangedFor(nameof(HasBody))] private string _body = "";
    public bool HasBody => Body.Length > 0;
    [ObservableProperty, NotifyPropertyChangedFor(nameof(HasPhoto))] private BitmapImage? _photoSource;
    public bool HasPhoto => PhotoSource is not null;
    [ObservableProperty, NotifyPropertyChangedFor(nameof(HasDescriptions)), NotifyPropertyChangedFor(nameof(HasNoDescriptions))]
    private IReadOnlyList<SaintDescription> _descriptions = [];
    public bool HasDescriptions => Descriptions.Count > 0;
    public bool HasNoDescriptions => IsFeast && Descriptions.Count == 0;
    [ObservableProperty] private IReadOnlyList<HomeReminderRow> _reminders = [];
}

public sealed record HomeReminderRow(Guid? PrayerId, string Title, string Time);

/// <summary>Home arranges reference cards while the native Library retains saved prayers and
/// each prayer retains its independent window. Reflections use exact-language supplied prose.</summary>
public partial class DashboardViewModel(IPresetStore presets) : ObservableObject
{
    public WindowNavigation Navigation { get; set; } = WindowNavigation.Detached;
    public HomeViewModel? Today { get; set; }
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
    public string DetailsLabel => Label("feast_details", "About Today’s Feast");
    public string NoDescriptionLabel => Label("no_feast_description", "No explanation is available in this language.");

    private static HomeWidgetCard Create(string id) => new()
    {
        Id = id,
        Title = id switch
        {
            "readings" => Label("readings", "Today’s Readings"),
            "popeIntention" => Label("pope_intention", "Pope’s Intention"),
            "calendar" => Label("calendar", "Calendar"),
            "photo" => Label("photo", "Photo"),
            "reminders" => Label("reminders", "Reminders"),
            "scripture" => Label("scripture", "Holy Scripture"),
            "reflection" => Label("reflection", "Reflection"),
            _ => Label("feast", "Today’s Feast"),
        },
        Glyph = id switch { "readings" or "scripture" => "\uE8A9", "calendar" => "\uE787",
            "photo" => "\uEB9F", "reminders" => "\uEA8F", "reflection" => "\uE8F2",
            "popeIntention" => "\uE8D7", _ => "\uE734" },
        ActionTitle = id switch
        {
            "readings" => Loc.Tr("bible_daily_readings", "Daily Readings"),
            "calendar" => Loc.Tr("calendar_feasts_solemnities", "Feasts and Solemnities"),
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
        foreach (var card in Cards.Concat(AvailableCards))
        {
            switch (card.Id)
            {
                case "readings":
                    var citations = TodayInfoStore.Readings(date);
                    card.Body = citations.Count == 0 ? Label("no_readings", "No readings are available for this date.")
                        : string.Join(Environment.NewLine, citations.Select(citation => citation.LocalizedFull(language)));
                    break;
                case "popeIntention":
                    var intention = TodayInfoStore.Intention(date);
                    card.Body = intention is null ? Label("no_intention", "No intention is available for this month.")
                        : intention.LocalizedTitle(language) + Environment.NewLine + intention.LocalizedText(language);
                    break;
                case "calendar":
                    var upcoming = TodayInfoStore.FeastsAndSolemnities()
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
                case "feast":
                    card.Body = feast is null ? Label("no_feast", "No feast information is available for this date.")
                        : feast.LocalizedTitle(language) + Environment.NewLine + feast.LocalizedRank(language);
                    card.Descriptions = feast?.LocalizedDescriptions(language) ?? [];
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
        if (AppSettings.SaintReminderEnabled) rows.Add(new(null, Label("feast", "Today’s Feast"),
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
