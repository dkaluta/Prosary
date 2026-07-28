using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;
using Prosary.ViewModels;

namespace Prosary.Views;

public sealed partial class FavoritesListPage : Page
{
    public FavoritesViewModel ViewModel { get; }

    public FavoritesListPage()
    {
        ViewModel = App.Services.GetRequiredService<FavoritesViewModel>();
        InitializeComponent();
    }

    protected override async void OnNavigatedTo(NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);
        await ViewModel.LoadAsync();
    }

    // FileOpenPicker needs the window handle and a UI-thread continuation, so the pick stays
    // code-behind and only the bytes reach the ViewModel.
    private async void OnImportBundle(object sender, RoutedEventArgs e)
    {
        var picker = new Windows.Storage.Pickers.FileOpenPicker();
        WinRT.Interop.InitializeWithWindow.Initialize(
            picker, WinRT.Interop.WindowNative.GetWindowHandle(App.MainWindow));
        picker.FileTypeFilter.Add(".prosaryprayer");
        var file = await picker.PickSingleFileAsync();
        if (file is null) return;

        var buffer = await Windows.Storage.FileIO.ReadBufferAsync(file);
        var bytes = new byte[buffer.Length];
        Windows.Storage.Streams.DataReader.FromBuffer(buffer).ReadBytes(bytes);
        await ViewModel.ImportPackAsync(bytes);

        if (ViewModel.ImportError is { } message)
        {
            ViewModel.ImportError = null;
            var dialog = new ContentDialog
            {
                Title = "Could Not Import Devotion",
                Content = message,
                CloseButtonText = "OK",
                XamlRoot = XamlRoot,
            };
            await dialog.ShowAsync();
        }
    }
}
