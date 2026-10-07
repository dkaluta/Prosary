using System.Collections.ObjectModel;
using System.Globalization;
using CommunityToolkit.Mvvm.ComponentModel;
using Prosary.Localization;
using Prosary.Services;
using Prosary.Models;

namespace Prosary.ViewModels;

public sealed record LiturgicalCalendarRow(DateOnly Date, string DateLabel, string Title, string Rank);

public partial class LiturgicalCalendarViewModel : ObservableObject
{
    public string Title => Loc.Tr("calendar_feasts_solemnities", "Feasts and Solemnities");
    public string TodayLabel => Loc.Tr("HomeResetToday.Content", "Today");
    public string ViewLabel => Loc.Tr("calendar_view", "Calendar View");
    public string ListLabel => Loc.Tr("calendar_list_view", "List");
    public string MonthLabel => Loc.Tr("calendar_month_view", "Month");
    public string EmptyLabel => IsMonthView
        ? Loc.Tr("calendar_no_observances", "No published observances are available for this month.")
        : Loc.Tr("calendar_no_feasts", "No published feasts or solemnities are available for this calendar.");
    private CultureInfo Culture
    {
        get
        {
            var culture = (CultureInfo)CultureInfo.GetCultureInfo(UiLanguageCatalog.ResourceTag(UiLanguageCatalog.Current)).Clone();
            culture.DateTimeFormat.Calendar = new GregorianCalendar();
            return culture;
        }
    }
    [ObservableProperty] private string _calendarName = "";
    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(EmptyLabel))]
    private bool _isMonthView = AppSettings.CalendarViewMode == "month";
    private DateOnly _selectedDate = DateOnly.FromDateTime(DateTime.Today);
    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(IsEmpty))]
    private ObservableCollection<LiturgicalCalendarRow> _rows = [];
    public bool IsEmpty => Rows.Count == 0;

    public LiturgicalCalendarViewModel() => Refresh();
    partial void OnIsMonthViewChanged(bool value)
    {
        AppSettings.CalendarViewMode = value ? "month" : "list";
        Refresh();
    }
    public void FocusOnDate(DateOnly date)
    {
        _selectedDate = date;
        Refresh();
    }
    public void Refresh()
    {
        var culture = Culture;
        CalendarName = TodayInfoStore.Calendars.FirstOrDefault(c => c.Id == TodayInfoStore.ResolvedCalendarId)?.DisplayName ?? "";
        var entries = IsMonthView
            ? Enumerable.Range(1, DateTime.DaysInMonth(_selectedDate.Year, _selectedDate.Month))
                .Select(day => new DateOnly(_selectedDate.Year, _selectedDate.Month, day))
                .Select(date => (Date: date, Feast: TodayInfoStore.Feast(date)))
                .Where(entry => entry.Feast is not null).Select(entry => (entry.Date, Feast: entry.Feast!))
            : TodayInfoStore.FeastsAndSolemnities();
        Rows = new(entries.Select(entry => new LiturgicalCalendarRow(entry.Date,
            entry.Date.ToString("D", culture), entry.Feast.LocalizedTitle(UiLanguageCatalog.Current),
            entry.Feast.LocalizedRank(UiLanguageCatalog.Current))));
    }
}
