using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;
using Prosary.Localization;
using Prosary.Navigation;

namespace Prosary.Views;

/// <summary>The cached reading workspace keeps Bible position local to its library window.</summary>
public sealed partial class DesktopReadingsPage : Page
{
    public string Title => Loc.Tr("readings_title", "Readings");
    public string DailyLabel => Loc.Tr("bible_daily_readings", "Daily Readings");
    public string BibleLabel => Loc.Tr("bible_title", "Bible");
    public string CalendarLabel => Loc.Tr("calendar_feasts_solemnities", "Feasts and Solemnities");
    public FlowDirection ReadingFlowDirection => UiLanguageCatalog.IsRightToLeft(UiLanguageCatalog.Current) ? FlowDirection.RightToLeft : FlowDirection.LeftToRight;
    public DesktopReadingsPage() { InitializeComponent(); NavigationCacheMode = NavigationCacheMode.Required; }
    public void ShowDailyReadings() => ReadingModes.SelectedIndex = 0;
    protected override void OnNavigatedTo(NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);
        DailyContent.Content ??= new DesktopTodayPage(Router.For(this).Today, readingsOnly: true);
        CalendarContent.FocusOnDate(Router.For(this).Today?.SelectedDate ?? DateOnly.FromDateTime(DateTime.Today));
        CalendarContent.SelectDate = date =>
        {
            if (Router.For(this).Today is { } today)
                today.SelectedTodayDate = new DateTimeOffset(date.ToDateTime(TimeOnly.MinValue));
            ReadingModes.SelectedIndex = 0;
        };
        if (e.Parameter is string mode) ReadingModes.SelectedIndex = mode == "calendar" ? 1 : 0;
    }
}
