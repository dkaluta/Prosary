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
    public FlowDirection ReadingFlowDirection => UiLanguageCatalog.IsRightToLeft(UiLanguageCatalog.Current) ? FlowDirection.RightToLeft : FlowDirection.LeftToRight;
    public DesktopReadingsPage() { InitializeComponent(); NavigationCacheMode = NavigationCacheMode.Required; }
    protected override void OnNavigatedTo(NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);
        DailyContent.Content ??= new DesktopTodayPage(Router.For(this).Today, readingsOnly: true);
    }
}
