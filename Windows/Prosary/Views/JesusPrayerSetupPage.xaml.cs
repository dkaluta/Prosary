using Prosary.Navigation;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml.Controls;
using Prosary.ViewModels;

namespace Prosary.Views;

public sealed partial class JesusPrayerSetupPage : Page
{
    public JesusPrayerSetupViewModel ViewModel { get; }

    public JesusPrayerSetupPage()
    {
        ViewModel = App.Services.GetRequiredService<JesusPrayerSetupViewModel>();
        ViewModel.Navigation = Router.For(this);
        InitializeComponent();
    }
}
