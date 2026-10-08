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
    private async void OnChooseMystery(object sender, RoutedEventArgs e)
    {
        await ShowMysteryChoiceDialogAsync();
    }
    public RosaryViewModel ViewModel { get; }

    private AutoAdvanceTimer? _autoAdvance;
    private readonly PrayerFlowReader _reader;
    private (bool, string, string)? _lastPrayerWording;
    private bool _isLoadingSession;
    private bool _isShowingMysteryDialog;
    private bool _isPageActive;

    private sealed record GroupChoice(MysteryGroup Group, string Title);

    public RosaryPrayerPage()
    {
        ViewModel = App.Services.GetRequiredService<RosaryViewModel>();
        ViewModel.Navigation = Router.For(this);
        InitializeComponent();
        // Keep the clicked item attached until WinUI dismisses its menu.
        LanguageFlyout.Opening += (_, _) => BuildLanguageFlyout();
        var chooseMystery = Loc.Tr("flow_choose_mystery", "Choose Mystery");
        Microsoft.UI.Xaml.Automation.AutomationProperties.SetName(MysteryPickerButton, chooseMystery);
        ToolTipService.SetToolTip(MysteryPickerButton, chooseMystery);
        _reader = new PrayerFlowReader(NarrowReader, NarrowBody);
        _reader.Register(WideReader, WideBody);
        ViewModel.PropertyChanged += OnFlowPropertyChanged;
        Loaded += (_, _) =>
        {
            AppSettings.TypographyChanged += OnTypographyChanged;
            AppSettings.PrayerWordingChanged += OnPrayerWordingChanged;
            AppSettings.PopeIntentionPreferenceChanged += OnTypographyChanged;
            OnPrayerWordingChanged();
            OnTypographyChanged();
        };
        Unloaded += (_, _) =>
        {
            _autoAdvance?.Dispose();
            _autoAdvance = null;
            AppSettings.TypographyChanged -= OnTypographyChanged;
            AppSettings.PrayerWordingChanged -= OnPrayerWordingChanged;
            AppSettings.PopeIntentionPreferenceChanged -= OnTypographyChanged;
        };
        ActualThemeChanged += OnActualThemeChanged;
    }

    protected override async void OnNavigatedTo(NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);
        _isPageActive = true;
        _isLoadingSession = true;
        PauseAutoAdvance();
        try
        {
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
            if (ViewModel.RequiresMysteryChoice) await ShowMysteryChoiceDialogAsync();

            if (ViewModel.Navigation.OwnerWindow is null) return;
            AutoAdvanceMenu.Populate(AutoAdvanceFlyout, () => _autoAdvance?.Restart());
        }
        finally
        {
            _isLoadingSession = false;
            ResumeAutoAdvance();
        }
    }

    protected override void OnNavigatedFrom(NavigationEventArgs e)
    {
        base.OnNavigatedFrom(e);
        _isPageActive = false;
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
        });

    private void PauseAutoAdvance()
    {
        _autoAdvance?.Dispose();
        _autoAdvance = null;
    }

    private void ResumeAutoAdvance()
    {
        PauseAutoAdvance();
        if (_isPageActive && !_isLoadingSession && !_isShowingMysteryDialog
            && !ViewModel.RequiresMysteryChoice && ViewModel.HasSteps && ViewModel.Navigation.OwnerWindow is not null)
            _autoAdvance = new AutoAdvanceTimer(ViewModel);
    }

    private async Task ShowMysteryChoiceDialogAsync()
    {
        if (_isShowingMysteryDialog) return;
        var mandatory = ViewModel.RequiresMysteryChoice;
        _isShowingMysteryDialog = true;
        PauseAutoAdvance();
        try
        {
            var groups = new ComboBox { Header = Loc.Tr("flow_mystery_set", "Mystery Set"),
                HorizontalAlignment = HorizontalAlignment.Stretch, DisplayMemberPath = nameof(GroupChoice.Title),
                ItemsSource = Enum.GetValues<MysteryGroup>().Select(group => new GroupChoice(group, group.UiName())).ToArray(),
                SelectedIndex = -1 };
            var mysteries = new StackPanel { Spacing = 8, Visibility = Visibility.Collapsed };
            var content = new StackPanel { Spacing = 12 };
            content.Children.Add(groups);
            content.Children.Add(new ScrollViewer { Content = mysteries, MaxHeight = 360,
                VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
                HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled });
            var dialog = new ContentDialog { XamlRoot = XamlRoot, FlowDirection = NavigationFlowDirection,
                Title = Loc.Tr("flow_choose_mystery", "Choose Mystery"), Content = content,
                CloseButtonText = Loc.Tr("common_cancel", "Cancel"),
                DefaultButton = ContentDialogButton.None };
            MysteryGroup? selectedGroup = null;
            int? selectedOrder = null;
            var hasChoice = false;
            Button ChoiceButton(string title, MysteryGroup group, int? order)
            {
                var button = new Button { HorizontalAlignment = HorizontalAlignment.Stretch,
                    HorizontalContentAlignment = HorizontalAlignment.Stretch,
                    Content = new TextBlock { Text = title, TextWrapping = TextWrapping.Wrap,
                        TextAlignment = NavigationFlowDirection == FlowDirection.RightToLeft ? TextAlignment.Right : TextAlignment.Left } };
                button.Click += (_, _) =>
                {
                    selectedGroup = group;
                    selectedOrder = order;
                    hasChoice = true;
                    dialog.Hide();
                };
                return button;
            }
            groups.SelectionChanged += (_, _) =>
            {
                if (groups.SelectedItem is not GroupChoice chosen) return;
                mysteries.Children.Clear();
                mysteries.Children.Add(ChoiceButton(Loc.Tr("flow_entire_set", "Entire Set"), chosen.Group, null));
                foreach (var mystery in MysteryCatalog.ForGroup(chosen.Group))
                    mysteries.Children.Add(ChoiceButton(MysteryTranslations.Get(UiLanguageCatalog.Current, mystery.ImageKey).Title,
                        chosen.Group, mystery.Order));
                mysteries.Visibility = Visibility.Visible;
            };
            await dialog.ShowAsync();
            if (!_isPageActive || ViewModel.Navigation.OwnerWindow is null) return;
            if (hasChoice && selectedGroup is { } group)
                ViewModel.ChooseMystery(group, selectedOrder);
            else if (mandatory) ViewModel.Navigation.GoBack();
        }
        finally
        {
            _isShowingMysteryDialog = false;
            ResumeAutoAdvance();
        }
    }

    private void FlowContent_SizeChanged(object sender, SizeChangedEventArgs e) => UpdateFlowLayout();

    private void OnFlowPropertyChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName is nameof(ViewModel.Body) or nameof(ViewModel.Progress)) _reader.Reset();
        if (e.PropertyName is nameof(ViewModel.GroupColumns) or nameof(ViewModel.BottomBeads)) UpdateFlowLayout();
        if (e.PropertyName == nameof(ViewModel.RequiresMysteryChoice) && ViewModel.RequiresMysteryChoice)
        {
            PauseAutoAdvance();
            if (_isPageActive && !_isLoadingSession && !_isShowingMysteryDialog)
                DispatcherQueue.TryEnqueue(async () => await ShowMysteryChoiceDialogAsync());
        }
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
