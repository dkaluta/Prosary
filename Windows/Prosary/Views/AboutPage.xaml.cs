using Microsoft.UI.Xaml.Controls;
using Prosary.Navigation;
using Prosary.Services;

namespace Prosary.Views;

public sealed partial class AboutPage : Page
{
    public string VersionText => AppBuildInfo.AboutText;
    public string UkrainianNiceneCredit => Prosary.Localization.Loc.Tr("about_source_ukrainian_nicene",
        "Ukrainian Nicene Creed: Ukrainian Greek Catholic Church, Christ – Our Pascha (2012), p. 10. The source’s bracketed Filioque is retained.");
    public string UkrainianNiceneLinkLabel => Prosary.Localization.Loc.Tr("about_ukrainian_nicene_link", "UGCC Catechism — Nicene Creed");

    public AboutPage()
    {
        InitializeComponent();
    }

    private void OnNavigateUp(object sender, Microsoft.UI.Xaml.RoutedEventArgs e) => Router.For(this).GoBack();
}
