using Microsoft.UI.Xaml.Controls;
using Prosary.Navigation;
using Prosary.Services;

namespace Prosary.Views;

public sealed partial class AboutPage : Page
{
    public string VersionText => AppBuildInfo.AboutText;

    public AboutPage()
    {
        InitializeComponent();
    }

    private void OnNavigateUp(object sender, Microsoft.UI.Xaml.RoutedEventArgs e) => Router.For(this).GoBack();
}
