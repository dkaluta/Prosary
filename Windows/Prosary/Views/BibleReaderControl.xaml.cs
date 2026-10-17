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
    private bool? _compactPassageSelectors;
    public BibleReaderControl()
    {
        InitializeComponent();
        Loaded += OnLoaded;
        Unloaded += OnUnloaded;
    }
    private void OnBibleLayoutSizeChanged(object sender, SizeChangedEventArgs args)
    {
        // Keep verse space available even when the selectors need a second row.
        var availableHeight = args.NewSize.Height - BibleLayout.Padding.Top
            - BibleLayout.Padding.Bottom - BibleLayout.RowSpacing;
        BibleOptionsScroll.MaxHeight = Math.Max(0, availableHeight * 0.5);
    }
    private void OnPassageSelectorsSizeChanged(object sender, SizeChangedEventArgs args)
    {
        // The page can be narrower than its window because of the library sidebar.
        var compact = args.NewSize.Width < 600;
        if (_compactPassageSelectors == compact) return;
        _compactPassageSelectors = compact;
        BookSelectorColumn.Width = new GridLength(compact ? 1 : 2, GridUnitType.Star);
        if (compact) PassageSelectors.ColumnDefinitions.Remove(VerseSelectorColumn);
        else if (!PassageSelectors.ColumnDefinitions.Contains(VerseSelectorColumn))
            PassageSelectors.ColumnDefinitions.Add(VerseSelectorColumn);
        PassageSelectors.RowSpacing = compact ? 12 : 0;
        Grid.SetColumnSpan(BookSelector, compact ? 2 : 1);
        Grid.SetRow(ChapterSelector, compact ? 1 : 0);
        Grid.SetColumn(ChapterSelector, compact ? 0 : 1);
        Grid.SetRow(VerseSelector, compact ? 1 : 0);
        Grid.SetColumn(VerseSelector, compact ? 1 : 2);
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
