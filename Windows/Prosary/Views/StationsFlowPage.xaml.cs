using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;
using Prosary.Navigation;
using Prosary.ViewModels;

namespace Prosary.Views;

/// <summary>Navigation parameter: <see cref="Guid"/>? — the launching favorite's id, or null when
/// reached from Home with no Stations favorite saved yet (see <see cref="StationsViewModel.LoadAsync"/>).</summary>
public sealed partial class StationsFlowPage : Page
{
    public StationsViewModel ViewModel { get; }

    public StationsFlowPage()
    {
        ViewModel = App.Services.GetRequiredService<StationsViewModel>();
        InitializeComponent();
    }

    protected override async void OnNavigatedTo(NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);
        var prayerId = e.Parameter as Guid?;
        await ViewModel.LoadAsync(prayerId);
    }

    private void OnNavigateUp(object sender, Microsoft.UI.Xaml.RoutedEventArgs e) => Router.GoBack();
}
