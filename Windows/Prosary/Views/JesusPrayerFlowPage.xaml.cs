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
        InitializeComponent();
    }

    protected override async void OnNavigatedTo(NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);
        var parameters = e.Parameter as JesusPrayerFlowParams ?? new JesusPrayerFlowParams(null, null);
        await ViewModel.LoadAsync(parameters.PrayerId, parameters.Target);
        if (ViewModel.HasSavedContinuation)
        {
            await ShowResumeDialogAsync();
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
    }

    // A plain back-arrow pop correctly returns to Setup when reached fresh (Home → Setup →
    // Flow); when launched from a saved favorite (one nav level) it lands wherever that came
    // from — either way this is a single pop, distinct from ViewModel.FinishCommand's
    // pop-to-root (see JesusPrayerViewModel's class doc).
    private void OnNavigateUp(object sender, Microsoft.UI.Xaml.RoutedEventArgs e) => Router.GoBack();
}
