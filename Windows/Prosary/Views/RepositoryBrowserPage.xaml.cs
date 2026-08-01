using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;
using Prosary.Navigation;
using Prosary.ViewModels;

namespace Prosary.Views;

/// <summary>The prayers.prosary.app browser — see <see cref="RepositoryBrowserViewModel"/>.
/// No navigation parameter.</summary>
public sealed partial class RepositoryBrowserPage : Page
{
    public RepositoryBrowserViewModel ViewModel { get; }

    public RepositoryBrowserPage()
    {
        ViewModel = App.Services.GetRequiredService<RepositoryBrowserViewModel>();
        InitializeComponent();
    }

    protected override async void OnNavigatedTo(NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);
        await ViewModel.LoadAsync();
    }

    private void OnNavigateUp(object sender, RoutedEventArgs e) => Router.GoBack();
}
