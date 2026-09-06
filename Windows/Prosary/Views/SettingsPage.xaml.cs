using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;
using Prosary.ViewModels;
using Prosary.Localization;
using Prosary.Models;
using System.Collections.ObjectModel;

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

    protected override void OnNavigatedTo(NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);
        ViewModel.RefreshInstalledDevotions();
    }

    private async void OnEditLanguageFallbackOrder(object sender, RoutedEventArgs e)
    {
        var rows = new ObservableCollection<LanguageOption>(LanguageCatalog.FallbackOptions);
        var list = new ListView
        {
            ItemsSource = rows,
            DisplayMemberPath = nameof(LanguageOption.NativeName),
            CanReorderItems = true,
            CanDragItems = true,
            AllowDrop = true,
            SelectionMode = ListViewSelectionMode.None,
            MaxHeight = 520,
            MinWidth = 320,
        };
        var panel = new StackPanel { Spacing = 8 };
        panel.Children.Add(new TextBlock
        {
            Text = Loc.Tr("settings_language_fallback_order_footer",
                "When text is missing, Prosary follows this order after the chosen language. Shared Hebrew, including repository prayers, uses the higher of the two Hebrew positions."),
            TextWrapping = TextWrapping.Wrap,
        });
        panel.Children.Add(list);
        var dialog = new ContentDialog
        {
            XamlRoot = XamlRoot,
            Title = Loc.Tr("settings_language_fallback_order_title", "Language fallback order"),
            Content = panel,
            PrimaryButtonText = Loc.Tr("common_done", "Done"),
            SecondaryButtonText = Loc.Tr("common_reset", "Reset"),
            CloseButtonText = Loc.Tr("common_cancel", "Cancel"),
            DefaultButton = ContentDialogButton.Primary,
        };
        var result = await dialog.ShowAsync();
        if (result == ContentDialogResult.Primary)
        {
            AppSettings.SetLanguageFallbackOrder(rows.Select(r => r.Code));
        }
        else if (result == ContentDialogResult.Secondary)
        {
            AppSettings.SetLanguageFallbackOrder([]);
        }
    }

    // The file pickers need the window handle and a UI-thread continuation, so picking stays
    // code-behind and only bytes (or a path) reach the ViewModel — same split the retired
    // Favorites page used.
    private async void OnImportBundle(object sender, RoutedEventArgs e)
    {
        var picker = new Windows.Storage.Pickers.FileOpenPicker();
        WinRT.Interop.InitializeWithWindow.Initialize(
            picker, WinRT.Interop.WindowNative.GetWindowHandle(App.MainWindow));
        picker.FileTypeFilter.Add(".prosaryprayer");
        if (await picker.PickSingleFileAsync() is not { } file)
        {
            return;
        }

        string? message;
        try
        {
            await using var input = await file.OpenStreamForReadAsync();
            var bytes = await PrayerPackStore.ReadInstallBytesAsync(input);
            message = ViewModel.ImportPack(bytes);
        }
        catch (PrayerPackStore.InstallException error)
        {
            message = error.Message;
        }

        if (message is not null)
        {
            var dialog = new ContentDialog
            {
                XamlRoot = XamlRoot,
                Title = Loc.Tr("favorites_import_error_title", "Could Not Import Devotion"),
                Content = message,
                CloseButtonText = Loc.Tr("common_ok", "OK"),
            };
            await dialog.ShowAsync();
        }
    }

    /// <summary>Round-trip to Compose (Gamaliel item 7): a copy of the installed
    /// .prosaryprayer, saved wherever the user picks, edited at compose.prosary.app, re-imported.</summary>
    private async void OnExportBundle(object sender, RoutedEventArgs e)
    {
        if (sender is not FrameworkElement { Tag: string bundleId } ||
            SettingsViewModel.InstalledPackPath(bundleId) is not { } source)
        {
            return;
        }

        var picker = new Windows.Storage.Pickers.FileSavePicker { SuggestedFileName = bundleId };
        picker.FileTypeChoices.Add(
            Loc.Tr("favorites_bundle_file_type", "Prosary devotion bundle"), [".prosaryprayer"]);
        WinRT.Interop.InitializeWithWindow.Initialize(
            picker, WinRT.Interop.WindowNative.GetWindowHandle(App.MainWindow));

        if (await picker.PickSaveFileAsync() is { } destination)
        {
            await using var output = await destination.OpenStreamForWriteAsync();
            await using var input = System.IO.File.OpenRead(source);
            await input.CopyToAsync(output);
        }
    }
}
