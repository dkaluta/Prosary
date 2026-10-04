using Microsoft.UI.Xaml.Controls;
using Prosary.ViewModels;

namespace Prosary.Views;

public sealed partial class LiturgicalCalendarControl : UserControl
{
    private DateOnly? _focusDate;
    public LiturgicalCalendarViewModel ViewModel { get; } = new();
    public Action<DateOnly>? SelectDate { get; set; }
    public LiturgicalCalendarControl()
    {
        InitializeComponent();
        Loaded += (_, _) => { ViewModel.Refresh(); ScrollToDate(_focusDate ?? DateOnly.FromDateTime(DateTime.Today)); };
    }
    public void FocusOnDate(DateOnly date)
    {
        _focusDate = date;
        if (IsLoaded) ScrollToDate(date);
    }
    private void OnToday(object sender, Microsoft.UI.Xaml.RoutedEventArgs e) => ScrollToDate(DateOnly.FromDateTime(DateTime.Today));
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
