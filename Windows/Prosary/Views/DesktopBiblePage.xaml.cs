using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;
using Prosary.Localization;

namespace Prosary.Views;

/// <summary>The library's full Scripture reader retains its place between destinations.</summary>
public sealed partial class DesktopBiblePage : Page
{
    public FlowDirection ContentDirection => UiLanguageCatalog.IsRightToLeft(UiLanguageCatalog.Current)
        ? FlowDirection.RightToLeft : FlowDirection.LeftToRight;

    public DesktopBiblePage()
    {
        InitializeComponent();
        NavigationCacheMode = NavigationCacheMode.Required;
    }
}
