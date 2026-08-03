using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml.Controls;
using Prosary.ViewModels;
using Prosary.Localization;

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
                Title = Loc.Tr("settings_remove_all_title", "Remove all downloaded devotions?"),
                Content = Loc.Tr("settings_remove_all_message", "Devotions from the repository can be downloaded again; hand-imported files cannot."),
                PrimaryButtonText = Loc.Tr("settings_remove_all_confirm", "Remove All"),
                CloseButtonText = Loc.Tr("common_cancel", "Cancel"),
                DefaultButton = ContentDialogButton.Close,
            };
            return await dialog.ShowAsync() == ContentDialogResult.Primary;
        };
    }
}
