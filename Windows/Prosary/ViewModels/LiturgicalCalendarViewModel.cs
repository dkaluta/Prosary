using System.Collections.ObjectModel;
using System.Globalization;
using CommunityToolkit.Mvvm.ComponentModel;
using Prosary.Localization;
using Prosary.Services;

namespace Prosary.ViewModels;

public sealed record LiturgicalCalendarRow(DateOnly Date, string DateLabel, string Title, string Rank);

public partial class LiturgicalCalendarViewModel : ObservableObject
{
    public string Title => Loc.Tr("calendar_feasts_solemnities", "Feasts and Solemnities");
    public string TodayLabel => Loc.Tr("HomeResetToday.Content", "Today");
    public string EmptyLabel => Loc.Tr("calendar_no_feasts", "No published feasts or solemnities are available for this calendar.");
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
    [NotifyPropertyChangedFor(nameof(IsEmpty))]
    private ObservableCollection<LiturgicalCalendarRow> _rows = [];
    public bool IsEmpty => Rows.Count == 0;

    public LiturgicalCalendarViewModel() => Refresh();
    public void Refresh()
    {
        var culture = Culture;
        CalendarName = TodayInfoStore.Calendars.FirstOrDefault(c => c.Id == TodayInfoStore.ResolvedCalendarId)?.DisplayName ?? "";
        Rows = new(TodayInfoStore.FeastsAndSolemnities().Select(entry => new LiturgicalCalendarRow(entry.Date,
            entry.Date.ToString("D", culture), entry.Feast.LocalizedTitle(UiLanguageCatalog.Current),
            entry.Feast.LocalizedRank(UiLanguageCatalog.Current))));
    }
}
