using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;
using Prosary.Navigation;
using Prosary.ViewModels;

namespace Prosary.Views;

/// <summary>Navigation parameter: a BasicPrayerCatalog id ("hailMary").</summary>
public sealed partial class BasicPrayerFlowPage : Page
{
    public BasicPrayerViewModel ViewModel { get; }

    public BasicPrayerFlowPage()
    {
        ViewModel = App.Services.GetRequiredService<BasicPrayerViewModel>();
        InitializeComponent();
    }

    protected override void OnNavigatedTo(NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);
        if (e.Parameter is string prayerId)
        {
            ViewModel.Load(prayerId);
        }
    }

    private void OnNavigateUp(object sender, RoutedEventArgs e) => Router.GoBack();
}
