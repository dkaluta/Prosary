using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Prosary.Localization;
using Prosary.Models;
using Prosary.Services;
using Prosary.ViewModels;

namespace Prosary.Views;

public sealed partial class BibleReaderControl : UserControl
{
    public BibleViewModel ViewModel { get; } = new();
    private bool _dialogOpen;
    public BibleReaderControl()
    {
        InitializeComponent();
        Loaded += OnLoaded;
        Unloaded += OnUnloaded;
    }
    private async void OnLoaded(object sender, RoutedEventArgs args)
    {
        ViewModel.ConfirmRemoval = ConfirmRemovalAsync;
        ViewModel.VerseRequested += OnVerseRequested;
        AppSettings.ReadingsEditionChanged += OnEditionChanged;
        AppSettings.TypographyChanged += OnTypographyChanged;
        BibleLibraryStore.Default.Changed += OnLibraryChanged;
        await ViewModel.RefreshAsync();
    }
    private void OnUnloaded(object sender, RoutedEventArgs args)
    {
        ViewModel.ConfirmRemoval = null;
        ViewModel.VerseRequested -= OnVerseRequested;
        AppSettings.ReadingsEditionChanged -= OnEditionChanged;
        AppSettings.TypographyChanged -= OnTypographyChanged;
        BibleLibraryStore.Default.Changed -= OnLibraryChanged;
        ViewModel.StopLoading();
    }
    private void OnVerseRequested(BibleVerseRow verse) => VerseList.ScrollIntoView(verse, ScrollIntoViewAlignment.Leading);
    private void OnEditionChanged() => DispatcherQueue.TryEnqueue(async () => { if (IsLoaded) await ViewModel.RefreshAsync(); });
    private void OnTypographyChanged() => DispatcherQueue.TryEnqueue(() => { if (IsLoaded) ViewModel.RefreshTypography(); });
    private void OnLibraryChanged(string id) => DispatcherQueue.TryEnqueue(async () =>
    {
        if (IsLoaded && ViewModel.EffectiveEdition?.Id == id && !ViewModel.IsDownloading) await ViewModel.RefreshAsync();
    });
    private async Task<bool> ConfirmRemovalAsync()
    {
        if (_dialogOpen || XamlRoot is null) return false;
        _dialogOpen = true;
        try
        {
            var dialog = new ContentDialog { XamlRoot = XamlRoot, FlowDirection = FlowDirection,
                Title = ViewModel.RemoveLabel,
                Content = string.Format(Loc.Tr("bible_remove_confirmation", "Remove the downloaded {0}? Daily readings remain available."), ViewModel.EditionName),
                PrimaryButtonText = ViewModel.RemoveLabel, CloseButtonText = Loc.Tr("common_cancel", "Cancel"),
                DefaultButton = ContentDialogButton.Close };
            return await dialog.ShowAsync() == ContentDialogResult.Primary;
        }
        finally { _dialogOpen = false; }
    }
}
