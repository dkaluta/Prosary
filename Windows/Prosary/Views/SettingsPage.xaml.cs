using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml.Controls;
using Prosary.ViewModels;

namespace Prosary.Views;

public sealed partial class SettingsPage : Page
{
    public SettingsViewModel ViewModel { get; }

    public SettingsPage()
    {
        ViewModel = App.Services.GetRequiredService<SettingsViewModel>();
        InitializeComponent();

        // Dialogs need a XamlRoot, so the ViewModel delegates the remove-all confirmation here.
        ViewModel.ConfirmRemoveAll = async () =>
        {
            var dialog = new ContentDialog
            {
                XamlRoot = XamlRoot,
                Title = "Remove all downloaded devotions?",
                Content = "Devotions from the repository can be downloaded again; hand-imported files cannot.",
                PrimaryButtonText = "Remove All",
                CloseButtonText = "Cancel",
                DefaultButton = ContentDialogButton.Close,
            };
            return await dialog.ShowAsync() == ContentDialogResult.Primary;
        };
    }
}
