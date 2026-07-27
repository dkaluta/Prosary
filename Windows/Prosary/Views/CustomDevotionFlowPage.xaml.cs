using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;
using Prosary.Navigation;
using Prosary.ViewModels;

namespace Prosary.Views;

/// <summary>Navigation parameter: <see cref="CustomDevotionFlowParams"/> — unlike the 5 hardcoded
/// simplified devotions, a generic devotion always needs a bundle id alongside the optional
/// favorite id, since its kind alone (PrayerKind.Custom) doesn't say which devotion to load.</summary>
public sealed partial class CustomDevotionFlowPage : Page
{
    public CustomDevotionViewModel ViewModel { get; }

    public CustomDevotionFlowPage()
    {
        ViewModel = App.Services.GetRequiredService<CustomDevotionViewModel>();
        InitializeComponent();
    }

    protected override async void OnNavigatedTo(NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);
        if (e.Parameter is CustomDevotionFlowParams p)
        {
            await ViewModel.LoadAsync(p.PrayerId, p.BundleId);
        }
    }

    private void OnNavigateUp(object sender, Microsoft.UI.Xaml.RoutedEventArgs e) => Router.GoBack();
}
