using System.Collections.ObjectModel;
using System.Globalization;
using CommunityToolkit.Mvvm.ComponentModel;
using Prosary.Localization;
using Prosary.Services;
using Prosary.Models;

namespace Prosary.ViewModels;

public sealed record LiturgicalCalendarRow(DateOnly Date, string DateLabel, string Title, string Rank,
    IReadOnlyList<SaintDescription>? Descriptions = null)
{
    public IReadOnlyList<SaintDescription> SourceDescriptions => Descriptions ?? [];
    public string Summary => EventSummary.FirstParagraph(SourceDescriptions.FirstOrDefault()?.Text);
    public bool HasSummary => Summary.Length > 0;
}

public static class EventSummary
{
    public static string FirstParagraph(string? source, int limit = 280)
    {
        var first = (source ?? "").Split(["\r\n", "\n", "\r"], StringSplitOptions.RemoveEmptyEntries)
            .FirstOrDefault()?.Trim() ?? "";
        if (first.Length <= limit) return first;
        var boundary = first.LastIndexOf(' ', limit);
        if (boundary <= 0) boundary = limit;
        if (boundary > 0 && char.IsHighSurrogate(first[boundary - 1])) boundary--;
        return first[..boundary].TrimEnd() + "…";
    }
}

public partial class LiturgicalCalendarViewModel : ObservableObject
{
    public string Title => Loc.Tr("calendar_events_title", "Event Calendar");
    public string TodayLabel => Loc.Tr("HomeResetToday.Content", "Today");
    public string ViewLabel => Loc.Tr("calendar_view", "Calendar View");
    public string ListLabel => Loc.Tr("calendar_list_view", "List");
    public string MonthLabel => Loc.Tr("calendar_month_view", "Month");
    public string EmptyLabel => IsMonthView
        ? Loc.Tr("calendar_no_observances", "No published observances are available for this month.")
        : Loc.Tr("calendar_no_events", "No published events are available for this calendar.");
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
            : TodayInfoStore.PublishedEvents();
        Rows = new(entries.SelectMany(entry => RowsForDate(entry.Date, entry.Feast, culture, UiLanguageCatalog.Current)));
    }

    internal static IEnumerable<LiturgicalCalendarRow> RowsForDate(DateOnly date, FeastDay feast, CultureInfo culture, string language)
    {
        if (culture.DateTimeFormat.Calendar is not GregorianCalendar)
        {
            culture = (CultureInfo)culture.Clone();
            culture.DateTimeFormat.Calendar = new GregorianCalendar();
        }
        var dateLabel = date.ToString("D", culture);
        var rank = feast.LocalizedRank(language);
        if (feast.Observances is not { Count: > 0 } observances)
            return [new(date, dateLabel, feast.LocalizedTitle(language), rank)];
        return observances.Select(observance => new LiturgicalCalendarRow(date, dateLabel,
            HebrewDisplayText.WithoutMarks(UiLanguageCatalog.Localized(observance.TitleByLanguage, language) ?? observance.Title),
            rank, (observance.LocalizedDescription(language) ?? observance.Reflection(language)) is { } description ? [description] : []));
    }
}
