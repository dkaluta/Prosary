using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;
using Prosary.Navigation;
using Prosary.ViewModels;

namespace Prosary.Views;

/// <summary>Navigation parameter: <see cref="JesusPrayerFlowParams"/>.</summary>
public sealed partial class JesusPrayerFlowPage : Page
{
    public JesusPrayerViewModel ViewModel { get; }

    public JesusPrayerFlowPage()
    {
        ViewModel = App.Services.GetRequiredService<JesusPrayerViewModel>();
        InitializeComponent();
    }

    protected override async void OnNavigatedTo(NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);
        var parameters = e.Parameter as JesusPrayerFlowParams ?? new JesusPrayerFlowParams(null, null);
        await ViewModel.LoadAsync(parameters.PrayerId, parameters.Target);
    }

    // A plain back-arrow pop correctly returns to Setup when reached fresh (Home → Setup →
    // Flow); when launched from a saved favorite (one nav level) it lands wherever that came
    // from — either way this is a single pop, distinct from ViewModel.FinishCommand's
    // pop-to-root (see JesusPrayerViewModel's class doc).
    private void OnNavigateUp(object sender, Microsoft.UI.Xaml.RoutedEventArgs e) => Router.GoBack();
}
