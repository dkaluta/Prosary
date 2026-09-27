using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Prosary.Localization;
using Prosary.Navigation;
using Prosary.ViewModels;

namespace Prosary.Views;

public sealed partial class AppearancePage : Page
{
    public AppearanceViewModel ViewModel { get; }

    public AppearancePage()
    {
        ViewModel = App.Services.GetRequiredService<AppearanceViewModel>();
        ViewModel.Navigation = Router.For(this);
        InitializeComponent();
        Language = UiLanguageCatalog.ResourceTag(UiLanguageCatalog.Current);
        FlowDirection = UiLanguageCatalog.IsRightToLeft(UiLanguageCatalog.Current)
            ? FlowDirection.RightToLeft : FlowDirection.LeftToRight;
        Loaded += (_, _) => ViewModel.Activate();
        Unloaded += (_, _) => ViewModel.Deactivate();
    }
}
