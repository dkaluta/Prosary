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
        InitializeComponent();
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
            BuildLanguageFlyout();
        }
    }

    private void BuildLanguageFlyout()
    {
        LanguageFlyout.Items.Clear();
        var choices = new List<(string Raw, string Name)>
        {
            (LanguageCatalog.DefaultSentinel, Loc.Tr("flow_app_setting", "App setting")),
        };
        choices.AddRange(ViewModel.Languages.Select(language => (language.Code, language.NativeName)));
        foreach (var (raw, name) in choices)
        {
            var item = new ToggleMenuFlyoutItem
            {
                Text = name,
                IsChecked = ViewModel.CurrentLanguageRaw == raw,
            };
            item.Click += (_, _) =>
            {
                ViewModel.SelectLanguage(raw);
                BuildLanguageFlyout();
            };
            LanguageFlyout.Items.Add(item);
        }
    }

    private void OnNavigateUp(object sender, RoutedEventArgs e) => Router.GoBack();
}
