using Prosary.Services;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;
using Prosary.Controls;
using Prosary.Models;
using Prosary.Navigation;
using Prosary.ViewModels;
using Prosary.Localization;

namespace Prosary.Views;

/// <summary>Navigation parameter: <see cref="CustomDevotionFlowParams"/> — a generic devotion
/// always needs a bundle id alongside the optional favorite id, since its kind alone
/// (PrayerKind.Custom) doesn't say which devotion to load. Breakpoint constants and the
/// theme/size handlers match RosaryPrayerPage.xaml.cs exactly — see that file for the
/// reasoning.</summary>
public sealed partial class CustomDevotionFlowPage : Page
{
    private const double WideLayoutBreakpoint = 860;
    private const double WideMinorColumnHeightThreshold = 300;

    public CustomDevotionViewModel ViewModel { get; }

    private AutoAdvanceTimer? _autoAdvance;

    public CustomDevotionFlowPage()
    {
        ViewModel = App.Services.GetRequiredService<CustomDevotionViewModel>();
        InitializeComponent();
        Loaded += (_, _) => { AppSettings.TypographyChanged += OnTypographyChanged; OnTypographyChanged(); };
        Unloaded += (_, _) => AppSettings.TypographyChanged -= OnTypographyChanged;
        SizeChanged += OnSizeChanged;
        ActualThemeChanged += OnActualThemeChanged;
    }

    protected override async void OnNavigatedTo(NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);
        ViewModel.HasDarkTheme = ActualTheme == ElementTheme.Dark;
        if (e.Parameter is CustomDevotionFlowParams p)
        {
            await ViewModel.LoadAsync(p.PrayerId, p.BundleId, p.LanguageCode, p.VariantId);
            if (ViewModel.HasSavedContinuation)
            {
                await ShowResumeDialogAsync();
            }
            BuildVariantFlyout();
            BuildLanguageFlyout();
            BuildDayFlyout();
        }

        AutoAdvanceMenu.Populate(AutoAdvanceFlyout, () => _autoAdvance?.Restart());
        _autoAdvance?.Dispose();
        _autoAdvance = new AutoAdvanceTimer(ViewModel);
    }

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

    protected override void OnNavigatedFrom(NavigationEventArgs e)
    {
        base.OnNavigatedFrom(e);
        _autoAdvance?.Dispose();
        _autoAdvance = null;
        ViewModel.StopAudio();
    }

    /// <summary>x:Bind function for the transport strip's play/pause FontIcon (Segoe glyphs:
    /// Play E768, Pause E769).</summary>
    public string PlayPauseGlyph(bool isPlaying) => isPlaying ? "\uE769" : "\uE768";

    // Same MenuFlyout rebuild pattern as the variant flyout: one toggle item per authored day,
    // period-prefixed for the Montfort-style groupings.
    private void BuildDayFlyout()
    {
        DayFlyout.Items.Clear();
        for (var i = 0; i < ViewModel.Days.Count; i++)
        {
            var day = ViewModel.Days[i];
            var item = new ToggleMenuFlyoutItem
            {
                Text = day.Period is { } period
                    ? $"{HebrewDisplayText.WithoutMarks(period)} — {day.LocalizedName}"
                    : day.LocalizedName,
                IsChecked = i == ViewModel.CurrentDayIndex,
            };
            var dayIndex = i;
            item.Click += async (_, _) =>
            {
                await ViewModel.SelectDayAsync(dayIndex);
                BuildDayFlyout();
            };
            DayFlyout.Items.Add(item);
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

    // Same MenuFlyout-has-no-ItemsSource pattern as the variant flyout: "App setting" first,
    // then the bundle's languages by native name, checkmark refreshed on every switch.
    private void BuildLanguageFlyout() =>
        Prosary.Controls.PrayerLanguageMenu.Populate(LanguageFlyout, ViewModel.Languages,
            ViewModel.CurrentLanguageRaw, async raw =>
        {
            await ViewModel.SelectLanguageAsync(raw);
            BuildLanguageFlyout();
        });

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
    private void OnTypographyChanged() => ViewModel.RefreshTypography();

    // UI navigation stays independent of the displayed prayer's writing system.
    public FlowDirection NavigationFlowDirection => UiLanguageCatalog.IsRightToLeft(UiLanguageCatalog.Current)
        ? FlowDirection.RightToLeft : FlowDirection.LeftToRight;
    public string PreviousNavigationGlyph => PrayerNavigation.PreviousGlyph(NavigationFlowDirection == FlowDirection.RightToLeft);
    public string NextNavigationGlyph => PrayerNavigation.NextGlyph(NavigationFlowDirection == FlowDirection.RightToLeft);

}
