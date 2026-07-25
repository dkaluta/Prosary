using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;
using Prosary.ViewModels;

namespace Prosary.Views;

/// <summary>Navigation parameter: <see cref="Guid"/>? — the favorite to pray, or null to fall
/// back to the default Rosary favorite (see <see cref="RosaryViewModel.LoadAsync"/>).</summary>
public sealed partial class RosaryPrayerPage : Page
{
    // Desktop windows at/above this width get the wide three-column layout (image, vertical bead
    // track, prayer text side by side); narrower windows keep the single-column layout with
    // horizontal bead rows. Matches irosary's RosaryPrayerPage.xaml.cs breakpoint exactly.
    private const double WideLayoutBreakpoint = 700;

    public RosaryViewModel ViewModel { get; }

    public RosaryPrayerPage()
    {
        ViewModel = App.Services.GetRequiredService<RosaryViewModel>();
        InitializeComponent();
        SizeChanged += OnSizeChanged;
    }

    protected override async void OnNavigatedTo(NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);
        var prayerId = e.Parameter as Guid?;
        await ViewModel.LoadAsync(prayerId);
    }

    private void OnSizeChanged(object sender, SizeChangedEventArgs e)
    {
        var isWide = ActualWidth >= WideLayoutBreakpoint;
        WideLayout.Visibility = isWide ? Visibility.Visible : Visibility.Collapsed;
        NarrowLayout.Visibility = isWide ? Visibility.Collapsed : Visibility.Visible;
    }
}
