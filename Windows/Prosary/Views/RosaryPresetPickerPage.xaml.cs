using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;
using Prosary.ViewModels;

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
        var nameBox = new TextBox { PlaceholderText = "Preset name" };
        var dialog = new ContentDialog
        {
            Title = "Save as Preset",
            Content = nameBox,
            PrimaryButtonText = "Save",
            CloseButtonText = "Cancel",
            DefaultButton = ContentDialogButton.Primary,
            XamlRoot = XamlRoot,
        };
        if (await dialog.ShowAsync() == ContentDialogResult.Primary)
        {
            await ViewModel.SaveAsPresetAsync(nameBox.Text);
        }
    }
}
