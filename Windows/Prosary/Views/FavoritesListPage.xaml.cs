using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;
using Prosary.ViewModels;

namespace Prosary.Views;

public sealed partial class FavoritesListPage : Page
{
    public FavoritesViewModel ViewModel { get; }

    public FavoritesListPage()
    {
        ViewModel = App.Services.GetRequiredService<FavoritesViewModel>();
        InitializeComponent();
    }

    protected override async void OnNavigatedTo(NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);
        await ViewModel.LoadAsync();
    }
}
