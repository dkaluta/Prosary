using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Automation;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;
using Prosary.Localization;
using Prosary.Models;
using Prosary.Navigation;
using Prosary.ViewModels;

namespace Prosary.Views;

/// <summary>Navigation parameter: a BasicPrayerCatalog id ("hailMary").</summary>
public sealed partial class BasicPrayerFlowPage : Page
{
    public BasicPrayerViewModel ViewModel { get; }

    public BasicPrayerFlowPage()
    {
        ViewModel = App.Services.GetRequiredService<BasicPrayerViewModel>();
        ViewModel.Navigation = Router.For(this);
        InitializeComponent();
        // Keep the clicked item attached until WinUI dismisses its menu.
        LanguageFlyout.Opening += (_, _) => BuildLanguageFlyout();
        var languageLabel = Loc.Tr("EdLanguageHeader/Text", "Prayer language");
        AutomationProperties.SetName(LanguageMenuButton, languageLabel);
        ToolTipService.SetToolTip(LanguageMenuButton, languageLabel);
    }

    protected override void OnNavigatedTo(NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);
        if (e.Parameter is string prayerId)
        {
            ViewModel.Load(prayerId);
        }
    }

    private void BuildLanguageFlyout() =>
        Prosary.Controls.PrayerLanguageMenu.Populate(LanguageFlyout, ViewModel.Languages,
            ViewModel.CurrentLanguageRaw, raw =>
        {
            ViewModel.SelectLanguage(raw);
            return Task.CompletedTask;
        }, ViewModel.HebrewRites);

    private void OnNavigateUp(object sender, RoutedEventArgs e) => Router.For(this).GoBack();
}
