using Prosary.Navigation;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;
using Prosary.ViewModels;
using Prosary.Localization;
using Prosary.Models;
using System.Collections.ObjectModel;
using System.Runtime.CompilerServices;

namespace Prosary.Views;

public sealed partial class SettingsPage : Page
{
    // Preserve only the position: returning recreates snapshot-backed settings from storage.
    private sealed class ScrollPosition { public double Offset; }
    private static readonly ConditionalWeakTable<Frame, ScrollPosition> ScrollPositions = new();
    private double? _restoredScrollOffset;
    public SettingsViewModel ViewModel { get; }

    public SettingsPage()
    {
        ViewModel = App.Services.GetRequiredService<SettingsViewModel>();
        ViewModel.Navigation = Router.For(this);
        InitializeComponent();
        Language = UiLanguageCatalog.ResourceTag(UiLanguageCatalog.Current);
        FlowDirection = UiLanguageCatalog.IsRightToLeft(UiLanguageCatalog.Current)
            ? FlowDirection.RightToLeft : FlowDirection.LeftToRight;
        ViewModel.ConfirmRemoveDownload = row => PrayerRemovalDialogs.ConfirmDownloadAsync(XamlRoot, row.Title);
        ViewModel.ShowRemovalError = message => PrayerRemovalDialogs.ShowErrorAsync(XamlRoot, message);

        // Dialogs need a XamlRoot, so the ViewModel delegates the remove-all confirmation here.
        ViewModel.ConfirmRemoveAll = async () =>
        {
            var dialog = new ContentDialog
            {
                XamlRoot = XamlRoot,
                Title = Loc.Tr("settings_remove_all_title", "Remove Unused Downloads?"),
                Content = Loc.Tr("settings_remove_all_message", "This removes downloaded prayers that have no saved copies. Saved prayers and built-in prayers are kept."),
                PrimaryButtonText = Loc.Tr("settings_remove_all_confirm", "Remove Unused"),
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
        if (e.NavigationMode == NavigationMode.Back && ScrollPositions.TryGetValue(Frame, out var position))
            _restoredScrollOffset = position.Offset;
    }

    protected override void OnNavigatedFrom(NavigationEventArgs e)
    {
        if (Frame is { } frame) ScrollPositions.GetValue(frame, _ => new()).Offset = SettingsScroll.VerticalOffset;
        base.OnNavigatedFrom(e);
    }

    private void OnSettingsScrollLoaded(object sender, RoutedEventArgs e)
    {
        if (_restoredScrollOffset is not { } offset) return;
        _restoredScrollOffset = null;
        DispatcherQueue.TryEnqueue(() =>
        {
            if (IsLoaded) SettingsScroll.ChangeView(null, offset, null, disableAnimation: true);
        });
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
            picker, WinRT.Interop.WindowNative.GetWindowHandle(Router.WindowFor(this)));
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
            picker, WinRT.Interop.WindowNative.GetWindowHandle(Router.WindowFor(this)));

        if (await picker.PickSaveFileAsync() is { } destination)
        {
            await using var output = await destination.OpenStreamForWriteAsync();
            await using var input = System.IO.File.OpenRead(source);
            await input.CopyToAsync(output);
        }
    }
}
