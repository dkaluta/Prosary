using Microsoft.UI.Xaml.Controls;
using Prosary.ViewModels;
using Microsoft.UI.Xaml;
using Prosary.Controls;
using Prosary.Localization;

namespace Prosary.Views;

public sealed partial class LiturgicalCalendarControl : UserControl
{
    private DateOnly? _focusDate;
    private bool _updatingPicker;
    private bool _dialogOpen;
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
        CalendarEventMarkers.Refresh();
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
    private void OnDayItemChanging(CalendarView sender, CalendarViewDayItemChangingEventArgs args) => CalendarEventMarkers.Apply(args);
    private void OnSelectedDatesChanged(CalendarView sender, CalendarViewSelectedDatesChangedEventArgs args)
    {
        if (_updatingPicker || args.AddedDates.Count == 0) return;
        var date = DateOnly.FromDateTime(args.AddedDates[0].DateTime);
        _focusDate = date;
        ViewModel.FocusOnDate(date);
        ScrollToDate(date);
    }
    private void ScrollToDate(DateOnly date)
    {
        var row = ViewModel.Rows.FirstOrDefault(row => row.Date >= date) ?? ViewModel.Rows.LastOrDefault();
        if (row is not null) DispatcherQueue.TryEnqueue(() => FeastList.ScrollIntoView(row, ScrollIntoViewAlignment.Leading));
    }
    private async void OnItemClick(object sender, ItemClickEventArgs e)
    {
        if (_dialogOpen || e.ClickedItem is not LiturgicalCalendarRow row || XamlRoot is null) return;
        _dialogOpen = true;
        try
        {
            var content = new StackPanel { Spacing = 12 };
            content.Children.Add(new TextBlock { Text = row.DateLabel, TextWrapping = TextWrapping.Wrap });
            content.Children.Add(new TextBlock { Text = row.Rank, TextWrapping = TextWrapping.Wrap });
            if (row.SourceDescriptions.Count == 0)
                content.Children.Add(new TextBlock { Text = Loc.Tr("calendar_description_unavailable", "No description is available for this event."), TextWrapping = TextWrapping.Wrap });
            foreach (var description in row.SourceDescriptions)
            {
                content.Children.Add(new TextBlock { Text = description.Text, TextWrapping = TextWrapping.Wrap, IsTextSelectionEnabled = true });
                if (description.HasCredit) content.Children.Add(new TextBlock { Text = description.Credit, TextWrapping = TextWrapping.Wrap });
                if (description.HasSource) content.Children.Add(new HyperlinkButton { Content = description.SourceLabel, NavigateUri = description.SourceUri });
            }
            var result = await new ContentDialog { XamlRoot = XamlRoot, Title = row.Title, FlowDirection = FlowDirection,
                Content = new ScrollViewer { Content = content, MaxHeight = 480 },
                PrimaryButtonText = Loc.Tr("calendar_open_readings", "Readings for this Date"),
                CloseButtonText = Loc.Tr("common_done", "Done"), DefaultButton = ContentDialogButton.Close }.ShowAsync();
            if (IsLoaded && result == ContentDialogResult.Primary) SelectDate?.Invoke(row.Date);
        }
        finally { _dialogOpen = false; }
    }
}
