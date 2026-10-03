using System.Collections.ObjectModel;
using System.Globalization;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Prosary.Localization;
using Prosary.Services;

namespace Prosary.ViewModels;

public sealed record LiturgicalCalendarRow(DateOnly Date, string DateLabel, string Title, string Rank);

public partial class LiturgicalCalendarViewModel : ObservableObject
{
    private DateOnly _month = new(DateTime.Today.Year, DateTime.Today.Month, 1);
    private static readonly DateOnly MinimumMonth = new(1900, 1, 1);
    private static readonly DateOnly MaximumMonth = new(2100, 12, 1);
    public bool CanMoveBackward => _month > MinimumMonth;
    public bool CanMoveForward => _month < MaximumMonth;
    public string Title => Loc.Tr("calendar_title", "Liturgical Calendar");
    public string PreviousLabel => Loc.Tr("calendar_previous_month", "Previous Month");
    public string NextLabel => Loc.Tr("calendar_next_month", "Next Month");
    public string TodayLabel => Loc.Tr("HomeResetToday.Content", "Today");
    public string EmptyLabel => Loc.Tr("calendar_no_observances", "No published observances are available for this month.");
    private CultureInfo Culture
    {
        get
        {
            var culture = (CultureInfo)CultureInfo.GetCultureInfo(UiLanguageCatalog.ResourceTag(UiLanguageCatalog.Current)).Clone();
            culture.DateTimeFormat.Calendar = new GregorianCalendar();
            return culture;
        }
    }
    [ObservableProperty] private string _monthLabel = "";
    [ObservableProperty] private string _calendarName = "";
    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(IsEmpty))]
    private ObservableCollection<LiturgicalCalendarRow> _rows = [];
    public bool IsEmpty => Rows.Count == 0;

    public LiturgicalCalendarViewModel() => Refresh();
    [RelayCommand(CanExecute = nameof(CanMoveBackward))] private void PreviousMonth() { _month = _month.AddMonths(-1); Refresh(); }
    [RelayCommand(CanExecute = nameof(CanMoveForward))] private void NextMonth() { _month = _month.AddMonths(1); Refresh(); }
    [RelayCommand] private void Today() { _month = new(DateTime.Today.Year, DateTime.Today.Month, 1); Refresh(); }
    public void Refresh()
    {
        _month = _month < MinimumMonth ? MinimumMonth : _month > MaximumMonth ? MaximumMonth : _month;
        PreviousMonthCommand.NotifyCanExecuteChanged();
        NextMonthCommand.NotifyCanExecuteChanged();
        MonthLabel = _month.ToString("MMMM yyyy", Culture);
        CalendarName = TodayInfoStore.Calendars.FirstOrDefault(c => c.Id == TodayInfoStore.ResolvedCalendarId)?.DisplayName ?? "";
        Rows = new(Enumerable.Range(1, DateTime.DaysInMonth(_month.Year, _month.Month))
            .Select(day => _month.AddDays(day - 1)).Select(date => (date, feast: TodayInfoStore.Feast(date)))
            .Where(row => row.feast is not null).Select(row => new LiturgicalCalendarRow(row.date,
                row.date.ToString("ddd d", Culture), row.feast!.LocalizedTitle(UiLanguageCatalog.Current),
                row.feast.LocalizedRank(UiLanguageCatalog.Current))));
    }
}
