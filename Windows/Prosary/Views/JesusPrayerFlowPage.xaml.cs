using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;
using Prosary.Controls;
using Prosary.Localization;
using Prosary.Navigation;
using Prosary.ViewModels;

namespace Prosary.Views;

/// <summary>Navigation parameter: <see cref="JesusPrayerFlowParams"/>.</summary>
public sealed partial class JesusPrayerFlowPage : Page
{
    public JesusPrayerViewModel ViewModel { get; }

    private AutoAdvanceTimer? _autoAdvance;

    public JesusPrayerFlowPage()
    {
        ViewModel = App.Services.GetRequiredService<JesusPrayerViewModel>();
        ViewModel.Navigation = Router.For(this);
        InitializeComponent();
        Unloaded += (_, _) => { _autoAdvance?.Dispose(); _autoAdvance = null; };
        ViewModel.ConfirmDelete = plan => PrayerRemovalDialogs.ConfirmDeleteAsync(XamlRoot, plan);
        ViewModel.ShowRemovalError = message => PrayerRemovalDialogs.ShowErrorAsync(XamlRoot, message);
    }

    protected override async void OnNavigatedTo(NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);
        if (!await Router.WaitUntilLoadedAsync(this)) return;
        var parameters = e.Parameter as JesusPrayerFlowParams ?? new JesusPrayerFlowParams(null, null);
        await ViewModel.LoadAsync(ViewModel.Navigation.SavedPrayerID ?? parameters.PrayerId, parameters.Target);
        if (ViewModel.Navigation.OwnerWindow is null) return;
        if (ViewModel.HasSavedContinuation)
        {
            if (e.NavigationMode == NavigationMode.Back) ViewModel.ContinueSavedRun();
                else await ShowResumeDialogAsync();
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
    }

    // A plain back-arrow pop correctly returns to Setup when reached fresh (Home → Setup →
    // Flow); when launched from a saved favorite (one nav level) it lands wherever that came
    // from — either way this is a single pop, distinct from ViewModel.FinishCommand's
    // pop-to-root (see JesusPrayerViewModel's class doc).
    private void OnNavigateUp(object sender, Microsoft.UI.Xaml.RoutedEventArgs e) => Router.For(this).GoBack();
}
