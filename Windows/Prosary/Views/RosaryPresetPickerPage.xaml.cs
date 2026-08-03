using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;
using Prosary.ViewModels;
using Prosary.Localization;

namespace Prosary.Views;

public sealed partial class RosaryPresetPickerPage : Page
{
    public RosaryPresetPickerViewModel ViewModel { get; }

    public RosaryPresetPickerPage()
    {
        ViewModel = App.Services.GetRequiredService<RosaryPresetPickerViewModel>();
        InitializeComponent();
    }

    protected override async void OnNavigatedTo(NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);
        await ViewModel.LoadAsync();
    }

    // ContentDialog needs the XamlRoot, so the save-name prompt stays code-behind and only the
    // chosen name reaches the ViewModel.
    private async void OnSaveAsPreset(object sender, RoutedEventArgs e)
    {
        var nameBox = new TextBox { PlaceholderText = Loc.Tr("rosary_preset_name", "Preset name") };
        var dialog = new ContentDialog
        {
            Title = Loc.Tr("rosary_save_as_preset", "Save as Preset"),
            Content = nameBox,
            PrimaryButtonText = Loc.Tr("common_save", "Save"),
            CloseButtonText = Loc.Tr("common_cancel", "Cancel"),
            DefaultButton = ContentDialogButton.Primary,
            XamlRoot = XamlRoot,
        };
        if (await dialog.ShowAsync() == ContentDialogResult.Primary)
        {
            await ViewModel.SaveAsPresetAsync(nameBox.Text);
        }
    }
}
