using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Prosary.Localization;
using Prosary.Services;

namespace Prosary.Views;

internal static class PrayerRemovalDialogs
{
    internal static async Task<bool> ConfirmDeleteAsync(XamlRoot root, PrayerRemovalPlan plan)
    {
        var message = plan.RemovesDownload
            ? Loc.Tr("prayerRemoval_deleteDownloadedMessage", "This is the last saved copy. Deleting it also removes its downloaded prayer pack from this device and cancels its reminders.")
            : Loc.Tr("prayerRemoval_deleteMessage", "This deletes the saved prayer and its reminders. Other saved copies and built-in prayers remain available.");
        var dialog = new ContentDialog
        {
            XamlRoot = root,
            Title = Loc.Tr("prayerRemoval_deleteTitle", "Delete Saved Prayer?"),
            Content = plan.Prayer.Name + "\n\n" + message,
            PrimaryButtonText = Loc.Tr("prayerRemoval_deleteConfirm", "Delete"),
            CloseButtonText = Loc.Tr("common_cancel", "Cancel"),
            DefaultButton = ContentDialogButton.Close,
        };
        return await dialog.ShowAsync() == ContentDialogResult.Primary;
    }

    internal static async Task<bool> ConfirmDownloadAsync(XamlRoot root, string name)
    {
        var dialog = new ContentDialog
        {
            XamlRoot = root,
            Title = Loc.Tr("prayerRemoval_removeDownloadTitle", "Remove Download?"),
            Content = name + "\n\n" + Loc.Tr("prayerRemoval_removeDownloadMessage",
                "This removes the downloaded prayer from this device. You can import or download it again."),
            PrimaryButtonText = Loc.Tr("prayerRemoval_removeConfirm", "Remove"),
            CloseButtonText = Loc.Tr("common_cancel", "Cancel"),
            DefaultButton = ContentDialogButton.Close,
        };
        return await dialog.ShowAsync() == ContentDialogResult.Primary;
    }

    internal static async Task ShowErrorAsync(XamlRoot root, string message)
    {
        await new ContentDialog
        {
            XamlRoot = root,
            Title = Loc.Tr("prayerRemoval_failedTitle", "Could Not Remove Prayer"),
            Content = message,
            CloseButtonText = Loc.Tr("common_ok", "OK"),
            DefaultButton = ContentDialogButton.Close,
        }.ShowAsync();
    }

    internal static async Task ShowSaveErrorAsync(XamlRoot root, string message)
    {
        await new ContentDialog
        {
            XamlRoot = root,
            Title = Loc.Tr("FavoriteEditorSaveFailed", "Could Not Save Favorite"),
            Content = message,
            CloseButtonText = Loc.Tr("common_ok", "OK"),
            DefaultButton = ContentDialogButton.Close,
        }.ShowAsync();
    }
}
