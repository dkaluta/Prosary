using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;
using Prosary.Localization;
using Prosary.Navigation;

namespace Prosary.Views;

/// <summary>Readings contains the selected day's appointed passages.</summary>
public sealed partial class DesktopReadingsPage : Page
{
    public FlowDirection ReadingFlowDirection => UiLanguageCatalog.IsRightToLeft(UiLanguageCatalog.Current) ? FlowDirection.RightToLeft : FlowDirection.LeftToRight;
    public DesktopReadingsPage() { InitializeComponent(); NavigationCacheMode = NavigationCacheMode.Required; }
    protected override void OnNavigatedTo(NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);
        DailyContent.Content ??= new DesktopTodayPage(Router.For(this).Today, readingsOnly: true);
    }
}
