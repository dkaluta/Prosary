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
using System.ComponentModel;

namespace Prosary.Views;

/// <summary>Navigation parameter: <see cref="CustomDevotionFlowParams"/> — a generic devotion
/// always needs a bundle id alongside the optional favorite id, since its kind alone
/// (PrayerKind.Custom) doesn't say which devotion to load. Sizing and reading-position behavior
/// are shared with RosaryPrayerPage.</summary>
public sealed partial class CustomDevotionFlowPage : Page
{
    public CustomDevotionViewModel ViewModel { get; }

    private AutoAdvanceTimer? _autoAdvance;
    private readonly PrayerFlowReader _reader;
    private (bool, string, string)? _lastPrayerWording;

    public CustomDevotionFlowPage()
    {
        ViewModel = App.Services.GetRequiredService<CustomDevotionViewModel>();
        ViewModel.Navigation = Router.For(this);
        InitializeComponent();
        _reader = new PrayerFlowReader(NarrowReader, NarrowBody);
        _reader.Register(WideReader, WideBody);
        ViewModel.PropertyChanged += OnFlowPropertyChanged;
        Loaded += (_, _) =>
        {
            AppSettings.TypographyChanged += OnTypographyChanged;
            AppSettings.PrayerWordingChanged += OnPrayerWordingChanged;
            OnPrayerWordingChanged();
            OnTypographyChanged();
        };
        Unloaded += (_, _) =>
        {
            _autoAdvance?.Dispose();
            _autoAdvance = null;
            ViewModel.StopAudio();
            AppSettings.TypographyChanged -= OnTypographyChanged;
            AppSettings.PrayerWordingChanged -= OnPrayerWordingChanged;
        };
        ActualThemeChanged += OnActualThemeChanged;
    }

    protected override async void OnNavigatedTo(NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);
        if (!await Router.WaitUntilLoadedAsync(this)) return;
        ViewModel.HasDarkTheme = ActualTheme == ElementTheme.Dark;
        if (e.Parameter is CustomDevotionFlowParams p)
        {
            var savedID = ViewModel.Navigation.SavedPrayerID ?? p.PrayerId;
            await ViewModel.LoadAsync(savedID, p.BundleId,
                savedID is null ? p.LanguageCode : null, savedID is null ? p.VariantId : null);
            if (ViewModel.Navigation.OwnerWindow is null) return;
            if (ViewModel.HasSavedContinuation)
            {
                if (e.NavigationMode == NavigationMode.Back) ViewModel.ContinueSavedRun();
                else await ShowResumeDialogAsync();
            }
            BuildVariantFlyout();
            BuildLanguageFlyout();
            BuildDayFlyout();
        }

        if (ViewModel.Navigation.OwnerWindow is null) return;
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
        var result = await dialog.ShowAsync();
        if (ViewModel.Navigation.OwnerWindow is null) return;
        if (result == ContentDialogResult.Primary)
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
                Text = day.LocalizedPeriod is { } period
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

    private void OnNavigateUp(object sender, RoutedEventArgs e) => Router.For(this).GoBack();

    private void FlowContent_SizeChanged(object sender, SizeChangedEventArgs e) => UpdateFlowLayout();

    private void OnFlowPropertyChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName is nameof(ViewModel.Body) or nameof(ViewModel.Progress)) _reader.Reset();
        if (e.PropertyName is nameof(ViewModel.GroupColumns) or nameof(ViewModel.BottomBeads) or nameof(ViewModel.ShowsBeadTrack))
            UpdateFlowLayout();
    }

    private void UpdateFlowLayout()
    {
        var layout = PrayerFlowLayout.Resolve(FlowContent.ActualWidth, FlowContent.ActualHeight,
            ViewModel.GroupColumns.Count, ViewModel.ShowsBeadTrack, ViewModel.BottomBeads.Count > 0);
        ViewModel.HasRoomForSingleMinorColumn = layout.HasRoomForSingleMinorColumn;
        WideArtwork.Width = WideArtwork.Height = layout.ImageSide;
        WideLayout.Visibility = layout.IsWide ? Visibility.Visible : Visibility.Collapsed;
        NarrowLayout.Visibility = layout.IsWide ? Visibility.Collapsed : Visibility.Visible;
        _reader?.UseSurface(layout.IsWide ? WideReader : NarrowReader, layout.IsWide ? WideBody : NarrowBody);
    }
    private void OnTypographyChanged() => ViewModel.RefreshTypography();
    private void OnPrayerWordingChanged()
    {
        var wording = (AppSettings.UseJaffaHailMaryWording, AppSettings.AramaicSignOfCrossForm, AppSettings.DefaultLanguageCode);
        if (_lastPrayerWording == wording) return;
        _lastPrayerWording = wording;
        ViewModel.RefreshPrayerWording();
    }

    // UI navigation stays independent of the displayed prayer's writing system.
    public FlowDirection NavigationFlowDirection => UiLanguageCatalog.IsRightToLeft(UiLanguageCatalog.Current)
        ? FlowDirection.RightToLeft : FlowDirection.LeftToRight;
    public string PreviousNavigationGlyph => PrayerNavigation.PreviousGlyph(NavigationFlowDirection == FlowDirection.RightToLeft);
    public string NextNavigationGlyph => PrayerNavigation.NextGlyph(NavigationFlowDirection == FlowDirection.RightToLeft);

}
