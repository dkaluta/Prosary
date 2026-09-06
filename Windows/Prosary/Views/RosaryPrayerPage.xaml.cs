using Prosary.Services;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;
using Prosary.Controls;
using Prosary.Localization;
using Prosary.Models;
using Prosary.Navigation;
using Prosary.ViewModels;

namespace Prosary.Views;

/// <summary>Navigation parameter: <see cref="Guid"/>? — the favorite to pray, or null to fall
/// back to the default Rosary favorite (see <see cref="RosaryViewModel.LoadAsync"/>).</summary>
public sealed partial class RosaryPrayerPage : Page
{
    // Desktop windows at/above this width get the wide three-column layout (image, major/minor
    // bead columns, prayer text side by side); narrower windows keep the single-column layout
    // with horizontal bead rows. Matches irosary's RosaryPrayerPage.xaml.cs breakpoint.
    private const double WideLayoutBreakpoint = 860;

    // A single 10-tall minor-beads column needs roughly 254pt of height (matching iOS's own
    // comment in PrayerStepFlowView.swift) — below that, the wide layout's minor beads split into
    // two 5-tall columns instead. Matches iOS's hasRoomForSingleMinorColumn threshold exactly.
    private const double WideMinorColumnHeightThreshold = 300;

    public RosaryViewModel ViewModel { get; }

    private AutoAdvanceTimer? _autoAdvance;

    public RosaryPrayerPage()
    {
        ViewModel = App.Services.GetRequiredService<RosaryViewModel>();
        InitializeComponent();
        ViewModel.OfferLitany = async () =>
        {
            var dialog = new ContentDialog
            {
                XamlRoot = XamlRoot,
                Title = Loc.Tr("rosary_litany_prompt", "Continue with the Litany of the Blessed Virgin Mary?"),
                PrimaryButtonText = Loc.Tr("rosary_pray_litany", "Pray the Litany"),
                CloseButtonText = Loc.Tr("common_finish", "Finish"),
                DefaultButton = ContentDialogButton.Close,
            };
            return await dialog.ShowAsync() == ContentDialogResult.Primary;
        };
        Loaded += (_, _) => { AppSettings.TypographyChanged += OnTypographyChanged; OnTypographyChanged(); };
        Unloaded += (_, _) => AppSettings.TypographyChanged -= OnTypographyChanged;
        SizeChanged += OnSizeChanged;
        ActualThemeChanged += OnActualThemeChanged;
    }

    protected override async void OnNavigatedTo(NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);
        ViewModel.HasDarkTheme = ActualTheme == ElementTheme.Dark;
        if (e.Parameter is Prosary.Models.Prayer adHoc)
        {
            // The preset picker's "Pray any Rosary" — an unsaved session.
            ViewModel.LoadAdHoc(adHoc);
        }
        else
        {
            await ViewModel.LoadAsync(e.Parameter as Guid?);
        }

        if (ViewModel.HasSavedContinuation)
        {
            await ShowResumeDialogAsync();
        }
        BuildLanguageFlyout();

        AutoAdvanceMenu.Populate(AutoAdvanceFlyout, () => _autoAdvance?.Restart());
        _autoAdvance?.Dispose();
        _autoAdvance = new AutoAdvanceTimer(ViewModel);
    }

    protected override void OnNavigatedFrom(NavigationEventArgs e)
    {
        base.OnNavigatedFrom(e);
        _autoAdvance?.Dispose();
        _autoAdvance = null;
    }

    private void OnActualThemeChanged(FrameworkElement sender, object args)
        => ViewModel.HasDarkTheme = ActualTheme == ElementTheme.Dark;

    private void OnNavigateUp(object sender, RoutedEventArgs e) => Router.GoBack();

    private async Task ShowResumeDialogAsync()
    {
        var dialog = new ContentDialog
        {
            XamlRoot = XamlRoot,
            Title = Loc.Tr("prayer_resume_title", "Continue where you left off?"),
            Content = Loc.Tr("prayer_resume_message", "Continue this unfinished prayer, or restart from the beginning."),
            PrimaryButtonText = Loc.Tr("common_continue", "Continue"),
            SecondaryButtonText = Loc.Tr("common_restart", "Restart"),
            DefaultButton = ContentDialogButton.Primary,
        };
        if (await dialog.ShowAsync() == ContentDialogResult.Primary)
        {
            ViewModel.ContinueSavedRun();
        }
        else
        {
            ViewModel.RestartRun();
        }
    }

    private void BuildLanguageFlyout() =>
        Prosary.Controls.PrayerLanguageMenu.Populate(LanguageFlyout, ViewModel.Languages,
            ViewModel.CurrentLanguageRaw, async raw =>
        {
            await ViewModel.SelectLanguageAsync(raw);
            BuildLanguageFlyout();
        });

    private void OnSizeChanged(object sender, SizeChangedEventArgs e)
    {
        var isWide = ActualWidth >= WideLayoutBreakpoint;
        WideLayout.Visibility = isWide ? Visibility.Visible : Visibility.Collapsed;
        NarrowLayout.Visibility = isWide ? Visibility.Collapsed : Visibility.Visible;
    }

    // WideLayout's own height reflects the actual available vertical space for the wide layout
    // (it fills Grid.Row="3", the page's remaining height after the back-button header/season
    // bar/progress header/footer) — measuring the beads column's own rendered height instead
    // would be circular, since that size is itself a consequence of which minor-beads layout
    // gets chosen.
    private void WideLayout_SizeChanged(object sender, SizeChangedEventArgs e)
    {
        ViewModel.HasRoomForSingleMinorColumn = e.NewSize.Height >= WideMinorColumnHeightThreshold;
    }
    private void OnTypographyChanged() => ViewModel.RefreshTypography();

    // UI navigation stays independent of the displayed prayer's writing system.
    public FlowDirection NavigationFlowDirection => UiLanguageCatalog.IsRightToLeft(UiLanguageCatalog.Current)
        ? FlowDirection.RightToLeft : FlowDirection.LeftToRight;
    public string PreviousNavigationGlyph => PrayerNavigation.PreviousGlyph(NavigationFlowDirection == FlowDirection.RightToLeft);
    public string NextNavigationGlyph => PrayerNavigation.NextGlyph(NavigationFlowDirection == FlowDirection.RightToLeft);

}
