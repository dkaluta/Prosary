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
    // Desktop windows at/above this width get the wide three-column layout (image, major/minor
    // bead columns, prayer text side by side); narrower windows keep the single-column layout
    // with horizontal bead rows. Matches irosary's RosaryPrayerPage.xaml.cs breakpoint.
    private const double WideLayoutBreakpoint = 700;

    // A single 10-tall minor-beads column needs roughly 254pt of height (matching iOS's own
    // comment in PrayerStepFlowView.swift) — below that, the wide layout's minor beads split into
    // two 5-tall columns instead. Matches iOS's hasRoomForSingleMinorColumn threshold exactly.
    private const double WideMinorColumnHeightThreshold = 300;

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

    // WideLayout's own height reflects the actual available vertical space for the wide layout
    // (it fills Grid.Row="2", the page's remaining height after the season bar/progress header/
    // footer) — measuring the beads column's own rendered height instead would be circular, since
    // that size is itself a consequence of which minor-beads layout gets chosen.
    private void WideLayout_SizeChanged(object sender, SizeChangedEventArgs e)
    {
        ViewModel.HasRoomForSingleMinorColumn = e.NewSize.Height >= WideMinorColumnHeightThreshold;
    }
}
