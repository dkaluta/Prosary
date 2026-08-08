using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;
using Prosary.ViewModels;

namespace Prosary.Views;

/// <summary>The basic prayers on their own, outside any devotion (Erez, 2026-08-07) — each row
/// opens its prayer as a single step in the shared flow chrome.</summary>
public sealed partial class BasicPrayersPage : Page
{
    public BasicPrayersViewModel ViewModel { get; }

    public BasicPrayersPage()
    {
        ViewModel = App.Services.GetRequiredService<BasicPrayersViewModel>();
        InitializeComponent();
    }

    protected override void OnNavigatedTo(NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);
        ViewModel.Load();
    }
}
