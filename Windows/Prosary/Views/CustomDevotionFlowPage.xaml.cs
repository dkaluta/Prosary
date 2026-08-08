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
    private const double WideLayoutBreakpoint = 700;
    private const double WideMinorColumnHeightThreshold = 300;

    public CustomDevotionViewModel ViewModel { get; }

    private AutoAdvanceTimer? _autoAdvance;

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
            BuildLanguageFlyout();
            BuildDayFlyout();
        }

        AutoAdvanceMenu.Populate(AutoAdvanceFlyout, () => _autoAdvance?.Restart());
        _autoAdvance?.Dispose();
        _autoAdvance = new AutoAdvanceTimer(ViewModel);
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
                Text = day.Period is { } period ? $"{period} — {day.LocalizedName}" : day.LocalizedName,
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
    private void BuildLanguageFlyout()
    {
        LanguageFlyout.Items.Clear();
        var choices = new List<(string Raw, string Name)> { (LanguageCatalog.DefaultSentinel, Loc.Tr("flow_app_setting", "App setting")) };
        choices.AddRange(ViewModel.Languages.Select(l => (l.Code, l.NativeName)));
        // A language row checks whenever the chosen code IS that language — rites included, by
        // base: a favorite carrying "he-x-gamliel" keeps עברית checked. Exact matching made the
        // Hebrew check vanish for the Mission's rite while the Vicariate's (whose code IS "he")
        // kept it. This flyout does not offer the rites themselves yet — the rite is chosen in
        // Settings/the editor — but the check must still tell the truth about the language.
        var chosen = ViewModel.CurrentLanguageRaw;
        var chosenBase = LanguageCatalog.BaseLanguage(chosen) ?? chosen;
        foreach (var (raw, name) in choices)
        {
            var isChecked = raw == LanguageCatalog.DefaultSentinel
                ? chosen == LanguageCatalog.DefaultSentinel
                : chosen != LanguageCatalog.DefaultSentinel && chosenBase == raw;
            var item = new ToggleMenuFlyoutItem
            {
                Text = name,
                IsChecked = isChecked,
            };
            var picked = raw;
            item.Click += async (_, _) =>
            {
                await ViewModel.SelectLanguageAsync(picked);
                BuildLanguageFlyout();
            };
            LanguageFlyout.Items.Add(item);
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
