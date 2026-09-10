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
using System.ComponentModel;

namespace Prosary.Views;

/// <summary>Navigation parameter: <see cref="Guid"/>? — the favorite to pray, or null to fall
/// back to the default Rosary favorite (see <see cref="RosaryViewModel.LoadAsync"/>).</summary>
public sealed partial class RosaryPrayerPage : Page
{
    public RosaryViewModel ViewModel { get; }

    private AutoAdvanceTimer? _autoAdvance;
    private readonly PrayerFlowReader _reader;
    private (bool, string, string)? _lastPrayerWording;

    public RosaryPrayerPage()
    {
        ViewModel = App.Services.GetRequiredService<RosaryViewModel>();
        ViewModel.Navigation = Router.For(this);
        InitializeComponent();
        _reader = new PrayerFlowReader(NarrowReader, NarrowBody);
        _reader.Register(WideReader, WideBody);
        ViewModel.PropertyChanged += OnFlowPropertyChanged;
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
        if (e.Parameter is Prosary.Models.Prayer adHoc)
        {
            // The preset picker's "Pray any Rosary" — an unsaved session.
            ViewModel.LoadAdHoc(adHoc);
        }
        else
        {
            await ViewModel.LoadAsync(e.Parameter as Guid?);
        }

        if (ViewModel.Navigation.OwnerWindow is null) return;
        if (ViewModel.HasSavedContinuation)
        {
            if (e.NavigationMode == NavigationMode.Back) ViewModel.ContinueSavedRun();
                else await ShowResumeDialogAsync();
        }
        BuildLanguageFlyout();

        if (ViewModel.Navigation.OwnerWindow is null) return;
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

    private void OnNavigateUp(object sender, RoutedEventArgs e) => Router.For(this).GoBack();

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

    private void BuildLanguageFlyout() =>
        Prosary.Controls.PrayerLanguageMenu.Populate(LanguageFlyout, ViewModel.Languages,
            ViewModel.CurrentLanguageRaw, async raw =>
        {
            await ViewModel.SelectLanguageAsync(raw);
            BuildLanguageFlyout();
        });

    private void FlowContent_SizeChanged(object sender, SizeChangedEventArgs e) => UpdateFlowLayout();

    private void OnFlowPropertyChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName is nameof(ViewModel.Body) or nameof(ViewModel.Progress)) _reader.Reset();
        if (e.PropertyName is nameof(ViewModel.GroupColumns) or nameof(ViewModel.BottomBeads)) UpdateFlowLayout();
    }

    private void UpdateFlowLayout()
    {
        var layout = PrayerFlowLayout.Resolve(FlowContent.ActualWidth, FlowContent.ActualHeight,
            ViewModel.GroupColumns.Count, true, ViewModel.BottomBeads.Count > 0);
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
