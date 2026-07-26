using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;
using Prosary.Navigation;
using Prosary.ViewModels;

namespace Prosary.Views;

/// <summary>Navigation parameter: <see cref="Guid"/>? — the launching favorite's id, or null when
/// reached from Home with no Seven Sorrows favorite saved yet (see
/// <see cref="SevenSorrowsViewModel.LoadAsync"/>). Breakpoint constants match
/// RosaryPrayerPage.xaml.cs exactly — see that file for the reasoning.</summary>
public sealed partial class SevenSorrowsFlowPage : Page
{
    private const double WideLayoutBreakpoint = 700;
    private const double WideMinorColumnHeightThreshold = 300;

    public SevenSorrowsViewModel ViewModel { get; }

    public SevenSorrowsFlowPage()
    {
        ViewModel = App.Services.GetRequiredService<SevenSorrowsViewModel>();
        InitializeComponent();
        SizeChanged += OnSizeChanged;
        ActualThemeChanged += OnActualThemeChanged;
    }

    protected override async void OnNavigatedTo(NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);
        ViewModel.HasDarkTheme = ActualTheme == ElementTheme.Dark;
        var prayerId = e.Parameter as Guid?;
        await ViewModel.LoadAsync(prayerId);
    }

    private void OnActualThemeChanged(FrameworkElement sender, object args)
        => ViewModel.HasDarkTheme = ActualTheme == ElementTheme.Dark;

    private void OnNavigateUp(object sender, RoutedEventArgs e) => Router.GoBack();

    private void OnSizeChanged(object sender, SizeChangedEventArgs e)
    {
        var isWide = ActualWidth >= WideLayoutBreakpoint;
        WideLayout.Visibility = isWide ? Visibility.Visible : Visibility.Collapsed;
        NarrowLayout.Visibility = isWide ? Visibility.Collapsed : Visibility.Visible;
    }

    private void WideLayout_SizeChanged(object sender, SizeChangedEventArgs e)
    {
        ViewModel.HasRoomForSingleMinorColumn = e.NewSize.Height >= WideMinorColumnHeightThreshold;
    }
}
