using Microsoft.UI.Xaml.Controls;
using Prosary.ViewModels;

namespace Prosary.Views;

public sealed partial class LiturgicalCalendarControl : UserControl
{
    private DateOnly? _focusDate;
    private bool _updatingPicker;
    public LiturgicalCalendarViewModel ViewModel { get; } = new();
    public Action<DateOnly>? SelectDate { get; set; }
    public LiturgicalCalendarControl()
    {
        InitializeComponent();
        MonthPicker.MinDate = new DateTimeOffset(new DateTime(1900, 1, 1));
        MonthPicker.MaxDate = new DateTimeOffset(new DateTime(2100, 12, 31));
        Loaded += (_, _) => FocusOnDate(_focusDate ?? DateOnly.FromDateTime(DateTime.Today));
    }
    private void OnLayoutSizeChanged(object sender, Microsoft.UI.Xaml.SizeChangedEventArgs args)
    {
        // Reserve feast rows while the month picker and options can scroll in short windows.
        var availableHeight = args.NewSize.Height - CalendarLayout.Padding.Top
            - CalendarLayout.Padding.Bottom - CalendarLayout.RowSpacing;
        CalendarOptionsScroll.MaxHeight = Math.Max(0, availableHeight * 0.65);
    }
    public void FocusOnDate(DateOnly date)
    {
        _focusDate = date;
        ViewModel.FocusOnDate(date);
        if (IsLoaded)
        {
            _updatingPicker = true;
            MonthPicker.SelectedDates.Clear();
            MonthPicker.SelectedDates.Add(new DateTimeOffset(date.ToDateTime(new TimeOnly(12, 0))));
            MonthPicker.SetDisplayDate(new DateTimeOffset(date.ToDateTime(new TimeOnly(12, 0))));
            _updatingPicker = false;
            ScrollToDate(date);
        }
    }
    private void OnToday(object sender, Microsoft.UI.Xaml.RoutedEventArgs e) => FocusOnDate(DateOnly.FromDateTime(DateTime.Today));
    private void OnSelectedDatesChanged(CalendarView sender, CalendarViewSelectedDatesChangedEventArgs args)
    {
        if (_updatingPicker || args.AddedDates.Count == 0) return;
        var date = DateOnly.FromDateTime(args.AddedDates[0].DateTime);
        _focusDate = date;
        ViewModel.FocusOnDate(date);
        SelectDate?.Invoke(date);
    }
    private void ScrollToDate(DateOnly date)
    {
        var row = ViewModel.Rows.FirstOrDefault(row => row.Date >= date) ?? ViewModel.Rows.LastOrDefault();
        if (row is not null) DispatcherQueue.TryEnqueue(() => FeastList.ScrollIntoView(row, ScrollIntoViewAlignment.Leading));
    }
    private void OnItemClick(object sender, ItemClickEventArgs e)
    {
        if (e.ClickedItem is LiturgicalCalendarRow row) SelectDate?.Invoke(row.Date);
    }
}
