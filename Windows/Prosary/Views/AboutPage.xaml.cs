using Microsoft.UI.Xaml.Controls;
using Prosary.Navigation;

namespace Prosary.Views;

public sealed partial class AboutPage : Page
{
    public AboutPage()
    {
        InitializeComponent();
    }

    private void OnNavigateUp(object sender, Microsoft.UI.Xaml.RoutedEventArgs e) => Router.GoBack();
}
