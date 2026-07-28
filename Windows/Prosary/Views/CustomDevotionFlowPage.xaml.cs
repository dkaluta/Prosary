using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;
using Prosary.Navigation;
using Prosary.ViewModels;

namespace Prosary.Views;

/// <summary>Navigation parameter: <see cref="CustomDevotionFlowParams"/> — a generic devotion
/// always needs a bundle id alongside the optional favorite id, since its kind alone
/// (PrayerKind.Custom) doesn't say which devotion to load. Breakpoint constants and the
/// theme/size handlers match RosaryPrayerPage.xaml.cs exactly — see that file for the
/// reasoning.</summary>
public sealed partial class CustomDevotionFlowPage : Page
{
    private const double WideLayoutBreakpoint = 700;
    private const double WideMinorColumnHeightThreshold = 300;

    public CustomDevotionViewModel ViewModel { get; }

    public CustomDevotionFlowPage()
    {
        ViewModel = App.Services.GetRequiredService<CustomDevotionViewModel>();
        InitializeComponent();
        SizeChanged += OnSizeChanged;
        ActualThemeChanged += OnActualThemeChanged;
    }

    protected override async void OnNavigatedTo(NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);
        ViewModel.HasDarkTheme = ActualTheme == ElementTheme.Dark;
        if (e.Parameter is CustomDevotionFlowParams p)
        {
            await ViewModel.LoadAsync(p.PrayerId, p.BundleId);
            BuildVariantFlyout();
        }
    }

    // MenuFlyout has no ItemsSource, so the variant items are built here after load — one
    // toggle item per variant, checked state refreshed on every switch.
    private void BuildVariantFlyout()
    {
        VariantFlyout.Items.Clear();
        foreach (var variant in ViewModel.Variants)
        {
            var item = new ToggleMenuFlyoutItem
            {
                Text = variant.LocalizedName,
                IsChecked = variant.Id == ViewModel.CurrentVariantId,
            };
            var variantId = variant.Id;
            item.Click += async (_, _) =>
            {
                await ViewModel.SelectVariantAsync(variantId);
                BuildVariantFlyout();
            };
            VariantFlyout.Items.Add(item);
        }
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
